"""Modelo canonico y reglas de sincronizacion idempotente.

Este modulo NO conoce la API externa: trabaja con datos ya normalizados a los
nombres internos del modelo. El mapeo desde el JSON de SAP/PLUZ es un puerto
aparte (``app.ports.WorkOrderMapper``) que sigue pendiente del contrato oficial.

Invariantes que se prueban en ``tests/test_domain.py``:

* una actualizacion externa nunca modifica el estado operativo de la orden;
* nunca borra ni sobrescribe asignaciones, avances o resultados locales;
* un payload identico se procesa como maximo una vez (idempotencia);
* los campos nulos del origen no borran datos ya guardados;
* una ubicacion ya informada no se reemplaza por la del origen.
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Mapping
from uuid import UUID


class AppRole(str, Enum):
    COORDINADOR = "coordinador"
    DESPACHADOR = "despachador"
    TECNICO = "tecnico"


class WorkOrderType(str, Enum):
    CORTE = "corte"
    REPOSICION = "reposicion"
    INSPECCION = "inspeccion"
    RECONEXION = "reconexion"
    MANTENIMIENTO = "mantenimiento"
    OTRO = "otro"


class WorkOrderStatus(str, Enum):
    PENDIENTE = "pendiente"
    ASIGNADA = "asignada"
    EN_PROCESO = "en_proceso"
    EJECUTADA = "ejecutada"
    IMPOSIBILITADA = "imposibilitada"
    CANCELADA = "cancelada"

    @property
    def is_closed(self) -> bool:
        return self in {
            WorkOrderStatus.EJECUTADA,
            WorkOrderStatus.IMPOSIBILITADA,
            WorkOrderStatus.CANCELADA,
        }


class IngestBatchStatus(str, Enum):
    RECIBIDO = "recibido"
    PROCESADO = "procesado"
    PARCIAL = "parcial"
    ERROR = "error"


class IngestRecordStatus(str, Enum):
    RECIBIDO = "recibido"
    PROCESADO = "procesado"
    OMITIDO = "omitido"
    ERROR = "error"


class SyncAction(str, Enum):
    CREATE = "create"
    UPDATE = "update"
    SKIP = "skip"


class SkipReason(str, Enum):
    NO_CHANGES = "no_changes"
    ORDER_IN_PROGRESS = "order_in_progress"
    ORDER_CLOSED = "order_closed"


@dataclass(frozen=True, slots=True)
class GeoPoint:
    latitude: float
    longitude: float

    def __post_init__(self) -> None:
        if not math.isfinite(self.latitude) or not math.isfinite(self.longitude):
            raise ValueError("La ubicacion debe contener numeros finitos")
        if not -90 <= self.latitude <= 90:
            raise ValueError("La latitud debe estar entre -90 y 90")
        if not -180 <= self.longitude <= 180:
            raise ValueError("La longitud debe estar entre -180 y 180")


@dataclass(frozen=True, slots=True)
class NormalizedWorkOrder:
    """Orden ya mapeada desde el origen externo.

    ``code`` es obligatorio para crear; en actualizaciones se ignora para no
    romper referencias internas (la identidad externa es ``external_id``).
    """

    code: str
    type: WorkOrderType
    priority: int
    customer_name: str | None = None
    supply_number: str | None = None
    address: str | None = None
    district: str | None = None
    zone: str | None = None
    location: GeoPoint | None = None
    scheduled_at: datetime | None = None
    due_at: datetime | None = None

    def __post_init__(self) -> None:
        code = self.code.strip()
        if not code:
            raise ValueError("El codigo de orden no puede estar vacio")
        object.__setattr__(self, "code", code)

        if isinstance(self.priority, bool) or not isinstance(self.priority, int):
            raise ValueError("La prioridad debe ser un entero")
        if not 1 <= self.priority <= 5:
            raise ValueError("La prioridad debe estar entre 1 y 5")

        for name in ("scheduled_at", "due_at"):
            value = getattr(self, name)
            if value is not None and (value.tzinfo is None or value.utcoffset() is None):
                raise ValueError(f"{name} debe incluir zona horaria")


@dataclass(frozen=True, slots=True)
class MappedWorkOrder:
    external_id: str
    order: NormalizedWorkOrder

    def __post_init__(self) -> None:
        external_id = self.external_id.strip()
        if not external_id:
            raise ValueError("El identificador externo no puede estar vacio")
        object.__setattr__(self, "external_id", external_id)


@dataclass(frozen=True, slots=True)
class ExistingWorkOrder:
    """Foto de la orden local, suficiente para decidir sin escribir."""

    id: UUID
    code: str
    status: WorkOrderStatus
    type: WorkOrderType
    priority: int
    customer_name: str | None = None
    supply_number: str | None = None
    address: str | None = None
    district: str | None = None
    zone: str | None = None
    location: GeoPoint | None = None
    scheduled_at: datetime | None = None
    due_at: datetime | None = None


@dataclass(frozen=True, slots=True)
class SyncDecision:
    action: SyncAction
    reason: SkipReason | None = None
    changes: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class ApplyOutcome:
    action: SyncAction
    work_order_id: UUID
    reason: str | None = None


# Campos descriptivos que SI puede administrar el origen externo.
# status, cancellation_reason, completed_at, created_by y updated_by quedan
# fuera por diseno: son decisiones operativas internas.
_EXTERNAL_TEXT_FIELDS = (
    "customer_name",
    "supply_number",
    "address",
    "district",
    "zone",
)
_EXTERNAL_TIME_FIELDS = ("scheduled_at", "due_at")


def hash_payload(payload: Mapping[str, Any]) -> str:
    """Huella estable (claves ordenadas) usada para deduplicar en ``ingest``."""

    canonical = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def plan_upsert(
    incoming: NormalizedWorkOrder,
    existing: ExistingWorkOrder | None,
) -> SyncDecision:
    """Decide que hacer con una orden sin ejecutar ninguna escritura.

    * Sin orden local -> crear.
    * Orden local en ``pendiente`` -> actualizar solo campos externos cambiados.
    * Orden asignada/en proceso/cerrada -> no tocar nada (se audita el payload).
    """

    if existing is None:
        return SyncDecision(action=SyncAction.CREATE)

    if existing.status is not WorkOrderStatus.PENDIENTE:
        reason = (
            SkipReason.ORDER_CLOSED
            if existing.status.is_closed
            else SkipReason.ORDER_IN_PROGRESS
        )
        return SyncDecision(action=SyncAction.SKIP, reason=reason)

    changes: dict[str, Any] = {}

    if incoming.type is not existing.type:
        changes["type"] = incoming.type
    if incoming.priority != existing.priority:
        changes["priority"] = incoming.priority

    for name in _EXTERNAL_TEXT_FIELDS:
        value = getattr(incoming, name)
        if value is not None and value != getattr(existing, name):
            changes[name] = value

    for name in _EXTERNAL_TIME_FIELDS:
        value = getattr(incoming, name)
        if value is not None and value != getattr(existing, name):
            changes[name] = value

    # La ubicacion puede haber sido corregida manualmente: solo se rellena si
    # la orden aun no tiene punto geografico.
    if incoming.location is not None and existing.location is None:
        changes["location"] = incoming.location

    if not changes:
        return SyncDecision(action=SyncAction.SKIP, reason=SkipReason.NO_CHANGES)

    return SyncDecision(action=SyncAction.UPDATE, changes=changes)
