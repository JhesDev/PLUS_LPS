"""Servicio de sincronizacion idempotente con el origen externo.

Responsabilidades:

1. Verificar que la integracion tenga contrato/adaptadores disponibles.
2. Serializar corridas concurrentes del mismo origen (lock en PostgreSQL).
3. Guardar SIEMPRE el payload crudo en ``ingest`` antes de normalizar.
4. Deduplicar payloads identicos por hash.
5. Aplicar cambios solo en campos externos y solo mientras la orden siga en
   ``pendiente`` (ver ``app.domain.plan_upsert``).
6. Cerrar el lote con un estado trazable (``procesado``/``parcial``/``error``).
"""

from __future__ import annotations

import hashlib
import logging
from collections.abc import AsyncIterator, Mapping
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from ..domain import (
    IngestBatchStatus,
    IngestRecordStatus,
    SyncAction,
    hash_payload,
)
from ..errors import ExternalSourceError, IntegrationPending, RunAlreadyInProgress
from ..ports import SyncStore, WorkOrderMapper, WorkOrderSource

logger = logging.getLogger(__name__)

_MAX_ERROR_LENGTH = 500


@dataclass(frozen=True, slots=True)
class IntegrationAvailability:
    configured: bool
    source: str
    missing: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class SyncRunResult:
    batch_id: UUID
    status: IngestBatchStatus
    received: int
    created: int
    updated: int
    skipped: int
    duplicates: int
    errors: int


class _SourceFailure(Exception):
    """Envuelve un fallo del origen para no confundirlo con uno de base de datos."""

    def __init__(self, cause: Exception) -> None:
        super().__init__(str(cause))
        self.cause = cause


