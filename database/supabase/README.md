# Base de datos PLUS_LPS (Supabase / PostgreSQL 17 + PostGIS)

Este directorio es el proyecto Supabase real. Todos los comandos se ejecutan
desde `database/supabase` (no desde la raíz del repo):

```powershell
cd database/supabase
supabase start          # stack local
supabase db reset       # recrea local, aplica migraciones + seed.sql
supabase test db        # pgTAP (tests/database)
supabase db lint --local --level warning
```

No se ejecutó `supabase db push` ni ningún cambio remoto.

## Migraciones

| Archivo | Contenido |
|---|---|
| `0001_extensions` | PostGIS y pg_trgm en el esquema `extensions` |
| `0002_profiles` | `app_role`, `profiles`, `technician_details`, alta automática desde `auth.users` |
| `0003_work_orders` | Órdenes, asignaciones, historial de estados e índices |
| `0004_routes` | Rutas/jornadas y paradas ordenadas |
| `0005_evidence` | Metadatos de evidencias + bucket privado de Storage |
| `0006_ingest` | Staging `ingest.batches` / `ingest.records` |
| `0007_functions` | Helpers de autorización y RPC de negocio |
| `0008_rls_grants` | RLS, grants por columna y políticas de Storage |
| `0009_views` | `v_work_orders_map`, `v_technician_workload` |

## Modelo operativo

- `public.profiles`: 1:1 con `auth.users`; `role` es la **única fuente de verdad** del rol.
  El trigger `on_auth_user_created` toma el rol desde `raw_app_meta_data`
  (solo escribible con `service_role`/Admin API). Si no viene, asigna `tecnico`.
  `user_metadata` **no** se usa para autorizar.
- `public.technician_details`: datos operativos (código, vehículo, capacidad, última ubicación).
- `public.work_orders`: orden canónica. `location geometry(Point,4326)` nullable
  (una orden sin geocodificar es válida). `external_source` + `external_id`
  identifican el origen para idempotencia. Índices GiST sobre `location` y sobre
  `(location::geography)` para búsquedas por radio en metros.
- `public.work_order_assignments`: historial; la vigente es `unassigned_at is null`
  (índice único parcial). Una orden nunca tiene dos asignaciones vigentes.
- `public.work_order_status_history`: auditoría append-only escrita por trigger.
- `public.routes` + `public.route_stops`: jornada y paradas con orden explícito.
  No hay optimización vial ni cálculo de rutas.
- `public.work_order_evidence`: metadatos; el binario vive en Storage.
- `ingest.batches` / `ingest.records`: payload original `jsonb` + hash. El esquema
  `ingest` no está expuesto por PostgREST y no tiene grants para `anon/authenticated`.

### Estados

`work_order_status`: `pendiente → asignada → en_proceso → ejecutada | imposibilitada`,
más `cancelada`. `imposibilitada → pendiente` solo para despachador (reapertura).
`rechazada` del requerimiento inicial se modela como `imposibilitada` + motivo.

`route_status`: `planificada → en_curso → completada | cancelada`.

## RPC (contrato para backend)

Todas son `SECURITY DEFINER`, con `search_path` fijado y validación de rol.

| Función | Retorna | Regla |
|---|---|---|
| `assign_work_order(work_order_id uuid, technician_id uuid, notes text default null)` | `uuid` (asignación) | Solo despachador/service. Cierra la vigente y deja la orden `asignada`. Idempotente si es el mismo técnico. |
| `unassign_work_order(work_order_id uuid, reason text default null)` | `uuid` (asignación cerrada) | Solo despachador/service. Devuelve la orden a `pendiente`. |
| `update_work_order_status(work_order_id uuid, status work_order_status, reason text default null, latitude float8 default null, longitude float8 default null)` | `void` | Despachador o técnico asignado. Valida transiciones; exige motivo para `imposibilitada`/`cancelada`; registra historial con ubicación. |
| `set_route_status(route_id uuid, status route_status)` | `void` | Despachador o técnico dueño de la ruta. |
| `set_route_stop_status(stop_id uuid, status route_stop_status)` | `void` | Despachador o técnico dueño de la ruta. |

Errores esperados: `42501` sin permiso, `23514` regla/transición inválida,
`P0002` no encontrado, `22023` parámetro inválido.

