# PLUS_LPS · Frontend (boceto operativo)

Boceto funcional del panel operativo de PLUS_LPS: visor GIS de órdenes,
asignación a cuadrillas y hoja de ruta del técnico, sobre **Vue 3 + TypeScript +
Vite**, **Pinia**, **Vue Router** y **MapLibre GL JS**.

> **Estado:** la API externa (SAP/PLUZ) y los endpoints de órdenes del backend
> todavía no tienen contrato. Este boceto funciona **solo con datos locales de
> demostración** derivados de `database/supabase/seed.sql`. La UI lo indica de
> forma explícita (`SourceBadge`, banner y textos de ayuda); no se presentan
> datos ficticios como si vinieran de la API.

## Arranque

```powershell
cd frontend
npm install
npm run dev            # http://localhost:5173
```

Otros scripts:

```powershell
npm run typecheck      # vue-tsc --noEmit
npm run test           # vitest run
npm run build          # typecheck + vite build
npm run preview        # sirve dist/
```

Requisitos: Node 20+ (probado con Node 24) y npm.

## Vistas del boceto

| Ruta | Rol | Contenido |
|---|---|---|
| `/despacho` | Despachador | Mapa, filtros, detalle, selección individual o por polígono, asignar/reasignar y cambios de estado. |
| `/coordinacion` | Coordinador | Mismo visor en **modo lectura**: métricas, tabla, historial y exportación CSV. Sin acciones de escritura. |
| `/tecnico` | Técnico | Experiencia móvil: órdenes asignadas, secuencia de paradas, mapa de ruta, formulario de resultado y evidencia fotográfica. |

El selector superior permite cambiar de usuario demo (1 coordinador, 1
despachador y 3 técnicos del seed) para recorrer las tres vistas. **Es una
simulación de sesión**: el rol real vive en `public.profiles` y lo resuelve el
backend.

### Estados de pantalla

- **Carga:** spinner mientras se lee el conjunto demo.
- **Vacío:** mensaje con acción para volver a los datos de demostración.
- **Error:** mensaje del repositorio y botón de reintento.
- **Mapa no disponible:** si el estilo del mapa no termina de cargar en 12 s
  (pestaña en segundo plano, proveedor de tiles caído), se muestra un aviso con
  botón **Reintentar mapa** en lugar de un spinner infinito. Al volver a la
  pestaña se reintenta automáticamente.
- **Demo:** badge permanente con el origen del conjunto.

El banner superior (siempre visible, también en estado de error o vacío) incluye
los controles **Listo / Vacío / Error / Lento** para revisar cada estado.

## Arquitectura

Separación estricta de responsabilidades:

```text
src/
  config/       runtime.ts (proveedores del mapa, navegación por rol)
                dataSource.ts (flag de modo demo)
  types/        domain.ts (contratos del dominio, en camelCase)
  data/         demoSeed.ts (conjunto ficticio derivado del seed)
  services/     operationsRepository.ts (puerto)
                demoRepository.ts (implementación en memoria)
  stores/       operations.ts (datos + filtros + selección + acciones)
                session.ts (usuario/rol simulado), toasts.ts
  map/          basemap.ts, icons.ts, route.ts
  components/   common/ · layout/ · map/ · orders/ · technicians/
  views/        DispatcherView · CoordinatorView · TechnicianView · NotFoundView
  utils/        format, geo, filters, metrics, status, csv
```

- **Presentación** (componentes/vistas) no conoce HTTP ni el seed.
- **Acceso a datos** se concentra en `operationsRepository` (puerto) y su
  implementación demo. Cuando el backend publique los endpoints, se añade un
  adaptador HTTP sin tocar vistas ni stores.
- **Estado de pantalla** vive en el store `operations` (filtros, selección,
  estados de carga/error/vacío).

### Semántica respetada de la base de datos

Las mutaciones del repositorio demo replican las reglas de las RPC de
PostgreSQL (`database/supabase/migrations/0007_functions.sql`):

- `assign_work_order`: una sola asignación vigente por orden; al reasignar se
  cierra la anterior con `end_reason = 'reasignada'`; idempotente si el técnico
  es el mismo; la orden pasa a `asignada`; las órdenes cerradas no admiten
  asignación.
- `unassign_work_order`: cierra la asignación vigente y devuelve la orden a
  `pendiente`.
- `update_work_order_status`: matriz de transiciones por rol, motivo
  obligatorio para `imposibilitada` y `cancelada`, historial de auditoría.
- `work_order_evidence`: bucket privado `work-order-evidence` con ruta
  `{work_order_id}/{archivo}` y límite de 10 MiB.

## Mapa (MapLibre GL JS)

**Decisión:** se evaluó MapLibre GL JS y se adoptó porque es la opción que mejor
encaja con la configuración existente:

- No requiere cuenta, token ni licencia de proveedor (a diferencia de Mapbox o
  Google Maps).
- Está disponible por npm, sin script externo, y sirve GeoJSON nativo, que es
  justo lo que entrega `v_work_orders_map` (`latitude`, `longitude`, `geojson`).
- El clustering de puntos se resuelve con una fuente GeoJSON con `cluster: true`
  (no hace falta plugin).

### Proveedor de tiles y glifos

El boceto **no** integra servicios de geocodificación ni de cálculo de rutas.
Solo consume tiles de mapa base, y se documenta explícitamente:

| Recurso | Valor por defecto | Requisito / nota |
|---|---|---|
| Tiles ráster | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Política de uso de OSM: válido para **desarrollo/demostración**; para producción hay que contratar o autoalojar un proveedor. |
| Glifos (etiquetas) | `https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf` | Necesarios para el conteo de clusters; de demostración. Define `VITE_MAP_GLYPHS_URL=` (vacío) para desactivar las etiquetas. |
| Estilo vectorial | `VITE_MAP_STYLE_URL` (sin definir) | Si se define, tiene prioridad y se usan sus propios glifos. |