class SyncService:
    def __init__(
        self,
        *,
        source_name: str,
        entity: str = "work_order",
        source: WorkOrderSource | None = None,
        mapper: WorkOrderMapper | None = None,
        store: SyncStore | None = None,
        missing: tuple[str, ...] | list[str] = (),
    ) -> None:
        self._source_name = source_name
        self._entity = entity
        self._source = source
        self._mapper = mapper
        self._store = store

        requirements = list(missing)
        if not requirements:
            if source is None:
                requirements.append("Adaptador del origen externo (autenticacion/paginacion)")
            if mapper is None:
                requirements.append("Mapeo de campos externos al modelo interno")
            if store is None:
                requirements.append("Acceso a PostgreSQL para ingesta y sincronizacion")
        self._missing = tuple(dict.fromkeys(requirements))

    @property
    def source_name(self) -> str:
        return self._source_name

    def availability(self) -> IntegrationAvailability:
        return IntegrationAvailability(
            configured=not self._missing,
            source=self._source_name,
            missing=self._missing,
        )

    async def run(self) -> SyncRunResult:
        source = self._source
        mapper = self._mapper
        store = self._store

        if self._missing or source is None or mapper is None or store is None:
            raise IntegrationPending(self._missing)

        received = created = updated = skipped = duplicates = errors = 0
        digests: list[str] = []
        source_failure: Exception | None = None
        database_failure: Exception | None = None
        batch_id: UUID | None = None
        batch_status = IngestBatchStatus.ERROR

        async with store.open_run(self._source_name) as (session, acquired):
            if not acquired:
                raise RunAlreadyInProgress(self._source_name)

            batch_id = await session.start_batch(
                source=self._source_name,
                entity=self._entity,
                notes="Sincronizacion iniciada",
            )

            try:
                async for payload in _guarded_stream(source):
                    received += 1
                    digest = hash_payload(payload)
                    digests.append(digest)

                    record_id = await session.add_record(
                        batch_id=batch_id,
                        source=self._source_name,
                        entity=self._entity,
                        payload=payload,
                        payload_hash=digest,
                    )
                    if record_id is None:
                        duplicates += 1
                        continue

                    # Un payload invalido o un conflicto de una orden no debe
                    # tumbar el lote: se registra el error y se continua.
                    try:
                        mapped = mapper.map(payload)
                        outcome = await session.apply_external_order(
                            source=self._source_name,
                            mapped=mapped,
                        )
                    except Exception as exc:
                        errors += 1
                        logger.warning(
                            "sync.record_failed source=%s record=%s error=%s",
                            self._source_name,
                            record_id,
                            type(exc).__name__,
                        )
                        await session.mark_record(
                            record_id,
                            status=IngestRecordStatus.ERROR,
                            work_order_id=None,
                            external_id=None,
                            error_message=_safe_error(exc),
                        )
                        continue

                    if outcome.action is SyncAction.CREATE:
                        created += 1
                    elif outcome.action is SyncAction.UPDATE:
                        updated += 1
                    else:
                        skipped += 1

                    await session.mark_record(
                        record_id,
                        status=(
                            IngestRecordStatus.PROCESADO
                            if outcome.action is not SyncAction.SKIP
                            else IngestRecordStatus.OMITIDO
                        ),
                        work_order_id=outcome.work_order_id,
                        external_id=mapped.external_id,
                        error_message=outcome.reason,
                    )
            except _SourceFailure as exc:
                source_failure = exc.cause
            except Exception as exc:
                # Fallo de base de datos o de serializacion: no es un fallo del
                # origen. Se cierra el lote como error y se propaga el original.
                database_failure = exc

            failure = source_failure or database_failure
            batch_status = _batch_status(failure, errors, created + updated + skipped)
            notes = _build_notes(
                received=received,
                duplicates=duplicates,
                created=created,
                updated=updated,
                skipped=skipped,
                errors=errors,
                failure=failure,
            )

            try:
                await session.finish_batch(
                    batch_id,
                    status=batch_status,
                    records_count=received,
                    payload_hash=_combined_hash(digests),
                    notes=notes,
                )
            except Exception:
                logger.exception("sync.finish_batch_failed batch=%s", batch_id)
                if failure is None:
                    raise

        if database_failure is not None:
            raise database_failure
        if source_failure is not None:
            raise ExternalSourceError(
                "No se pudo completar la lectura del origen externo."
            ) from source_failure

        assert batch_id is not None
        logger.info(
            "sync.finished source=%s batch=%s received=%s created=%s updated=%s "
            "skipped=%s duplicates=%s errors=%s",
            self._source_name,
            batch_id,
            received,
            created,
            updated,
            skipped,
            duplicates,
            errors,
        )
        return SyncRunResult(
            batch_id=batch_id,
            status=batch_status,
            received=received,
            created=created,
            updated=updated,
            skipped=skipped,
            duplicates=duplicates,
            errors=errors,
        )


async def _guarded_stream(
    source: WorkOrderSource,
) -> AsyncIterator[Mapping[str, Any]]:
    """Convierte cualquier fallo del origen en ``_SourceFailure``."""

    try:
        async for payload in source.stream():
            yield payload
    except Exception as exc:
        raise _SourceFailure(exc) from exc


def _batch_status(
    failure: Exception | None, errors: int, succeeded: int
) -> IngestBatchStatus:
    if failure is not None:
        return IngestBatchStatus.ERROR
    if errors == 0:
        return IngestBatchStatus.PROCESADO
    return IngestBatchStatus.PARCIAL if succeeded else IngestBatchStatus.ERROR


def _combined_hash(digests: list[str]) -> str | None:
    if not digests:
        return None
    return hashlib.sha256("\n".join(digests).encode("utf-8")).hexdigest()


def _safe_error(exc: Exception) -> str:
    message = " ".join(str(exc).split())
    if not message:
        message = type(exc).__name__
    return message[:_MAX_ERROR_LENGTH]


def _build_notes(
    *,
    received: int,
    duplicates: int,
    created: int,
    updated: int,
    skipped: int,
    errors: int,
    failure: Exception | None,
) -> str:
    parts = [
        f"recibidos={received}",
        f"duplicados={duplicates}",
        f"creados={created}",
        f"actualizados={updated}",
        f"omitidos={skipped}",
        f"errores={errors}",
    ]
    if failure is not None:
        parts.append(f"fallo={type(failure).__name__}")
    return "; ".join(parts)
