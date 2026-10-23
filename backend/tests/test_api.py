from __future__ import annotations

from uuid import UUID

from fastapi.testclient import TestClient

from app.config import Settings
from app.container import Container
from app.domain import AppRole
from app.factory import create_app
from app.security import Principal
from app.services.sync import SyncService

from .fakes import DictMapper, FakeAuth, FakeSyncStore, ListSource, make_payload

DESPACHADOR_ID = UUID("22222222-2222-4222-8222-222222222222")
COORDINADOR_ID = UUID("11111111-1111-4111-8111-111111111111")
TECNICO_ID = UUID("33333333-3333-4333-8333-333333333331")


def _settings() -> Settings:
    return Settings(
        supabase_url="http://supabase.test",
        supabase_anon_key="anon-test",
        database_url=None,
        cors_origins=[],
    )


def _auth() -> FakeAuth:
    return FakeAuth(
        {
            "despachador-token": Principal(DESPACHADOR_ID, AppRole.DESPACHADOR, "Despachador Demo"),
            "coordinador-token": Principal(COORDINADOR_ID, AppRole.COORDINADOR, "Coordinador Demo"),
            "tecnico-token": Principal(TECNICO_ID, AppRole.TECNICO, "Tecnico Demo"),
        }
    )


def _unconfigured_sync() -> SyncService:
    return SyncService(
        source_name="sap",
        missing=("Documentacion oficial de la API externa",),
    )


def _configured_sync() -> SyncService:
    return SyncService(
        source_name="sap",
        source=ListSource([make_payload(external_id="EXT-1", code="WO-1")]),
        mapper=DictMapper(),
        store=FakeSyncStore(),
    )


def _client(sync: SyncService) -> TestClient:
    settings = _settings()
    container = Container(
        settings=settings,
        auth=_auth(),
        sync=sync,
        http_client=None,
    )
    return TestClient(create_app(settings, container=container))


def test_health_is_public() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_me_requires_bearer_token() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get("/api/v1/me")

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHENTICATED"
    assert response.headers["www-authenticate"] == "Bearer"


def test_me_returns_role_from_database_profile() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get(
            "/api/v1/me",
            headers={"Authorization": "Bearer despachador-token"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(DESPACHADOR_ID)
    assert body["role"] == "despachador"


def test_invalid_token_is_rejected() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get(
            "/api/v1/me", headers={"Authorization": "Bearer no-existe"}
        )

    assert response.status_code == 401


def test_availability_is_readable_by_coordinador() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get(
            "/api/v1/sync/availability",
            headers={"Authorization": "Bearer coordinador-token"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["configured"] is False
    assert body["source"] == "sap"
    assert body["missing"]


def test_availability_is_forbidden_for_tecnico() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get(
            "/api/v1/sync/availability",
            headers={"Authorization": "Bearer tecnico-token"},
        )

    assert response.status_code == 403
    assert response.json()["code"] == "FORBIDDEN"


def test_sync_trigger_is_forbidden_for_coordinador_and_tecnico() -> None:
    with _client(_configured_sync()) as client:
        for token in ("coordinador-token", "tecnico-token"):
            response = client.post(
                "/api/v1/sync/runs",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 403


def test_sync_trigger_returns_503_while_contract_is_pending() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.post(
            "/api/v1/sync/runs",
            headers={"Authorization": "Bearer despachador-token"},
        )

    assert response.status_code == 503
    body = response.json()
    assert body["code"] == "INTEGRATION_PENDING"
    assert body["missing"]


def test_sync_trigger_runs_for_despachador() -> None:
    with _client(_configured_sync()) as client:
        response = client.post(
            "/api/v1/sync/runs",
            headers={"Authorization": "Bearer despachador-token"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "procesado"
    assert body["received"] == 1
    assert body["created"] == 1
    assert body["errors"] == 0
    assert UUID(body["batch_id"])


def test_unknown_route_returns_404() -> None:
    with _client(_unconfigured_sync()) as client:
        response = client.get("/api/v1/no-existe")

    assert response.status_code == 404
    assert response.json()["code"] == "NOT_FOUND"
