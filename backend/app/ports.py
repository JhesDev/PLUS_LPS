"""Puertos (protocolos) entre la logica de sincronizacion y la infraestructura.

La API externa aun no tiene contrato oficial. Estos protocolos son la frontera
que debera implementar el adaptador cuando llegue la documentacion; el servicio
de sincronizacion no depende de ningun endpoint, campo ni formato externo.
"""

from __future__ import annotations

from collections.abc import AsyncIterator, Mapping
from contextlib import AbstractAsyncContextManager
from typing import Any, Protocol
from uuid import UUID

from .domain import (
    ApplyOutcome,
    IngestBatchStatus,
    IngestRecordStatus,
    MappedWorkOrder,
)


class WorkOrderSource(Protocol):
    """Origen externo de ordenes.

    El adaptador concreto es responsable de autenticacion, paginacion,
    reintentos y de entregar payloads individuales sin interpretarlos.
    """

    source_name: str

    def stream(self) -> AsyncIterator[Mapping[str, Any]]:
        """Itera payloads crudos. Puede ser un generador asincrono."""
        ...


class WorkOrderMapper(Protocol):
    """Traduce un payload externo al modelo canonico interno.

    Aqui se concentra el conocimiento del JSON externo (nombres de campos,
    formatos de fecha, estados). No se implementa hasta recibir el contrato.
    """

    def map(self, payload: Mapping[str, Any]) -> MappedWorkOrder: ...


class SyncSession(Protocol):
    """Operaciones de una corrida, sobre una unica conexion/transaccion logica."""

    async def start_batch(
        self, *, source: str, entity: str, notes: str | None
    ) -> UUID: ...

    async def add_record(
        self,
        *,
        batch_id: UUID,
        source: str,
        entity: str,
        payload: Mapping[str, Any],
        payload_hash: str,
    ) -> UUID | None:
        """Inserta el registro crudo. Devuelve ``None`` si es duplicado exacto."""
        ...

    async def mark_record(
        self,
        record_id: UUID,
        *,
        status: IngestRecordStatus,
        work_order_id: UUID | None,
        external_id: str | None,
        error_message: str | None,
    ) -> None: ...

    async def finish_batch(
        self,
        batch_id: UUID,
        *,
        status: IngestBatchStatus,
        records_count: int,
        payload_hash: str | None,
        notes: str | None,
    ) -> None: ...

    async def apply_external_order(
        self, *, source: str, mapped: MappedWorkOrder
    ) -> ApplyOutcome:
        """Aplica la orden externa respetando la idempotencia.

        Debe leer y escribir dentro de una transaccion y nunca modificar
        estado, asignaciones, avances ni resultados locales.
        """
        ...


class SyncStore(Protocol):
    def open_run(
        self, source: str
    ) -> AbstractAsyncContextManager[tuple[SyncSession, bool]]:
        """Abre una corrida y devuelve ``(sesion, lock_adquirido)``.

        ``lock_adquirido=False`` indica que ya hay otra sincronizacion del mismo
        origen en ejecucion; la sesion se cierra igualmente.
        """
        ...
