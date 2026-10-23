"""CLI para ejecutar la sincronizacion desde un cron/worker local.

No requiere un usuario interactivo: se ejecuta en el servidor con las mismas
credenciales elevadas del backend (``DATABASE_URL``). No configura ni asume un
broker de Taskiq; ver ``docs/integracion-externa.md``.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
from dataclasses import asdict

from .config import get_settings
from .container import build_container
from .errors import ExternalSourceError, IntegrationPending, RunAlreadyInProgress


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m app.cli",
        description="Procesos operativos de PLUS_LPS",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("sync", help="Ejecuta una sincronizacion del origen externo")
    subparsers.add_parser("status", help="Muestra si la integracion esta configurada")
    args = parser.parse_args(argv)

    return asyncio.run(_run(args.command))


async def _run(command: str) -> int:
    settings = get_settings()
    logging.basicConfig(
        level=settings.log_level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    logging.getLogger("httpx").setLevel(logging.WARNING)

    container = build_container(settings)
    try:
        if command == "status":
            print(json.dumps(asdict(container.sync.availability()), ensure_ascii=False))
            return 0

        try:
            result = await container.sync.run()
        except IntegrationPending as exc:
            print(
                json.dumps(
                    {
                        "code": exc.code,
                        "message": exc.message,
                        "missing": list(exc.missing),
                    },
                    ensure_ascii=False,
                )
            )
            return 2
        except RunAlreadyInProgress as exc:
            print(json.dumps({"code": exc.code, "message": exc.message}, ensure_ascii=False))
            return 3
        except ExternalSourceError as exc:
            print(json.dumps({"code": exc.code, "message": exc.message}, ensure_ascii=False))
            return 4

        payload = asdict(result)
        payload["status"] = result.status.value
        payload["batch_id"] = str(result.batch_id)
        print(json.dumps(payload, ensure_ascii=False))
        # Codigo distinto de cero para que cron/monitorizacion detecten un
        # lote con errores aunque el proceso haya terminado.
        return 0 if result.errors == 0 else 5
    finally:
        await container.aclose()


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
