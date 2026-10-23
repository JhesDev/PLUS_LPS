"""Fakes de pruebas. NO representan el contrato real de la API externa."""

from __future__ import annotations

from contextlib import asynccontextmanager
from dataclasses import replace
from typing import Any, Mapping
from uuid import UUID, uuid4

from app.domain import (
    ApplyOutcome,
    ExistingWorkOrder,
    GeoPoint,
    IngestBatchStatus,
    IngestRecordStatus,
    MappedWorkOrder,
    NormalizedWorkOrder,
    SyncAction,
    WorkOrderStatus,
    WorkOrderType,
    plan_upsert,
)
from app.errors import AuthError
from app.security import Principal


class FakeAuth:
    def __init__(self, tokens: Mapping[str, Principal]) -> None:
        self._tokens = dict(tokens)

    async def authenticate(self, token: str) -> Principal:
        try:
            return self._tokens[token]
        except KeyError:
            raise AuthError("Token invalido") from None


class ListSource:
    source_name = "sap"

    def __init__(self, payloads: list[Mapping[str, Any]], error: Exception | None = None):
        self._payloads = list(payloads)
        self._error = error

    async def stream(self):
        for payload in self._payloads:
            yield payload
        if self._error is not None:
            raise self._error


class DictMapper:
    """Mapeo solo para pruebas (esquema ficticio, no es el de SAP/PLUZ)."""

    def map(self, payload: Mapping[str, Any]) -> MappedWorkOrder:
        try:
            location = None
            if payload.get("latitude") is not None:
                location = GeoPoint(
                    latitude=float(payload["latitude"]),
                    longitude=float(payload["longitude"]),
                )
            return MappedWorkOrder(
                external_id=str(payload["external_id"]),
                order=NormalizedWorkOrder(
                    code=str(payload["code"]),
                    type=WorkOrderType(payload["type"]),
                    priority=int(payload["priority"]),
                    customer_name=payload.get("customer_name"),
                    supply_number=payload.get("supply_number"),
                    address=payload.get("address"),
                    district=payload.get("district"),
                    zone=payload.get("zone"),
                    location=location,
                    scheduled_at=payload.get("scheduled_at"),
                    due_at=payload.get("due_at"),
                ),
            )
        except KeyError as exc:
            raise ValueError(f"payload sin el campo obligatorio {exc.args[0]}") from exc


class FakeSyncSession:
    def __init__(self) -> None:
        self.batches: dict[UUID, dict[str, Any]] = {}
        self.records: dict[UUID, dict[str, Any]] = {}
        self.orders_by_ref: dict[tuple[str, str], ExistingWorkOrder] = {}
        self.orders_by_id: dict[UUID, ExistingWorkOrder] = {}
        self.applied: list[UUID] = []

    async def start_batch(
        self, *, source: str, entity: str, notes: str | None
    ) -> UUID:
        batch_id = uuid4()
        self.batches[batch_id] = {
            "source": source,
            "entity": entity,
            "notes": notes,
            "status": IngestBatchStatus.RECIBIDO,
            "records_count": 0,
            "payload_hash": None,
        }
        return batch_id

    async def add_record(
        self,
        *,
        batch_id: UUID,
        source: str,
        entity: str,
        payload: Mapping[str, Any],
        payload_hash: str,
    ) -> UUID | None:
        for record in self.records.values():
            if (
                record["source"],
                record["entity"],
                record["payload_hash"],
            ) == (source, entity, payload_hash):
                if record["status"] is IngestRecordStatus.ERROR:
                    record.update(
                        batch_id=batch_id,
                        status=IngestRecordStatus.RECIBIDO,
                        work_order_id=None,
                        external_id=None,
                        error_message=None,
                    )
                    return record["id"]
                return None

        record_id = uuid4()
        self.records[record_id] = {
            "id": record_id,
            "batch_id": batch_id,
            "source": source,
            "entity": entity,
            "payload": payload,
            "payload_hash": payload_hash,
            "status": IngestRecordStatus.RECIBIDO,
            "work_order_id": None,
            "external_id": None,
            "error_message": None,
        }
        return record_id

    async def mark_record(
        self,
        record_id: UUID,
        *,
        status: IngestRecordStatus,
        work_order_id: UUID | None,
        external_id: str | None,
        error_message: str | None,
    ) -> None:
        self.records[record_id].update(
            status=status,
            work_order_id=work_order_id,
            external_id=external_id,
            error_message=error_message,
        )

    async def finish_batch(
        self,
        batch_id: UUID,
        *,
        status: IngestBatchStatus,
        records_count: int,
        payload_hash: str | None,
        notes: str | None,
    ) -> None:
        self.batches[batch_id].update(
            status=status,
            records_count=records_count,
            payload_hash=payload_hash,
            notes=notes,
        )

    async def apply_external_order(
        self, *, source: str, mapped: MappedWorkOrder
    ) -> ApplyOutcome:
        key = (source, mapped.external_id)
        existing = self.orders_by_ref.get(key)
        decision = plan_upsert(mapped.order, existing)

        if decision.action is SyncAction.CREATE:
            order_id = uuid4()
            order = mapped.order
            stored = ExistingWorkOrder(
                id=order_id,
                code=order.code,
                status=WorkOrderStatus.PENDIENTE,
                type=order.type,
                priority=order.priority,
                customer_name=order.customer_name,
                supply_number=order.supply_number,
                address=order.address,
                district=order.district,
                zone=order.zone,
                location=order.location,
                scheduled_at=order.scheduled_at,
                due_at=order.due_at,
            )
            self.orders_by_ref[key] = stored
            self.orders_by_id[order_id] = stored
            self.applied.append(order_id)
            return ApplyOutcome(action=SyncAction.CREATE, work_order_id=order_id)

        assert existing is not None

        if decision.action is SyncAction.UPDATE:
            updated = replace(existing, **decision.changes)
            self.orders_by_ref[key] = updated
            self.orders_by_id[existing.id] = updated
            self.applied.append(existing.id)
            return ApplyOutcome(action=SyncAction.UPDATE, work_order_id=existing.id)

        return ApplyOutcome(
            action=SyncAction.SKIP,
            work_order_id=existing.id,
            reason=decision.reason.value if decision.reason else None,
        )


class FakeSyncStore:
    def __init__(self, session: FakeSyncSession | None = None, acquired: bool = True):
        self.session = session or FakeSyncSession()
        self.acquired = acquired
        self.sources: list[str] = []

    @asynccontextmanager
    async def open_run(self, source: str):
        self.sources.append(source)
        yield self.session, self.acquired


def make_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "external_id": "EXT-0001",
        "code": "WO-TEST-0001",
        "type": "corte",
        "priority": 2,
        "customer_name": "Cliente Ficticio",
        "address": "Av. Demo 100",
        "district": "Miraflores",
        "latitude": -12.1219,
        "longitude": -77.0297,
    }
    payload.update(overrides)
    return payload


def make_existing(
    *,
    status: WorkOrderStatus = WorkOrderStatus.PENDIENTE,
    **overrides: Any,
) -> ExistingWorkOrder:
    values: dict[str, Any] = {
        "id": uuid4(),
        "code": "WO-TEST-0001",
        "status": status,
        "type": WorkOrderType.CORTE,
        "priority": 2,
        "customer_name": "Cliente Ficticio",
        "address": "Av. Demo 100",
        "district": "Miraflores",
        "location": GeoPoint(latitude=-12.1219, longitude=-77.0297),
    }
    values.update(overrides)
    return ExistingWorkOrder(**values)
