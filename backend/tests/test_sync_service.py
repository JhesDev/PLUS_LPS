from __future__ import annotations

from dataclasses import replace

import pytest

from app.domain import IngestBatchStatus, IngestRecordStatus, WorkOrderStatus
from app.errors import ExternalSourceError, IntegrationPending, RunAlreadyInProgress
from app.services.sync import SyncService

from .fakes import DictMapper, FakeSyncSession, FakeSyncStore, ListSource, make_payload


def _service(
    payloads,
    *,
    session: FakeSyncSession | None = None,
    acquired: bool = True,
    source_error: Exception | None = None,
) -> tuple[SyncService, FakeSyncStore]:
    store = FakeSyncStore(session=session, acquired=acquired)
    service = SyncService(
        source_name="sap",
        source=ListSource(payloads, error=source_error),
        mapper=DictMapper(),
        store=store,
    )
    return service, store


async def test_run_creates_orders_and_records() -> None:
    service, store = _service(
        [
            make_payload(external_id="EXT-1", code="WO-1"),
            make_payload(external_id="EXT-2", code="WO-2", type="reposicion"),
        ]
    )

    result = await service.run()

    assert (result.received, result.created, result.errors) == (2, 2, 0)
    assert result.status is IngestBatchStatus.PROCESADO
    assert len(store.session.orders_by_ref) == 2
    assert all(
        record["status"] is IngestRecordStatus.PROCESADO
        for record in store.session.records.values()
    )
    assert all(order.status is WorkOrderStatus.PENDIENTE for order in store.session.orders_by_id.values())
    batch = store.session.batches[result.batch_id]
    assert batch["records_count"] == 2
    assert batch["payload_hash"] is not None


async def test_second_identical_run_is_deduplicated() -> None:
    payloads = [make_payload(external_id="EXT-1", code="WO-1")]
    service, store = _service(payloads)

    first = await service.run()
    second = await service.run()

    assert (first.created, first.duplicates) == (1, 0)
    assert (second.created, second.updated, second.duplicates) == (0, 0, 1)
    assert len(store.session.orders_by_ref) == 1
    assert len(store.session.records) == 1
    assert second.status is IngestBatchStatus.PROCESADO


async def test_order_in_progress_is_never_overwritten() -> None:
    service, store = _service([make_payload(external_id="EXT-1", code="WO-1")])
    await service.run()

    (key, order), = store.session.orders_by_ref.items()
    store.session.orders_by_ref[key] = replace(order, status=WorkOrderStatus.EN_PROCESO)

    changed = make_payload(
        external_id="EXT-1",
        code="WO-1",
        address="Direccion que no debe aplicarse",
        priority=5,
    )

    result = await SyncService(
        source_name="sap",
        source=ListSource([changed]),
        mapper=DictMapper(),
        store=store,
    ).run()

    updated = store.session.orders_by_ref[key]
    assert result.skipped == 1
    assert result.updated == 0
    assert updated.address == "Av. Demo 100"
    assert updated.priority == 2
    assert updated.status is WorkOrderStatus.EN_PROCESO


async def test_mapping_error_marks_record_and_batch_partial() -> None:
    bad = {"external_id": "EXT-BAD", "type": "corte", "priority": 1}
    service, store = _service([make_payload(external_id="EXT-1", code="WO-1"), bad])

    result = await service.run()

    assert (result.created, result.errors) == (1, 1)
    assert result.status is IngestBatchStatus.PARCIAL
    error_records = [
        record
        for record in store.session.records.values()
        if record["status"] is IngestRecordStatus.ERROR
    ]
    assert len(error_records) == 1
    assert "obligatorio" in error_records[0]["error_message"]


async def test_failed_record_is_retried_on_next_run() -> None:
    bad = {"external_id": "EXT-BAD", "type": "corte", "priority": 1}
    service, store = _service([bad])

    first = await service.run()
    second = await service.run()

    assert first.errors == 1
    assert second.errors == 1
    assert len(store.session.records) == 1  # se reutiliza el registro fallido
    assert store.session.records[next(iter(store.session.records))]["status"] is IngestRecordStatus.ERROR


async def test_source_failure_closes_batch_as_error() -> None:
    service, store = _service(
        [make_payload(external_id="EXT-1", code="WO-1")],
        source_error=RuntimeError("timeout del origen"),
    )

    with pytest.raises(ExternalSourceError):
        await service.run()

    batch = next(iter(store.session.batches.values()))
    assert batch["status"] is IngestBatchStatus.ERROR
    assert "fallo=RuntimeError" in batch["notes"]
    assert "timeout del origen" not in batch["notes"]


async def test_unconfigured_integration_raises_pending() -> None:
    service = SyncService(source_name="sap", missing=["documentacion pendiente"])

    assert service.availability().configured is False
    with pytest.raises(IntegrationPending) as excinfo:
        await service.run()
    assert excinfo.value.missing == ("documentacion pendiente",)


async def test_concurrent_run_is_rejected() -> None:
    service, _ = _service([make_payload()], acquired=False)

    with pytest.raises(RunAlreadyInProgress):
        await service.run()
