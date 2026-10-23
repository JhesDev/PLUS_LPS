# PLUS_LPS — Backend (FastAPI)

Backend responsable de la identidad/autorización, la frontera de ingesta y la
sincronización idempotente con la futura API externa (SAP/PLUZ).

> **Estado:** la integración externa está deliberadamente **pendiente**. No se
> inventaron URL, autenticación, paginación, campos ni estados del origen. Los
> endpoints de sincronización responden `503 INTEGRATION_PENDING` hasta que
> exista contrato oficial. Ver [`docs/integracion-externa.md`](docs/integracion-externa.md).

## Alcance implementado

- Configuración por entorno (secretos solo en el servidor).
- Verificación de identidad contra Supabase Auth y rol efectivo desde
  `public.profiles` (nunca desde el JWT ni `user_metadata`).
- Guardas de rol en el servidor para acciones sensibles.
- Frontera de integración (`WorkOrderSource`, `WorkOrderMapper`) sin conexión
  real.
- Motor de sincronización idempotente con staging en `ingest` y aplicación
  transaccional sobre `public.work_orders`.
- Bloqueo de concurrencia por origen (`pg_try_advisory_lock`).
- CLI para cron/worker local.
- Pruebas unitarias y de integración contra PostgreSQL local.

No implementa pantallas ni lógica de frontend. No reimplementa asignaciones,
rutas ni cambios de estado: esas reglas viven en las RPC de PostgreSQL
(`assign_work_order`, `unassign_work_order`, `update_work_order_status`, ...).

## Estructura

```text
backend/
  app/
    config.py              # Settings por variables de entorno
    errors.py              # Errores con código estable para el cliente
    security.py            # Identidad Supabase + rol desde profiles
    domain.py              # Modelo canónico y planner idempotente (puro)
    ports.py               # Protocolos: origen, mapper, store, sesión
    adapters/postgres.py   # asyncpg: ingest + work_orders
    services/sync.py       # Orquestación de la sincronización
    api/                   # Routers, dependencias y modelos HTTP
    container.py           # Composición de dependencias
    factory.py / main.py   # create_app() y entrada Uvicorn
    cli.py                 # python -m app.cli sync|status
  tests/
    test_domain.py         # Reglas de idempotencia (sin I/O)
    test_sync_service.py   # Orquestación con fakes
    test_security.py       # Auth con httpx.MockTransport
    test_api.py            # Endpoints HTTP
    integration/           # PostgreSQL real (opt-in)
  docs/
    integracion-externa.md # Qué falta para conectar SAP/PLUZ
    sincronizacion.md      # Garantías y contrato con la base de datos
```

## Requisitos

- Python >= 3.12.
- PostgreSQL 17 + PostGIS (stack Supabase en `database/supabase`).
- Dependencias: `fastapi`, `httpx`, `asyncpg`, `pydantic`,
  `pydantic-settings`, `uvicorn`; pruebas: `pytest`, `pytest-asyncio`.

```powershell
cd backend
uv sync --extra dev
```

## Configuración

Copiar `.env.example` a `.env` y completar:

| Variable | Uso |
|---|---|
| `SUPABASE_URL` | URL del stack (local: `http://127.0.0.1:54321`). |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key usada por Auth; no es una clave elevada. También se acepta el nombre antiguo `SUPABASE_ANON_KEY`. |
| `DATABASE_URL` | Conexión directa a PostgreSQL. **Secreto de servidor.** |
| `DB_SERVICE_ROLE` | Rol que adopta la sincronización (`service_role` por defecto). |
| `SYNC_SOURCE` / `SYNC_ENTITY` | Origen lógico (`sap` / `work_order`). |
| `CORS_ORIGINS` | Orígenes permitidos del frontend (JSON). |

El backend usa la Publishable key para llamar a Supabase Auth; no necesita
`service_role` para autenticar usuarios. La clave no se devuelve en respuestas.

`DATABASE_URL` es necesaria porque el esquema `ingest` **no** está expuesto por
PostgREST (`database/supabase/config.toml` sólo expone `public` y
`graphql_public`). Ninguna de estas variables debe llevar prefijo `VITE_` ni
llegar al navegador.

## Ejecución

```powershell
cd backend
uv run uvicorn app.main:app --reload
uv run python -m app.cli status   # ¿está configurada la integración?
uv run python -m app.cli sync     # corrida manual (cron/worker)
```