Las tablas `work_order_assignments` y `work_order_status_history` son de solo
lectura para la API: no se otorga `INSERT/UPDATE/DELETE`. La escritura pasa
exclusivamente por las RPC.

## RLS y grants

| Rol | Órdenes | Asignaciones/Historial | Rutas | Evidencias | Perfiles |
|---|---|---|---|---|---|
| `coordinador` | SELECT | SELECT | SELECT | SELECT | SELECT (staff) |
| `despachador` | SELECT + INSERT/UPDATE columnas operativas | SELECT (escritura vía RPC) | SELECT/INSERT/UPDATE columnas | SELECT/INSERT | SELECT |
| `tecnico` | SELECT solo propias | SELECT solo propias | SELECT propias | SELECT/INSERT propias | SELECT/UPDATE propias columnas |
| `anon` | sin acceso | sin acceso | sin acceso | sin acceso | sin acceso |

`status`, `created_by`, `uploaded_by`, `assigned_by` no se otorgan como columnas:
los fija la RPC o un trigger. El rol no es actualizable por el usuario
(column grant limitado a `full_name`, `phone`).

Storage: bucket privado `work-order-evidence`, ruta obligatoria
`{work_order_id}/{archivo}`. Políticas de SELECT/INSERT alineadas con RLS.
Sin UPDATE/DELETE: append-only.

## Seed de desarrollo

`seed.sql` crea 5 usuarios ficticios en `auth.users` (dominio `.test`), 12 órdenes
en Lima, 4 asignaciones vigentes, 2 cerradas, 3 rutas, 6 paradas, 3 evidencias
(solo metadatos) y 1 lote de ingesta. Los usuarios **no tienen contraseña conocida**
(se genera aleatoria) para no guardar credenciales en el repo.

| Usuario | UUID | Rol |
|---|---|---|
| `coordinador.demo@plus-lps.test` | `11111111-1111-4111-8111-111111111111` | coordinador |
| `despachador.demo@plus-lps.test` | `22222222-2222-4222-8222-222222222222` | despachador |
| `tecnico.uno@plus-lps.test` | `33333333-3333-4333-8333-333333333331` | técnico |
| `tecnico.dos@plus-lps.test` | `33333333-3333-4333-8333-333333333332` | técnico |
| `tecnico.tres@plus-lps.test` | `33333333-3333-4333-8333-333333333333` | técnico |

## Decisiones que backend debe conocer

1. Usar las RPC para asignar/desasignar/cambiar estados. No hacer `UPDATE` directo
   de `status` ni inserts en asignaciones/historial (fallará por grants).
2. El backend con `service_role` bypassa RLS y puede corregir transiciones; aun así
   el trigger de historial registra `changed_by = NULL` si no hay JWT. Si se requiere
   atribución, ejecutar con JWT del usuario o añadir actor explícito en una fase futura.
3. La ingesta debe escribir primero en `ingest` y normalizar a `work_orders` en una
   transacción separada; el contrato SAP aún no está definido. No se inventó su JSON.
4. `v_work_orders_map` entrega `latitude`, `longitude` y `geojson`; usar esa vista
   para el mapa. Respeta RLS (`security_invoker`).
5. Las paradas no asignan órdenes automáticamente: asignar primero con la RPC y
   luego crear la parada.
6. `location` nullable: el mapa debe tolerar órdenes sin geocodificar.

## Validación local ejecutada

- `supabase db reset --local`: OK (9 migraciones + `seed.sql`).
- `supabase test db`: **24 pruebas pgTAP, PASS** (RLS por rol, RPC, auditoría,
  convención de Storage, altas del despachador, staging inaccesible).
- `supabase db lint --local --level warning`: sin hallazgos en `public`/`ingest`;
  solo advertencias internas de las funciones de PostGIS en `extensions`.
- Verificado: SRID 4326 en todas las geometrías, 4 índices GiST (geometry +
  geography), 8 tablas operativas con RLS, vista de mapa con 12 filas para staff
  y 2 para el técnico 1.

## Limitaciones actuales

- Sin optimización ni secuenciación automática de rutas.
- Sin geocodificación de direcciones.
- Sin políticas de actualización/borrado de evidencias (append-only por diseño).
- Sin tablas de auditoría genéricas fuera del historial de estados y asignaciones.
- Los grants por defecto para objetos futuros en `public` fueron revocados:
  cada migración nueva debe conceder explícitamente lo que exponga.
