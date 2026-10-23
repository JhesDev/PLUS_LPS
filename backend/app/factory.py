"""Fabrica de la aplicacion FastAPI.

``create_app`` permite inyectar configuracion y contenedor para pruebas sin
depender de variables de entorno reales.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from . import __version__
from .api.routes import api_router
from .config import Settings, get_settings
from .container import Container, build_container
from .errors import AppError, AuthError, IntegrationPending

logger = logging.getLogger(__name__)


def create_app(
    settings: Settings | None = None,
    *,
    container: Container | None = None,
) -> FastAPI:
    resolved_settings = settings or get_settings()
    resolved_container = container or build_container(resolved_settings)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        try:
            yield
        finally:
            await resolved_container.aclose()

    docs_url = (
        "/docs" if resolved_settings.environment != "production" else None
    )

    app = FastAPI(
        title=resolved_settings.app_name,
        version=__version__,
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=None,
    )
    app.state.container = resolved_container

    if resolved_settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=resolved_settings.cors_origins,
            allow_credentials=True,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type"],
        )

    app.add_exception_handler(AppError, _app_error_handler)
    app.add_exception_handler(StarletteHTTPException, _http_error_handler)
    app.add_exception_handler(RequestValidationError, _validation_error_handler)
    app.add_exception_handler(Exception, _unhandled_error_handler)
    app.include_router(api_router)

    return app


async def _app_error_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, AppError)
    content: dict[str, object] = {"code": exc.code, "message": exc.message}
    if isinstance(exc, IntegrationPending):
        content["missing"] = list(exc.missing)

    headers = None
    if isinstance(exc, AuthError) and exc.status_code == 401:
        headers = {"WWW-Authenticate": "Bearer"}

    return JSONResponse(
        status_code=exc.status_code,
        content=content,
        headers=headers,
    )


async def _unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    # No registrar texto de excepciones ni trazas: pueden contener DSN,
    # sentencias o contenido sensible de proveedores externos.
    logger.error(
        "unhandled_error path=%s error=%s",
        request.url.path,
        type(exc).__name__,
    )
    return JSONResponse(
        status_code=500,
        content={
            "code": "INTERNAL_ERROR",
            "message": "Error interno del servidor.",
        },
    )


_HTTP_ERROR_CODES = {
    400: "BAD_REQUEST",
    401: "UNAUTHENTICATED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    405: "METHOD_NOT_ALLOWED",
    409: "CONFLICT",
    413: "PAYLOAD_TOO_LARGE",
    415: "UNSUPPORTED_MEDIA_TYPE",
    422: "VALIDATION_ERROR",
    429: "TOO_MANY_REQUESTS",
}


async def _http_error_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)
    if exc.status_code >= 500:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "code": "INTERNAL_ERROR",
                "message": "Error interno del servidor.",
            },
        )

    code = _HTTP_ERROR_CODES.get(exc.status_code, "HTTP_ERROR")
    message = exc.detail if isinstance(exc.detail, str) else "Peticion no valida."
    return JSONResponse(
        status_code=exc.status_code,
        content={"code": code, "message": message},
    )


async def _validation_error_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    return JSONResponse(
        status_code=422,
        content={
            "code": "VALIDATION_ERROR",
            "message": "La peticion no es valida.",
        },
    )
