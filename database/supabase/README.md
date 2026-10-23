# Base de datos PLUS_LPS (Supabase / PostgreSQL 17 + PostGIS)

Este directorio es el proyecto Supabase real. Todos los comandos se ejecutan
desde `database/supabase` (no desde la raíz del repo):

```powershell
cd database/supabase
supabase start                 # stack local
supabase db reset              # recrea local, aplica migraciones + seed.sql
supabase test db               # pgTAP (tests/database)
supabase db lint --local --level warning
./scripts/create-demo-accounts.ps1   # deja contraseñas utilizables en las cuentas demo
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

**Fase alpha: no se agregó ninguna migración.** Se verificó por rol que las
políticas de `0005`/`0008` ya permiten exactamente lo requerido (técnico asignado
sube objeto y metadatos; coordinador solo lee; `anon` sin acceso) y que el bucket
sigue privado con límite de 10 MiB y MIME restringidos. Los cambios de esta fase
son solo de datos (`seed.sql`), pruebas y documentación.

## Modelo operativo

- `public.profiles`: 1:1 con `auth.users`; `role` es la **única fuente de verdad** del rol.
  El trigger `on_auth_user_created` toma el rol desde `raw_app_meta_data`
  (solo escribible con `service_role`/Admin API). Si no viene, asigna `tecnico`.
  `user_metadata` **no** se usa para autorizar. El registro público nunca ofrece
  un selector de rol.
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

### Semántica de la asignación vigente

`work_order_assignments.unassigned_at is null` significa **"vigente: no reasignada
ni desasignada"**, no "en progreso". Al ejecutar o imposibilitar una orden la
asignación permanece vigente: así el técnico conserva visibilidad de su trabajo y
puede seguir registrando evidencias. Los conteos de carga se calculan por estado
de la orden (`v_technician_workload`), no por la asignación.

## RPC (contrato para API)

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

### Cómo se comporta una escritura no permitida

Hay dos casos distintos y el frontend debe tratarlos igual: **verificar filas
devueltas**, nunca asumir éxito por un HTTP 200.

- **Falta de privilegio de tabla** (p. ej. un técnico intentando `UPDATE` en
  `work_order_assignments`) → PostgREST responde `42501`.
- **RLS que filtra filas** (p. ej. un coordinador intentando `PATCH` en
  `work_orders`) → la operación afecta **0 filas** y responde 200.

Por eso, en acciones de escritura conviene enviar `Prefer: return=representation`
y comprobar que vuelve al menos una fila.

### Storage

Bucket privado `work-order-evidence`, ruta obligatoria `{work_order_id}/{archivo}`.
Políticas de SELECT/INSERT alineadas con RLS; sin UPDATE/DELETE (append-only).
El límite de tamaño y los MIME permitidos los aplica la API de Storage, a partir
de la configuración del bucket (`file_size_limit` 10 MiB, JPEG/PNG/WEBP/PDF).
No se generan URLs públicas: para leer hay que pedir una URL firmada.

## Seed de desarrollo

`seed.sql` es determinista y repetible (IDs derivados de un índice; volver a
ejecutarlo no duplica). Contiene:

| Dato | Cantidad |
|---|---|
| Perfiles / usuarios Auth | 10 (1 coordinador, 1 despachador, 8 técnicos) |
| Órdenes | 612 (12 de muestra legibles + 600 generadas) |
| Órdenes sin coordenadas | 37 |
| Distritos / zonas | 40 / 5 |
| Asignaciones | 389 (387 vigentes + 2 cerradas de ejemplo) |
| Historial de estados | 853 filas |
| Rutas | 20 (`en_curso`, `planificada`, `completada`, `cancelada`) |
| Paradas | 192 |
| Evidencias (solo metadatos) | 27 (3 por técnico, las 3 de muestra aparte) |
| Lote de ingesta | 1 batch + 2 records ficticios |

Distribución de estados: ~30 % pendiente, 20 % asignada, 20 % en proceso,
20 % ejecutada, 6 % imposibilitada, 4 % cancelada. Los 6 tipos de trabajo y las
5 prioridades están representados.

### Coordenadas

Son **coordenadas ficticias de prueba**. Se derivan de centros urbanos
aproximados de 40 distritos de Lima Metropolitana y Callao y luego se aplica un
desplazamiento determinista acotado (hasta ~670 m norte/sur y hasta ~780 m
**hacia el este, tierra adentro**, ≤ ~1 km en diagonal) para evitar caer en el
mar. No hubo geocodificación real y no se usan límites distritales oficiales.

Verificado sobre el seed: 564 órdenes generadas con coordenadas, distancia máxima
al centro de su distrito 991 m (media 545 m), 0 órdenes desplazadas hacia el
oeste y todas en SRID 4326 dentro del área de Lima/Callao (las pruebas lo cubren).

### Usuarios demo y contraseñas

Los usuarios se crean con `encrypted_password` aleatorio para no versionar
credenciales, y con los columnas `*_token` en cadena vacía: GoTrue las escanea
como `string` y un `NULL` rompe el login y el Admin API
(`converting NULL to string is unsupported`).

Para poder iniciar sesión:

```powershell
cd database/supabase
./scripts/create-demo-accounts.ps1            # genera contraseña y escribe .env.demo.local
./scripts/create-demo-accounts.ps1 -NoFile    # no escribe archivo
```

El helper:

- lee `API_URL` y `service_role`/`secret key` en tiempo de ejecución desde
  `supabase status -o env`; **no** guarda claves en el repositorio;
- se niega a ejecutarse si `API_URL` no es local;
- fija la contraseña de las 10 cuentas demo vía Admin API y es idempotente;
- escribe la contraseña en `database/supabase/.env.demo.local`, ignorado por git
  (regla `.env.*`), y solo imprime la ruta.

La alternativa manual es Supabase Studio (`http://127.0.0.1:54323` → Authentication),
sin poner credenciales en archivos versionados.

