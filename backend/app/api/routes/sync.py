from __future__ import annotations

import logging
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ...container import Container
from ...domain import AppRole
from ...security import Principal
from ..deps import get_container, require_roles

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/sync", tags=["sincronizacion"])

_STAFF = (AppRole.COORDINADOR, AppRole.DESPACHADOR)


class SyncAvailabilityResponse(BaseModel):
    configured: bool
    source: str
    missing: list[str]


class SyncRunResponse(BaseModel):
    batch_id: UUID
    status: str
    received: int
    created: int
    updated: int
    skipped: int
    duplicates: int
    errors: int


@router.get("/availability", response_model=SyncAvailabilityResponse)
async def get_availability(
    _: Annotated[Principal, Depends(require_roles(*_STAFF))],
    container: Annotated[Container, Depends(get_container)],
) -> SyncAvailabilityResponse:
    """Indica si la integracion externa esta lista y que falta para estarlo.

    Coordinador y despachador pueden consultarlo; el tecnico no.
    """
    availability = container.sync.availability()
    return SyncAvailabilityResponse(
        configured=availability.configured,
        source=availability.source,
        missing=list(availability.missing),
    )


@router.post("/runs", response_model=SyncRunResponse)
async def trigger_sync(
    principal: Annotated[
        Principal, Depends(require_roles(AppRole.DESPACHADOR))
    ],
    container: Annotated[Container, Depends(get_container)],
) -> SyncRunResponse:
    """Ejecuta una sincronizacion manual (boton "Sincronizar ahora").

    Solo despachador. Es sincrona: responde cuando termina. Si ya hay una
    corrida activa del mismo origen devuelve 409; si la API externa aun no
    tiene contrato, 503.
    """
    logger.info(
        "sync.manual_requested source=%s actor=%s",
        container.sync.source_name,
        principal.user_id,
    )
    result = await container.sync.run()
    return SyncRunResponse(
        batch_id=result.batch_id,
        status=result.status.value,
        received=result.received,
        created=result.created,
        updated=result.updated,
        skipped=result.skipped,
        duplicates=result.duplicates,
        errors=result.errors,
    )
