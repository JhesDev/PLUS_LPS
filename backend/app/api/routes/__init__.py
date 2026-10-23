"""Endpoints HTTP."""

from __future__ import annotations

from fastapi import APIRouter

from . import health, identity, sync

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(identity.router)
api_router.include_router(sync.router)

__all__ = ["api_router"]
