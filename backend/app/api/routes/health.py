from __future__ import annotations

from pydantic import BaseModel

from fastapi import APIRouter

router = APIRouter(tags=["salud"])


class HealthResponse(BaseModel):
    status: str


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Sonda de vida. No consulta dependencias externas."""
    return HealthResponse(status="ok")
