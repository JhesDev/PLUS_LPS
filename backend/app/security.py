"""Identidad y autorizacion.

El rol NO se toma del JWT ni de ``user_metadata``: se consulta siempre
``public.profiles.role`` con el token del usuario, de modo que RLS y la base de
datos siguen siendo la fuente de verdad. El backend igualmente aplica sus
propias guardas de rol antes de ejecutar acciones sensibles.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

import httpx

from .domain import AppRole
from .errors import AuthError

_MAX_TOKEN_LENGTH = 8192


@dataclass(frozen=True, slots=True)
class Principal:
    user_id: UUID
    role: AppRole
    full_name: str


class AuthService(Protocol):
    async def authenticate(self, token: str) -> Principal: ...


class SupabaseAuthService:
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        client: httpx.AsyncClient,
        timeout: float = 10.0,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._client = client
        self._timeout = timeout

    async def authenticate(self, token: str) -> Principal:
        token = token.strip()
        if not token or len(token) > _MAX_TOKEN_LENGTH:
            raise AuthError("Token de acceso ausente o invalido")

        headers = {
            "apikey": self._api_key,
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        }

        try:
            response = await self._client.get(
                f"{self._base_url}/auth/v1/user",
                headers=headers,
                timeout=self._timeout,
            )
        except httpx.HTTPError as exc:
            raise AuthError(
                "No se pudo contactar el servicio de autenticacion",
                status_code=503,
            ) from exc

        if response.status_code in (401, 403):
            raise AuthError("Token invalido o expirado")
        if response.status_code >= 400:
            raise AuthError(
                "Servicio de autenticacion no disponible", status_code=503
            )

        try:
            user_id = UUID(str(response.json()["id"]))
        except (KeyError, TypeError, ValueError) as exc:
            raise AuthError(
                "Respuesta de autenticacion invalida", status_code=502
            ) from exc

        return await self._load_profile(user_id, headers)

    async def _load_profile(
        self, user_id: UUID, headers: dict[str, str]
    ) -> Principal:
        try:
            response = await self._client.get(
                f"{self._base_url}/rest/v1/profiles",
                params={
                    "select": "id,role,full_name,is_active",
                    "id": f"eq.{user_id}",
                    "limit": "1",
                },
                headers=headers,
                timeout=self._timeout,
            )
        except httpx.HTTPError as exc:
            raise AuthError(
                "No se pudo consultar el perfil del usuario", status_code=503
            ) from exc

        if response.status_code in (401, 403):
            raise AuthError("Token invalido o expirado")
        if response.status_code >= 400:
            raise AuthError(
                "No se pudo consultar el perfil del usuario", status_code=503
            )

        try:
            rows = response.json()
        except ValueError as exc:
            raise AuthError("Respuesta de perfil invalida", status_code=502) from exc

        if not isinstance(rows, list) or not rows:
            raise AuthError(
                "El usuario no tiene perfil en la aplicacion", status_code=403
            )

        row = rows[0]
        if not row.get("is_active", False):
            raise AuthError("El perfil del usuario esta inactivo", status_code=403)

        try:
            role = AppRole(row["role"])
        except (KeyError, ValueError) as exc:
            raise AuthError(
                "El perfil tiene un rol no reconocido", status_code=403
            ) from exc

        return Principal(
            user_id=user_id,
            role=role,
            full_name=str(row.get("full_name") or ""),
        )
