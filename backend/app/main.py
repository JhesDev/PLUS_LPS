"""Punto de entrada para Uvicorn: ``uvicorn app.main:app``."""

from __future__ import annotations

import logging

from .config import get_settings
from .factory import create_app

_settings = get_settings()
logging.basicConfig(
    level=_settings.log_level.upper(),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
# Evita registrar cada llamada HTTP (incluye UUIDs de usuario) en nivel INFO.
logging.getLogger("httpx").setLevel(logging.WARNING)

app = create_app(_settings)
