# Sincronización idempotente

## Flujo de una corrida

1. `SyncService.run()` exige que existan `WorkOrderSource`, `WorkOrderMapper` y
   `SyncStore`; si falta algo lanza `INTEGRATION_PENDING` (HTTP 503).
2. `PostgresSyncStore.open_run(source)` abre **una** conexión, adopta el rol
   `DB_SERVICE_ROLE` y toma `pg_try_advisory_lock(<hash del origen>)`. Si otra
   corrida del mismo origen está activa, devuelve `SYNC_ALREADY_RUNNING` (409)
   sin escribir nada.
3. Se crea `ingest.batches` en estado `recibido`.
4. Por cada payload del origen:
   1. se calcula `sha256` del JSON canónico (claves ordenadas);
   2. se inserta en `ingest.records` con el payload original;
      - si el hash ya existe y el registro está `procesado`/`omitido`, se cuenta
        como **duplicado** y no se vuelve a aplicar;
      - si el hash existe pero el último intento quedó en `error`, se reutiliza
        el registro para reintentar (misma fila, nuevo `batch_id`);
   3. el `WorkOrderMapper` traduce el payload al modelo interno;
   4. `apply_external_order` lee la orden local con `FOR UPDATE`, decide con
      `plan_upsert` y escribe (o no) en la misma transacción;
   5. se actualiza el registro como `procesado`, `omitido` o `error`.
5. Se cierra el lote con estado `procesado` (sin errores), `parcial` (mezcla) o
   `error` (todos fallaron o falló la lectura del origen) y un resumen en
   `notes`. `records_count` cuenta payloads recibidos (incluidos duplicados);
   el desglose de duplicados/creados/actualizados/omitidos/errores queda en
   `notes`.

Un fallo de un registro **no** aborta el lote. Un fallo del origen sí cierra el
lote como `error` y se devuelve `502`.

## Qué puede cambiar el origen externo

| Campo | ¿Origen externo puede escribirlo? |
|---|---|
| `code` | Sólo al crear. Nunca se modifica después (referencia interna estable). |
| `type`, `priority` | Sí, mientras la orden siga `pendiente`. |
| `customer_name`, `supply_number`, `address`, `district`, `zone` | Sí; un valor `null` **no** borra el existente. |
| `location` | Sólo si la orden aún no tiene punto geográfico. |
| `scheduled_at`, `due_at` | Sí; `null` no borra el existente. |
| `external_source`, `external_id` | Inmutables; son la clave de idempotencia. |
| `status`, `cancellation_reason`, `completed_at` | **Nunca.** Decisión operativa interna. |
| Asignaciones, historial, rutas, paradas, evidencias | **Nunca.** |

Regla de congelación: si la orden no está en `pendiente` (es decir, `asignada`,
`en_proceso`, `ejecutada`, `imposibilitada` o `cancelada`), el payload se guarda
en staging para auditoría pero **no se aplica ningún cambio**. El registro queda
`omitido`; en `ingest.records.error_message` se guarda únicamente el código del
motivo (`order_in_progress` u `order_closed`), no datos personales.

Nunca se ejecuta `DELETE` sobre órdenes. Que un registro desaparezca del lote
externo no cancela ni borra nada localmente.

## Idempotencia

- **Payload idéntico:** el hash canónico evita reaplicarlo.
- **Payload distinto pero sin cambios relevantes:** el diff no genera `UPDATE`.
- **Mismo `external_id`:** se actualiza la misma orden (`external_source` +
  `external_id`, índice único parcial).
- **Reintentos:** una corrida repetida produce como máximo los mismos efectos;
  las asignaciones y el avance local no se tocan.
- **Concurrencia:** el lock por origen serializa corridas dentro del mismo
  PostgreSQL. El índice único de `work_orders` es la última defensa.

Fuera de garantía: si el origen reutiliza el mismo `external_id` para una orden
distinta, el sistema la tratará como actualización de la existente. Es una regla
que debe confirmarse en el contrato externo (ver
[`integracion-externa.md`](integracion-externa.md)).

## Contrato con la base de datos

Se usan únicamente objetos existentes en `database/supabase/migrations`:

- `ingest.batches`, `ingest.records` (staging, no expuesto por PostgREST).
- `public.work_orders` (columnas externas + `external_source`/`external_id`).
- Enums `work_order_type`, `ingest.batch_status`, `ingest.record_status`.
- Trigger `work_orders_set_updated_at` (mantiene `updated_at`).
- Trigger `work_orders_stamp_actor` (sin JWT, `updated_by` queda `null`).
- Trigger de historial: **no** se dispara porque la sincronización no cambia
  `status`.

La conexión adopta `service_role` (`SET ROLE`) para escribir en `ingest`, que no
tiene grants para `anon`/`authenticated`. En local, el usuario `postgres` es
miembro de `service_role`. Si el DSN de producción no lo fuera, habría que
ajustar `DB_SERVICE_ROLE` o los grants (coordinación con DB Manager).

### Puntos a confirmar con DB Manager

1. **Acceso directo:** ¿se autoriza `DATABASE_URL` con `SET ROLE service_role`
   desde el backend, o se prefiere una RPC `SECURITY DEFINER` en `public` para
   escribir en `ingest`? La RPC evitaría exponer el DSN, pero añade esquema.
2. **Reintento de duplicados:** la restricción
   `ingest_records_payload_uk (source, entity, payload_hash)` impide insertar de
   nuevo un payload fallido. El adaptador reutiliza la fila en `error`
   (actualiza `batch_id`). Consecuencia: el lote anterior conserva su resumen,
   pero esa fila pasa a pertenecer al lote del reintento. Confirmar que ese uso
   es aceptable o proponer una columna de intento.
3. **Frescura:** no existe `external_updated_at`/`synced_at` en `work_orders`.
   Hoy la frescura se deduce del diff y de `ingest`. Si se necesita auditar
   «última sincronización», requiere migración.
4. **Código inmutable:** `code` es único y se considera estable tras el alta.
   Si SAP puede cambiar el código de una orden, hace falta una regla explícita.
5. **Protección en base:** la inmutabilidad de `status`/asignaciones frente a la
   ingesta se garantiza en el backend. Si se quiere defensa en profundidad, un
   trigger podría rechazar cambios de columnas operativas cuando el actor sea
   `service_role`; no se implementó para no modificar el esquema.
