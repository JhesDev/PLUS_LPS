from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.domain import (
    GeoPoint,
    NormalizedWorkOrder,
    SkipReason,
    SyncAction,
    WorkOrderStatus,
    WorkOrderType,
    hash_payload,
    plan_upsert,
)

from .fakes import make_existing


def _incoming(**overrides) -> NormalizedWorkOrder:
    values = {
        "code": "WO-TEST-0001",
        "type": WorkOrderType.CORTE,
        "priority": 2,
        "customer_name": "Cliente Ficticio",
        "address": "Av. Demo 100",
        "district": "Miraflores",
        "location": GeoPoint(latitude=-12.1219, longitude=-77.0297),
    }
    values.update(overrides)
    return NormalizedWorkOrder(**values)


def test_creates_when_order_does_not_exist() -> None:
    decision = plan_upsert(_incoming(), None)

    assert decision.action is SyncAction.CREATE
    assert decision.changes == {}


def test_skips_order_in_progress_without_touching_anything() -> None:
    existing = make_existing(status=WorkOrderStatus.ASIGNADA)
    incoming = _incoming(address="Otra direccion", priority=5)

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.SKIP
    assert decision.reason is SkipReason.ORDER_IN_PROGRESS
    assert decision.changes == {}


@pytest.mark.parametrize(
    "status",
    [
        WorkOrderStatus.EJECUTADA,
        WorkOrderStatus.IMPOSIBILITADA,
        WorkOrderStatus.CANCELADA,
    ],
)
def test_skips_closed_orders(status: WorkOrderStatus) -> None:
    decision = plan_upsert(_incoming(address="Otra direccion"), make_existing(status=status))

    assert decision.action is SyncAction.SKIP
    assert decision.reason is SkipReason.ORDER_CLOSED
    assert decision.changes == {}


def test_skips_when_nothing_changed() -> None:
    decision = plan_upsert(_incoming(), make_existing())

    assert decision.action is SyncAction.SKIP
    assert decision.reason is SkipReason.NO_CHANGES
    assert decision.changes == {}


def test_updates_only_external_descriptive_fields() -> None:
    existing = make_existing()
    incoming = _incoming(
        priority=4,
        address="Av. Nueva 456",
        type=WorkOrderType.MANTENIMIENTO,
    )

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.UPDATE
    assert decision.changes == {
        "type": WorkOrderType.MANTENIMIENTO,
        "priority": 4,
        "address": "Av. Nueva 456",
    }
    assert "status" not in decision.changes
    assert "code" not in decision.changes


def test_null_values_do_not_erase_local_data() -> None:
    existing = make_existing()
    incoming = _incoming(address=None, district=None, customer_name=None)

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.SKIP
    assert decision.reason is SkipReason.NO_CHANGES


def test_existing_location_is_never_replaced() -> None:
    existing = make_existing(location=GeoPoint(latitude=-12.1, longitude=-77.0))
    incoming = _incoming(location=GeoPoint(latitude=-11.0, longitude=-75.0))

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.SKIP
    assert "location" not in decision.changes


def test_missing_location_is_filled_from_external_data() -> None:
    existing = make_existing(location=None)
    incoming = _incoming(location=GeoPoint(latitude=-12.5, longitude=-76.9))

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.UPDATE
    assert decision.changes == {"location": GeoPoint(latitude=-12.5, longitude=-76.9)}


def test_priority_out_of_range_is_rejected() -> None:
    with pytest.raises(ValueError):
        _incoming(priority=0)


def test_naive_datetime_is_rejected() -> None:
    with pytest.raises(ValueError):
        _incoming(scheduled_at=datetime(2026, 10, 23, 9, 0))


def test_aware_datetime_is_accepted_and_compared() -> None:
    existing = make_existing()
    incoming = _incoming(scheduled_at=datetime(2026, 10, 23, 9, 0, tzinfo=UTC))

    decision = plan_upsert(incoming, existing)

    assert decision.action is SyncAction.UPDATE
    assert decision.changes == {
        "scheduled_at": datetime(2026, 10, 23, 9, 0, tzinfo=UTC)
    }


def test_payload_hash_is_independent_of_key_order() -> None:
    first = {"a": 1, "b": {"c": 2, "d": 3}}
    second = {"b": {"d": 3, "c": 2}, "a": 1}

    assert hash_payload(first) == hash_payload(second)
    assert hash_payload(first) == hash_payload(second)
    assert hash_payload({"a": 2}) != hash_payload(first)
