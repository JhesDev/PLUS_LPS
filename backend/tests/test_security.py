from __future__ import annotations

from uuid import UUID

import httpx
import pytest

from app.domain import AppRole
from app.errors import AuthError
from app.security import SupabaseAuthService

USER_ID = UUID("22222222-2222-4222-8222-222222222222")


def _service(handler) -> tuple[SupabaseAuthService, httpx.AsyncClient]:
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    service = SupabaseAuthService(
        base_url="http://supabase.test",
        api_key="anon-test",
        client=client,
    )
    return service, client


def _ok_handler(profile: dict | list[dict] | None = None, *, user_status: int = 200):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers.get("apikey") == "anon-test"
        if request.url.path == "/auth/v1/user":
            if user_status != 200:
                return httpx.Response(user_status, json={"msg": "error"})
            return httpx.Response(200, json={"id": str(USER_ID)})
        if request.url.path == "/rest/v1/profiles":
            if request.url.params.get("select") != "id,role,full_name,is_active":
                return httpx.Response(400)
            if request.url.params.get("id") != f"eq.{USER_ID}":
                return httpx.Response(400)
            return httpx.Response(200, json=profile)
        return httpx.Response(404)

    return handler


async def test_authenticate_returns_role_from_profile() -> None:
    service, client = _service(
        _ok_handler(
            [{"id": str(USER_ID), "role": "despachador", "full_name": "Demo", "is_active": True}]
        )
    )
    async with client:
        principal = await service.authenticate("valid-token")

    assert principal.user_id == USER_ID
    assert principal.role is AppRole.DESPACHADOR
    assert principal.full_name == "Demo"


async def test_inactive_profile_is_forbidden() -> None:
    service, client = _service(
        _ok_handler(
            [{"id": str(USER_ID), "role": "tecnico", "full_name": "Demo", "is_active": False}]
        )
    )
    async with client:
        with pytest.raises(AuthError) as excinfo:
            await service.authenticate("valid-token")

    assert excinfo.value.status_code == 403


async def test_user_without_profile_is_forbidden() -> None:
    service, client = _service(_ok_handler([]))
    async with client:
        with pytest.raises(AuthError) as excinfo:
            await service.authenticate("valid-token")

    assert excinfo.value.status_code == 403


async def test_unknown_role_is_forbidden() -> None:
    service, client = _service(
        _ok_handler(
            [{"id": str(USER_ID), "role": "admin", "full_name": "Demo", "is_active": True}]
        )
    )
    async with client:
        with pytest.raises(AuthError) as excinfo:
            await service.authenticate("valid-token")

    assert excinfo.value.status_code == 403


async def test_invalid_token_returns_401() -> None:
    service, client = _service(_ok_handler([], user_status=401))
    async with client:
        with pytest.raises(AuthError) as excinfo:
            await service.authenticate("bad-token")

    assert excinfo.value.status_code == 401


async def test_auth_provider_failure_returns_503() -> None:
    service, client = _service(_ok_handler([], user_status=500))
    async with client:
        with pytest.raises(AuthError) as excinfo:
            await service.authenticate("valid-token")

    assert excinfo.value.status_code == 503


async def test_empty_token_is_rejected_without_http_call() -> None:
    def handler(request: httpx.Request) -> httpx.Response:  # pragma: no cover
        raise AssertionError("no debe llamarse al proveedor")

    service, client = _service(handler)
    async with client:
        with pytest.raises(AuthError):
            await service.authenticate("   ")


async def test_oversized_token_is_rejected() -> None:
    service, client = _service(_ok_handler([]))
    async with client:
        with pytest.raises(AuthError):
            await service.authenticate("x" * 9000)
