"""Composicion de dependencias del backend.

Se construye una sola vez al arrancar la aplicacion. Los adaptadores externos
(API de SAP/PLUZ) quedan deliberadamente sin registrar hasta recibir el
contrato oficial: el servicio reporta ``configured=false`` y responde 503.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import httpx

from .adapters.postgres import PostgresSyncStore
from .config import Settings
from .security import AuthService, SupabaseAuthService
from .services.sync import SyncService

_MISSING_EXTERNAL_CONTRACT = (
    "Documentacion oficial de la API externa (URL, autenticacion y paginacion)",
    "Ejemplo de respuesta JSON sanitizado (sin datos personales)",
    "Reglas de identificacion y actualizacion de ordenes del origen",
    "Mapeo de campos externos al modelo interno (WorkOrderMapper)",
    "Adaptador del origen externo (WorkOrderSource)",
)


@dataclass
class Container:
    settings: Settings
    auth: AuthService
    sync: SyncService
    http_client: httpx.AsyncClient | None = field(default=None, repr=False)

    async def aclose(self) -> None:
        if self.http_client is not None:
            await self.http_client.aclose()


def build_container(settings: Settings) -> Container:
    http_client = httpx.AsyncClient(timeout=settings.http_timeout_seconds)

    auth = SupabaseAuthService(
        base_url=settings.supabase_url,
        api_key=settings.supabase_anon_key.get_secret_value(),
        client=http_client,
        timeout=settings.http_timeout_seconds,
    )

    missing: list[str] = []
    store: PostgresSyncStore | None = None

    if settings.database_url is not None:
        store = PostgresSyncStore(
            settings.database_url.get_secret_value(),
            settings.db_service_role,
        )
    else:
        missing.append(
            "DATABASE_URL del backend (acceso directo a PostgreSQL para el esquema ingest)"
        )

    missing.extend(_MISSING_EXTERNAL_CONTRACT)

    sync = SyncService(
        source_name=settings.sync_source,
        entity=settings.sync_entity,
        source=None,
        mapper=None,
        store=store,
        missing=missing,
    )

    return Container(settings=settings, auth=auth, sync=sync, http_client=http_client)
