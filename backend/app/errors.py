"""Errores de aplicacion con codigo estable para el cliente.

Los mensajes son aptos para el usuario: nunca incluyen trazas, tokens ni
detalles del payload externo.
"""

from __future__ import annotations

from collections.abc import Sequence


class AppError(Exception):
    status_code: int = 500
    code: str = "INTERNAL_ERROR"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class AuthError(AppError):
    """Token ausente/invalido o identidad no utilizable."""

    def __init__(self, message: str, *, status_code: int = 401) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = "FORBIDDEN" if status_code == 403 else "UNAUTHENTICATED"


class ForbiddenError(AppError):
    status_code = 403
    code = "FORBIDDEN"

    def __init__(self, message: str) -> None:
        super().__init__(message)


class IntegrationPending(AppError):
    """La API externa aun no tiene contrato/documentacion oficial."""

    status_code = 503
    code = "INTEGRATION_PENDING"

    def __init__(self, missing: Sequence[str]) -> None:
        self.missing = tuple(missing)
        super().__init__(
            "La integracion con la API externa todavia no esta configurada."
        )


class RunAlreadyInProgress(AppError):
    status_code = 409
    code = "SYNC_ALREADY_RUNNING"

    def __init__(self, source: str) -> None:
        super().__init__(f"Ya hay una sincronizacion en curso para '{source}'.")


class ExternalSourceError(AppError):
    """Fallo al leer de la API externa (no se expone el detalle tecnico)."""

    status_code = 502
    code = "EXTERNAL_SOURCE_ERROR"


class SyncApplyError(Exception):
    """Conflicto interno al aplicar un registro (no es un error de API)."""
