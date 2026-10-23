"""Pruebas de integracion contra PostgreSQL local.

Se omiten si no existe ``PLUS_TEST_DATABASE_URL``. Usan un ``source`` propio
(``pytest-sap``) y limpian todo lo que crean, sin tocar el seed.
"""

from __future__ import annotations

import os
from typing import Any

import asyncpg
import pytest

from app.adapters.postgres import PostgresSyncStore
from app.domain import IngestBatchStatus
from app.services.sync import SyncService

from ..fakes import DictMapper, ListSource, make_payload

DSN = os.getenv("PLUS_TEST_DATABASE_URL")
SOURCE = "pytest-sap"
CODE = "WO-PYTEST-0001"

pytestmark = pytest.mark.skipif(
    not DSN, reason="PLUS_TEST_DATABASE_URL no esta configurada"
)


async def _connect() -> asyncpg.Connection:
    assert DSN is not None
    conn = await asyncpg.connect(DSN)
    await conn.execute("set role service_role")
    return conn


async def _cleanup() -> None:
    conn = await _connect()
    try:
        await conn.execute("delete from ingest.records where source = $1", SOURCE)
        await conn.execute("delete from ingest.batches where source = $1", SOURCE)
        await conn.execute(
            "delete from public.work_orders where external_source = $1", SOURCE
        )
    finally:
        await conn.close()


async def _fetch_order() -> dict[str, Any] | None:
    conn = await _connect()
    try:
        row = await conn.fetchrow(
            """
            select id, code, status::text as status, address, priority,
                   extensions.ST_Y(location) as latitude
            from public.work_orders
            where external_source = $1
            """,
            SOURCE,
        )
        return dict(row) if row is not None else None
    finally:
        await conn.close()


async def _records() -> list[dict[str, Any]]:
    conn = await _connect()
    try:
        rows = await conn.fetch(
            """
            select id, batch_id, status::text as status, error_message
            from ingest.records
            where source = $1
            order by created_at
            """,
            SOURCE,
        )
        return [dict(row) for row in rows]
    finally:
        await conn.close()


@pytest.fixture
async def store():
    await _cleanup()
    try:
        yield PostgresSyncStore(DSN or "", "service_role")
    finally:
        await _cleanup()


def _service(store: PostgresSyncStore, payloads: list[dict[str, Any]]) -> SyncService:
    return SyncService(
        source_name=SOURCE,
        source=ListSource(payloads),
        mapper=DictMapper(),
        store=store,
    )


async def test_creates_order_and_is_idempotent(store: PostgresSyncStore) -> None:
    payloads = [make_payload(external_id="PY-1", code=CODE)]

    first = await _service(store, payloads).run()
    second = await _service(store, payloads).run()

    assert (first.created, first.duplicates) == (1, 0)
    assert (second.created, second.duplicates) == (0, 1)

    order = await _fetch_order()
    assert order is not None
    assert order["status"] == "pendiente"
    assert order["code"] == CODE
    assert abs(order["latitude"] - (-12.1219)) < 1e-6


async def test_does_not_overwrite_order_that_left_pending(store: PostgresSyncStore) -> None:
    await _service(store, [make_payload(external_id="PY-1", code=CODE)]).run()

    conn = await _connect()
    try:
        await conn.execute(
            "update public.work_orders set status = 'asignada' where external_source = $1",
            SOURCE,
        )
    finally:
        await conn.close()

    changed = make_payload(
        external_id="PY-1",
        code=CODE,
        address="Direccion que no debe aplicarse",
        priority=5,
    )
    result = await _service(store, [changed]).run()

    order = await _fetch_order()
    assert result.skipped == 1
    assert result.updated == 0
    assert order is not None
    assert order["status"] == "asignada"
    assert order["address"] == "Av. Demo 100"
    assert order["priority"] == 2


async def test_advisory_lock_blocks_concurrent_runs(store: PostgresSyncStore) -> None:
    async with store.open_run(SOURCE) as (_, acquired):
        assert acquired is True
        async with store.open_run(SOURCE) as (_, second):
            assert second is False


async def test_failed_record_is_reused_on_retry(store: PostgresSyncStore) -> None:
    # Payload sin `code`: el mapper falla y el registro queda en error.
    bad = {"external_id": "PY-BAD", "type": "corte", "priority": 1}

    first = await _service(store, [bad]).run()
    second = await _service(store, [bad]).run()

    assert first.errors == 1
    assert first.status is IngestBatchStatus.ERROR
    assert second.errors == 1

    records = await _records()
    assert len(records) == 1
    assert records[0]["status"] == "error"
    # El reintento reutiliza la fila y la vincula al lote nuevo.
    assert records[0]["batch_id"] == second.batch_id
