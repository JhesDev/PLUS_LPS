"""Adaptador PostgreSQL (asyncpg) para ingesta y sincronizacion.

Se usa conexion directa (no PostgREST) por dos motivos concretos:

* el esquema ``ingest`` no esta expuesto en ``config.toml``;
* aplicar un registro requiere leer y escribir dentro de una misma transaccion.

La conexion se abre solo durante una corrida y opera con el rol configurado
(``DB_SERVICE_ROLE``, por defecto ``service_role``). Es un secreto exclusivo del
servidor: nunca se envia al frontend ni se registra en logs.

Se eligio asyncpg y no psycopg async porque, en Windows, Uvicorn usa
``ProactorEventLoop`` y psycopg async no lo soporta.
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from collections.abc import AsyncIterator, Mapping
from contextlib import asynccontextmanager
from typing import Any
from uuid import UUID

import asyncpg
from asyncpg.exceptions import UniqueViolationError

from ..domain import (
    ApplyOutcome,
    ExistingWorkOrder,
    GeoPoint,
    IngestBatchStatus,
    IngestRecordStatus,
    MappedWorkOrder,
    SyncAction,
    WorkOrderStatus,
    WorkOrderType,
    plan_upsert,
)
from ..errors import SyncApplyError

logger = logging.getLogger(__name__)

_ROLE_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

_SELECT_EXISTING = """
select
  id,
  code,
  status::text as status,
  type::text as type,
  priority,
  customer_name,
  supply_number,
  address,
  district,
  zone,
  extensions.ST_Y(location) as latitude,
  extensions.ST_X(location) as longitude,
  scheduled_at,
  due_at
from public.work_orders
where external_source = $1
  and external_id = $2
for update
"""

_INSERT_ORDER = """
insert into public.work_orders (
  code,
  external_source,
  external_id,
  type,
  priority,
  customer_name,
  supply_number,
  address,
  district,
  zone,
  location,
  scheduled_at,
  due_at
)
values (
  $1,
  $2,
  $3,
  $4::public.work_order_type,
  $5,
  $6,
  $7,
  $8,
  $9,
  $10,
  case
    when $12::float8 is null then null
    else extensions.ST_SetSRID(
           extensions.ST_MakePoint($11::float8, $12::float8),
           4326
         )
  end,
  $13,
  $14
)
on conflict (external_source, external_id) where external_id is not null
do nothing
returning id
"""

_UPDATE_ORDER = """
update public.work_orders
set
  type = $1::public.work_order_type,
  priority = $2,
  customer_name = coalesce($3, customer_name),
  supply_number = coalesce($4, supply_number),
  address = coalesce($5, address),
  district = coalesce($6, district),
  zone = coalesce($7, zone),
  location = case
    when location is null and $9::float8 is not null
      then extensions.ST_SetSRID(
             extensions.ST_MakePoint($8::float8, $9::float8),
             4326
           )
    else location
  end,
  scheduled_at = coalesce($10, scheduled_at),
  due_at = coalesce($11, due_at)
where id = $12
  and status = 'pendiente'
returning id
"""

_INSERT_BATCH = """
insert into ingest.batches (source, status, records_count, notes)
values ($1, 'recibido', 0, $2)
returning id
"""

# Si el mismo payload ya existe y su ultimo intento fallo, se reutiliza el
# registro (mismo payload_hash) y se reintenta. Si ya fue procesado, no se toca.
_INSERT_RECORD = """
insert into ingest.records (batch_id, source, entity, payload, payload_hash)
values ($1, $2, $3, $4::jsonb, $5)
on conflict (source, entity, payload_hash) do update
  set batch_id = excluded.batch_id,
      status = 'recibido',
      work_order_id = null,
      external_id = null,
      error_message = null,
      processed_at = null
  where ingest.records.status = 'error'
returning id
"""

_MARK_RECORD = """
update ingest.records
set status = $2::ingest.record_status,
    work_order_id = $3,
    external_id = coalesce($4, external_id),
    error_message = $5,
    processed_at = now()
where id = $1
"""

_FINISH_BATCH = """
update ingest.batches
set status = $2::ingest.batch_status,
    records_count = $3,
    payload_hash = $4,
    notes = $5
