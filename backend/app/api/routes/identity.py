from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter
from pydantic import BaseModel

from ..deps import PrincipalDep

router = APIRouter(prefix="/api/v1", tags=["identidad"])


class MeResponse(BaseModel):
    id: UUID
    role: str
    full_name: str


@router.get("/me", response_model=MeResponse)
async def me(principal: PrincipalDep) -> MeResponse:
    """Identidad verificada y rol efectivo segun ``public.profiles``."""
    return MeResponse(
        id=principal.user_id,
        role=principal.role.value,
        full_name=principal.full_name,
    )
