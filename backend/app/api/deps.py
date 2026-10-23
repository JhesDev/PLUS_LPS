"""Dependencias HTTP compartidas: contenedor, principal y guardas de rol."""

from __future__ import annotations

from collections.abc import Callable
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ..container import Container
from ..domain import AppRole
from ..errors import AuthError, ForbiddenError
from ..security import Principal

_bearer = HTTPBearer(auto_error=False, description="JWT de Supabase Auth")


def get_container(request: Request) -> Container:
    return request.app.state.container


async def resolve_principal(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(_bearer)
    ],
    container: Annotated[Container, Depends(get_container)],
) -> Principal:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AuthError("Se requiere un token Bearer")
    return await container.auth.authenticate(credentials.credentials)


PrincipalDep = Annotated[Principal, Depends(resolve_principal)]


def require_roles(*allowed: AppRole) -> Callable[..., Principal]:
    async def dependency(principal: PrincipalDep) -> Principal:
        if principal.role not in allowed:
            raise ForbiddenError("El rol no tiene permiso para esta operacion.")
        return principal

    return dependency