where id = $1
"""


class PostgresSyncSession:
    """Sesion de una corrida; comparte conexion y lock con el resto del run."""

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def start_batch(
        self, *, source: str, entity: str, notes: str | None
    ) -> UUID:
        # ``entity`` se conserva en la firma para simetria con add_record; el
        # lote agrupa registros de cualquier entidad del mismo origen.
        del entity
        async with self._conn.transaction():
            batch_id = await self._conn.fetchval(_INSERT_BATCH, source, notes)
        if batch_id is None:  # pragma: no cover - INSERT ... RETURNING siempre devuelve
            raise SyncApplyError("No se pudo crear el lote de ingesta")
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
        serialized = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
        async with self._conn.transaction():
            return await self._conn.fetchval(
                _INSERT_RECORD,
                batch_id,
                source,
                entity,
                serialized,
                payload_hash,
            )

    async def mark_record(
        self,
        record_id: UUID,
        *,
        status: IngestRecordStatus,
        work_order_id: UUID | None,
        external_id: str | None,
        error_message: str | None,
    ) -> None:
        async with self._conn.transaction():
            await self._conn.execute(
                _MARK_RECORD,
                record_id,
                status.value,
                work_order_id,
                external_id,
                error_message,
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
        async with self._conn.transaction():
            await self._conn.execute(
                _FINISH_BATCH,
                batch_id,
                status.value,
                records_count,
                payload_hash,
                notes,
            )

    async def apply_external_order(
        self, *, source: str, mapped: MappedWorkOrder
    ) -> ApplyOutcome:
        params = _order_params(source=source, mapped=mapped)

        async with self._conn.transaction():
            row = await self._conn.fetchrow(
                _SELECT_EXISTING, source, mapped.external_id
            )
            existing = _row_to_existing(row) if row is not None else None
            decision = plan_upsert(mapped.order, existing)

            if decision.action is SyncAction.CREATE:
                try:
                    inserted = await self._conn.fetchval(
                        _INSERT_ORDER,
                        params["code"],
                        source,
                        mapped.external_id,
                        params["type"],
                        params["priority"],
                        params["customer_name"],
                        params["supply_number"],
                        params["address"],
                        params["district"],
                        params["zone"],
                        params["longitude"],
                        params["latitude"],
                        params["scheduled_at"],
                        params["due_at"],
                    )
                except UniqueViolationError as exc:
                    raise SyncApplyError(
                        "El codigo de orden ya existe y pertenece a otra orden interna"
                    ) from exc
                if inserted is None:
                    raise SyncApplyError(
                        "La orden externa fue insertada por otro proceso concurrente"
                    )
                return ApplyOutcome(
                    action=SyncAction.CREATE, work_order_id=inserted
                )

            assert existing is not None  # plan_upsert solo devuelve CREATE sin existente

            if decision.action is SyncAction.UPDATE:
                updated = await self._conn.fetchval(
                    _UPDATE_ORDER,
                    params["type"],
                    params["priority"],
                    params["customer_name"],
                    params["supply_number"],
                    params["address"],
                    params["district"],
                    params["zone"],
                    params["longitude"],
                    params["latitude"],
                    params["scheduled_at"],
                    params["due_at"],
                    existing.id,
                )
                if updated is None:
                    return ApplyOutcome(
                        action=SyncAction.SKIP,
                        work_order_id=existing.id,
                        reason="order_left_pending",
                    )
                return ApplyOutcome(
                    action=SyncAction.UPDATE, work_order_id=existing.id
                )

            return ApplyOutcome(
                action=SyncAction.SKIP,
                work_order_id=existing.id,
                reason=decision.reason.value if decision.reason else None,
            )


class PostgresSyncStore:
    def __init__(self, dsn: str, service_role: str | None = "service_role") -> None:
        self._dsn = dsn
        self._service_role = service_role

    @asynccontextmanager
    async def open_run(
        self, source: str
    ) -> AsyncIterator[tuple[PostgresSyncSession, bool]]:
        conn = await asyncpg.connect(self._dsn)
        try:
            if self._service_role:
                if not _ROLE_NAME.match(self._service_role):
                    raise RuntimeError("DB_SERVICE_ROLE contiene caracteres invalidos")
                await conn.execute(f'set role "{self._service_role}"')

            lock_key = _advisory_key(source)
            acquired = bool(
                await conn.fetchval("select pg_try_advisory_lock($1)", lock_key)
            )

            try:
                yield PostgresSyncSession(conn), acquired
            finally:
                if acquired:
                    try:
                        await conn.fetchval(
                            "select pg_advisory_unlock($1)", lock_key
                        )
                    except Exception:  # pragma: no cover - cierre defensivo
                        logger.warning(
                            "sync.advisory_unlock_failed source=%s", source
                        )
        finally:
            await conn.close()


def _advisory_key(source: str) -> int:
    digest = hashlib.sha256(f"plus_lps.sync:{source}".encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big", signed=True)


def _order_params(*, source: str, mapped: MappedWorkOrder) -> dict[str, Any]:
    order = mapped.order
    location = order.location
    return {
        "source": source,
        "external_id": mapped.external_id,
        "code": order.code,
        "type": order.type.value,
        "priority": order.priority,
        "customer_name": order.customer_name,
        "supply_number": order.supply_number,
        "address": order.address,
        "district": order.district,
        "zone": order.zone,
        "latitude": location.latitude if location else None,
        "longitude": location.longitude if location else None,
        "scheduled_at": order.scheduled_at,
        "due_at": order.due_at,
    }


def _row_to_existing(row: Mapping[str, Any]) -> ExistingWorkOrder:
    location = None
    if row["latitude"] is not None and row["longitude"] is not None:
        location = GeoPoint(
            latitude=float(row["latitude"]),
            longitude=float(row["longitude"]),
        )

    return ExistingWorkOrder(
        id=row["id"],
        code=row["code"],
        status=WorkOrderStatus(row["status"]),
        type=WorkOrderType(row["type"]),
        priority=int(row["priority"]),
        customer_name=row["customer_name"],
        supply_number=row["supply_number"],
        address=row["address"],
        district=row["district"],
        zone=row["zone"],
        location=location,
        scheduled_at=row["scheduled_at"],
        due_at=row["due_at"],
    )