Códigos de salida del CLI: `0` sin errores, `2` integración pendiente, `3`
corrida ya en curso, `4` fallo del origen, `5` lote con errores por registro.

## Endpoints

| Método | Ruta | Roles | Descripción |
|---|---|---|---|
| `GET` | `/health` | público | Sonda de vida del proceso; no comprueba PostgreSQL ni SAP/PLUZ. |
| `GET` | `/api/v1/me` | autenticado | Identidad y rol efectivo. |
| `GET` | `/api/v1/sync/availability` | coordinador, despachador | ¿Integración lista? ¿Qué falta? |
| `POST` | `/api/v1/sync/runs` | despachador | Sincronización manual (botón «Sincronizar ahora»). |

Autenticación: `Authorization: Bearer <jwt de Supabase>`. La autorización se
resuelve siempre en el servidor.

`GET /api/v1/sync/availability` informa de los requisitos para la sincronización,
incluidos `DATABASE_URL` y el contrato externo pendiente. No realiza una
comprobación activa de conectividad con PostgreSQL o SAP/PLUZ.

Errores (JSON `{code, message}`):

| HTTP | `code` | Cuándo |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Token ausente/inválido/expirado. |
| 403 | `FORBIDDEN` | Rol sin permiso, perfil inactivo o inexistente. |
| 409 | `SYNC_ALREADY_RUNNING` | Ya hay una corrida del mismo origen. |
| 502 | `EXTERNAL_SOURCE_ERROR` | Fallo leyendo el origen externo. |
| 503 | `INTEGRATION_PENDING` | Falta contrato/adaptador (incluye `missing[]`). |
| 500 | `INTERNAL_ERROR` | Error interno; la respuesta no incluye detalles técnicos. |

Ejemplo de `POST /api/v1/sync/runs` cuando esté habilitado:

```json
{
  "batch_id": "0b6f...-...",
  "status": "procesado",
  "received": 120,
  "created": 40,
  "updated": 70,
  "skipped": 9,
  "duplicates": 1,
  "errors": 0
}
```

El frontend debe tratar `503` mostrando el estado «integración pendiente» (y
`missing` sólo como diagnóstico interno, sin datos sensibles) y `409` como
«sincronización en curso». No debe reintentar automáticamente en bucle.

## Pruebas

```powershell
cd backend
uv run pytest -q
```

Integración con PostgreSQL local (crea y limpia su propio `source`):

```powershell
$env:PLUS_TEST_DATABASE_URL="postgresql://postgres:<password>@127.0.0.1:54322/postgres"
uv run pytest tests/integration -q
```

Las pruebas de integración se omiten si `PLUS_TEST_DATABASE_URL` no está
configurada y accesible.

## Decisiones de diseño

1. **Sin lógica de negocio duplicada:** asignaciones, rutas, estados y
   evidencias siguen resolviéndose en las RPC/RLS de PostgreSQL. El backend no
   hace `UPDATE` de `status` ni inserta en asignaciones/historial.
2. **Staging primero:** todo payload se guarda en `ingest.records` (con hash)
   antes de normalizar; la normalización corre en transacciones separadas.
3. **Idempotencia doble:** hash del payload (dedupe en `ingest`) + diff contra
   el estado local (sin escrituras si no hay cambios).
4. **Protección de trabajo local:** una orden que dejó `pendiente` no se
   actualiza desde el origen; nunca se borran órdenes ausentes del lote.
5. **asyncpg y no psycopg async:** Uvicorn usa `ProactorEventLoop` en Windows y
   psycopg async no lo soporta. asyncpg sí funciona en ese loop.
6. **Sin Taskiq todavía:** no hay broker configurado ni contrato externo; la
   corrida manual y el CLI cubren la necesidad actual. Ver
   `docs/integracion-externa.md` para el criterio de activación.

## Coordinación pendiente

- **DB Manager:** confirmar que el backend puede usar `DATABASE_URL` con
  `SET ROLE service_role` y que la semántica de `ingest.records` para reintentos
  es aceptable. Ver `docs/sincronizacion.md` (puntos 3 y 4).
- **Frontend:** consumir los endpoints de la tabla anterior; no llamar a la API
  externa ni manejar `service_role`.
- **Integración:** entregar documentación y ejemplo sanitizado de la API para
  implementar `WorkOrderSource` + `WorkOrderMapper`.