Variables públicas (`VITE_*`) en `.env.example`. **Ninguna** debe contener
secretos: son visibles en el navegador.

### Simbología

- **Estado** por color del marcador: pendiente (amarillo), asignada (azul), en
  proceso (naranja), ejecutada (verde), imposibilitada (rojo), cancelada (gris).
- **Tipo** por icono dibujado localmente en canvas (tijeras, rayo, lupa,
  eslabón, llave) para no depender de un sprite externo. La leyenda y las tablas
  replican el mismo icono en SVG.
- **Cuadrilla** como marcador propio con su última ubicación conocida (capa
  opcional).
- **Selección** con halo turquesa; el área dibujada se muestra con relleno y
  vértices.

### Rutas: renderizado ≠ cálculo

El modelo no guarda geometría vial (ver migración `0004_routes`: el orden de las
paradas es una decisión operativa). Por eso el mapa dibuja la **secuencia de
paradas con líneas rectas y discontinuas** y lo declara en la leyenda. No hay
motor de ruteo ni optimización de rutas.

La selección por proximidad («Cerca de» en la barra del mapa) usa la distancia
en línea recta (`haversine`) hacia la última posición conocida de la cuadrilla;
nunca calcula una ruta.

## Supabase y autorización

- **No se implementó todavía autenticación.** Cuando se integre, debe usar
  **Supabase Auth** con la **publishable/anon key** y la sesión del usuario.
- En este repo **no** hay claves: ni `service_role`, ni contraseñas, ni DSN en
  variables `VITE_*`. La sesión del boceto es local y simulada.
- La autorización de datos corresponde a **RLS** y a los permisos del servidor,
  no a la clave ni a ocultar botones. Por eso el modo lectura del coordinador se
  refleja en la UI *además* de estar garantizado en la base de datos.
- Acceso directo a Supabase solo para operaciones permitidas por el contrato y
  las políticas RLS existentes; el resto debe pasar por el backend FastAPI.
  El boceto actual **no** escribe en Supabase.

## Integración pendiente (no implementada)

| Función | Estado | Motivo |
|---|---|---|
| Sync con SAP | Botón informativo | El backend responde `503 INTEGRATION_PENDING`; no hay contrato. No se llama a ningún endpoint ni se reintenta en bucle. |
| Endpoints de órdenes | No consumidos | No existen en el contrato del backend (`/health`, `/api/v1/me`, `/api/v1/sync/*`). |
| Supabase Auth | No implementado | Falta sesión y clave publicable. |
| Subida de evidencias a Storage | Solo previsualización local | Falta el flujo de Storage; el bucket y sus políticas ya existen. |
| Estado de jornada (`set_route_status`) | Solo lectura | RPC no integrada aún. |
| Exportación PDF | No implementada | Falta definir plantilla; la exportación CSV está disponible. |

## Pruebas

```powershell
cd frontend
npm run test
```

Última ejecución local: **41 pruebas en verde** (3 archivos).

- `src/utils/filters.spec.ts` — filtros, búsqueda, orden, métricas,
  `pointInPolygon` y matriz de transiciones por rol.
- `src/services/demoRepository.spec.ts` — asignación/reasignación,
  idempotencia, órdenes cerradas, permisos por rol, transiciones, motivo
  obligatorio, historial, evidencias (límite 10 MiB) y escenarios.
- `src/stores/operations.spec.ts` — carga, estados vacío/error, órdenes sin
  geocodificar, selección por polígono, asignación por área, proximidad y
  coordenadas reactivas (regresión del `structuredClone` con Proxy).

`npm run build` (typecheck + build) también pasa. Aviso conocido: MapLibre GL JS
genera un chunk > 500 kB; es esperable y se puede dividir con `manualChunks` si
se necesita.

## Coordinación con otros agentes

- **Backend:** falta el contrato HTTP de lectura/escritura de órdenes. Cuando
  exista, el adaptador debe respetar el envoltorio de error `{ code, message }`
  ya definido (`UNAUTHENTICATED`, `FORBIDDEN`, `INTEGRATION_PENDING`, …). El
  frontend tratará `503` como «integración pendiente» y `409` como
  «sincronización en curso», sin reintentos automáticos.
- **DB Manager:** el boceto asume la nomenclatura del esquema versionado
  (`work_order_status`, `route_status`, `evidence_kind`, vista
  `v_work_orders_map`, vista `v_technician_workload`, bucket
  `work-order-evidence`). Cualquier cambio de contrato debe comunicarse para
  ajustar `src/types/domain.ts` y el seed demo.
- **Integración:** se requiere documentación y un ejemplo sanitizado de la API
  para implementar `WorkOrderSource` + `WorkOrderMapper`; no se inventaron
  campos del origen externo.

## Limitaciones

- Datos en memoria: los cambios se pierden al recargar (por diseño del boceto).
- Sin autenticación ni sesión real.
- Sin optimización/secuenciación automática de rutas ni geocodificación.
- La vista de técnico no modifica el estado de la jornada.
- El conteo de clusters requiere glifos; si se desactivan, los clusters siguen
  siendo funcionales pero sin número.
- MapLibre avanza con `requestAnimationFrame`: si la pestaña queda oculta mucho
  tiempo, el mapa puede mostrar el aviso de «mapa no respondió» y reintentar al
  volver a primer plano. No afecta a la lista, la tabla ni las acciones.
- Los objetos de dominio que pasan por `ref()` reactivos se convierten en Proxy
  y no son serializables: la frontera del repositorio normaliza las coordenadas
  a valores planos. Cualquier dato nuevo que cruce esa frontera debe ser plano.