| Usuario | UUID | Rol |
|---|---|---|
| `coordinador.demo@plus-lps.test` | `11111111-1111-4111-8111-111111111111` | coordinador |
| `despachador.demo@plus-lps.test` | `22222222-2222-4222-8222-222222222222` | despachador |
| `tecnico.uno@plus-lps.test` … `tecnico.ocho@plus-lps.test` | `33333333-3333-4333-8333-3333333333{31..38}` | tecnico |

`.env.demo.local` también expone `SUPABASE_URL`, `SUPABASE_ANON_KEY` y
`SUPABASE_PUBLISHABLE_KEY` (claves locales) para que el frontend las consuma sin
copiarlas a mano.

### Evidencias del seed

Son **solo metadatos**: los `storage_path` apuntan a objetos que no existen, así
que pedir una URL firmada para ellos devuelve "object not found". Sirven para
probar listados, filtros y RLS, no la descarga. Para probar la descarga hay que
subir un archivo real (como hace la validación documentada abajo).

## Decisiones que backend y frontend deben conocer

1. Usar las RPC para asignar/desasignar/cambiar estados. No hacer `UPDATE` directo
   de `status` ni inserts en asignaciones/historial (fallará por grants).
2. `service_role` bypassa RLS y puede corregir transiciones; el trigger de historial
   registra `changed_by = NULL` cuando no hay JWT del usuario.
3. La ingesta debe escribir primero en `ingest` y normalizar a `work_orders` en una
   transacción separada; el contrato SAP no está definido. `/api/v1/sync/runs`
   debe seguir respondiendo `503 INTEGRATION_PENDING`.
4. `v_work_orders_map` entrega `latitude`, `longitude` y `geojson`; es la vista
   para el mapa. Respeta RLS (`security_invoker`). Con 612 órdenes conviene
   paginar (`Range`/`limit`) y usar `Prefer: count=exact` para los KPIs.
5. Las paradas no asignan órdenes automáticamente: asignar primero con la RPC y
   luego crear la parada.
6. `location` nullable: el mapa y las listas deben tolerar órdenes sin geocodificar.
7. Un `PATCH` bloqueado por RLS puede responder 200 con 0 filas: comprobar la
   respuesta con `Prefer: return=representation`.
8. El coordinador nunca debe recibir controles de escritura; la base los rechaza,
   pero la UI no debe ofrecerlos.

## Validación local ejecutada

- `supabase db reset --local`: OK (9 migraciones + `seed.sql`).
- Idempotencia: `seed.sql` ejecutado 3 veces seguidas → mismos conteos
  (612 órdenes, 389 asignaciones, 853 filas de historial, 20 rutas, 192 paradas,
  27 evidencias, 10 identidades).
- `supabase test db`: **61 pruebas pgTAP, PASS** (`0001` RLS/RPC: 24, `0002`
  seed/evidencias/Storage: 37).
- `supabase db lint --local --level warning`: sin hallazgos en `public`/`ingest`;
  solo advertencias internas de PostGIS en `extensions`.
- Flujo alpha contra el stack local (login real por PostgREST/Storage):
  - login del técnico → `profiles.role = tecnico` leído de la base;
  - el técnico ve 47 de 612 órdenes y 3 evidencias (RLS);
  - `v_work_orders_map` devuelve `geojson` válido; `v_technician_workload` 1 fila;
  - la transición inválida por RPC devuelve `23514`;
  - subida real al bucket privado + inserción de metadatos con
    `uploaded_by` derivado del token;
  - el coordinador ve 612 órdenes y su `PATCH` afecta 0 filas;
  - el despachador asigna por RPC y la orden pasa a `asignada`.

## Limitaciones actuales

- Sin optimización, secuenciación ni geocodificación de rutas/direcciones.
- Sin políticas de UPDATE/DELETE en evidencias (append-only por diseño).
- Los binarios de las evidencias del seed no existen en Storage.
- `district`/`zone` son texto libre: no hay catálogo de distritos ni geometrías
  de límites distritales en la base.
- Sin tablas de auditoría genéricas fuera del historial de estados y asignaciones.
- El esquema no guarda secretos ni URLs públicas; las credenciales demo viven solo
  en el archivo local ignorado.
- Los grants por defecto para objetos futuros en `public` están revocados: cada
  migración nueva debe conceder explícitamente lo que exponga.
