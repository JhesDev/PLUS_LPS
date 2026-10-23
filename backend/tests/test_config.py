from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.config import Settings


def _settings(**overrides) -> Settings:
    values = {
        "supabase_url": "http://127.0.0.1:54321",
        "supabase_anon_key": "anon-test",
    }
    values.update(overrides)
    return Settings(**values)


def test_empty_database_url_is_treated_as_missing() -> None:
    settings = _settings(database_url="")

    assert settings.database_url is None


def test_empty_service_role_is_treated_as_none() -> None:
    settings = _settings(db_service_role="   ")

    assert settings.db_service_role is None


def test_supabase_url_must_be_http() -> None:
    with pytest.raises(ValidationError):
        _settings(supabase_url="127.0.0.1:54321")


def test_secrets_are_masked_in_repr() -> None:
    settings = _settings(
        supabase_anon_key="super-secret-anon",
        database_url="postgresql://user:password@localhost/db",
    )

    rendered = repr(settings)
    assert "super-secret-anon" not in rendered
    assert "password" not in rendered


def test_default_cors_origins_are_local_frontend() -> None:
    settings = _settings()

    assert "http://localhost:5173" in settings.cors_origins
