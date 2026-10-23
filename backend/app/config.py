"""Configuracion del backend.

Todas las credenciales elevadas (DSN de PostgreSQL, anon key) viven solo aqui,
se leen de variables de entorno del servidor y nunca se envian al cliente.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
        populate_by_name=True,
    )

    app_name: str = "PLUS_LPS Backend"
    environment: Literal["development", "test", "production"] = "development"
    log_level: str = "INFO"

    # Supabase Auth/PostgREST acepta la Publishable key. El nombre del campo
    # conserva compatibilidad con configuraciones existentes que usan ANON.
    supabase_url: str
    supabase_anon_key: SecretStr = Field(
        validation_alias=AliasChoices(
            "SUPABASE_PUBLISHABLE_KEY",
            "SUPABASE_ANON_KEY",
        )
    )

    # Acceso directo a PostgreSQL para el esquema `ingest` (no expuesto por
    # PostgREST) y para la escritura transaccional de la sincronizacion.
    database_url: SecretStr | None = None
    db_service_role: str | None = "service_role"

    sync_source: str = "sap"
    sync_entity: str = "work_order"

    http_timeout_seconds: float = Field(default=10.0, gt=0, le=60)
    cors_origins: list[str] = Field(
        default_factory=lambda: [
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        ]
    )

    @field_validator("supabase_url")
    @classmethod
    def _normalize_supabase_url(cls, value: str) -> str:
        value = value.strip().rstrip("/")
        if not value.startswith(("http://", "https://")):
            raise ValueError("SUPABASE_URL debe iniciar con http:// o https://")
        return value

    @field_validator("db_service_role", mode="before")
    @classmethod
    def _empty_role_is_none(cls, value: object) -> object:
        if isinstance(value, str) and not value.strip():
            return None
        return value

    @field_validator("database_url", mode="before")
    @classmethod
    def _empty_dsn_is_none(cls, value: object) -> object:
        if isinstance(value, str) and not value.strip():
            return None
        return value


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
