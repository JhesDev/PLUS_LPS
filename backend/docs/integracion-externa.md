# Integración con la API externa (SAP / PLUZ B2B)

## Estado actual

**No conectada.** No se creó ninguna URL, nombre de campo, estado, código de
error ni esquema de paginación externo. El backend sólo define la frontera:

- `app/ports.py` → `WorkOrderSource` (entrega payloads) y `WorkOrderMapper`
  (traduce al modelo interno).
- `app/services/sync.py` → orquesta la corrida e impone la idempotencia.
- `app/container.py` → hoy registra `source=None`, `mapper=None`; por eso
  `GET /api/v1/sync/availability` devuelve `configured=false` y
  `POST /api/v1/sync/runs` devuelve `503 INTEGRATION_PENDING`.

No se debe asumir nada del origen: ni endpoint, ni método de auth, ni formato de
fechas, ni catálogo de estados, ni si el identificador es estable.

## Información requerida para implementar el adaptador

### 1. Documentación oficial

- Versión del documento y fecha.
- OpenAPI/Swagger, WSDL o PDF oficial (no ejemplos informales).
- Entornos disponibles: sandbox y producción.
- URL base por entorno (se configurará como variable de entorno, nunca en código).

### 2. Autenticación

- Tipo: OAuth2 client credentials, API key, Basic, mTLS u otro.
- Endpoint de token, duración, refresh y scopes.
- Dónde viaja la credencial (header/query) y cómo se rota.
- Límites por credencial/IP y política de bloqueo.
- Confirmación de que la credencial de integración **no** es la `service_role`
  de Supabase (son secretos distintos, ambos sólo en el backend).

### 3. Ejemplo de respuesta sanitizado

- Un JSON real **sin datos personales** (reemplazar nombres, documentos,
  teléfonos, direcciones exactas y coordenadas reales).
- Ejemplo de respuesta vacía, de error de validación y de error de servidor.
- Tipos y formatos: fechas (ISO 8601 con offset), decimales, nulos, campos
  opcionales, encoding.
- Unidad de las coordenadas y sistema de referencia (se espera WGS84/SRID 4326;
  confirmar).

### 4. Paginación y volumen

- Esquema: `page/size`, cursor, `Link` header u otro.
- Tamaño máximo por página, orden estable y cómo detectar el final.
- Volumen esperado: órdenes/día, picos, tamaño medio del payload.
- Si existe consulta incremental (ventana por fecha o watermark) y su zona
  horaria.

### 5. Identificación y actualización

- Campo que identifica de forma **estable** una orden (y si cambia al
  actualizarse).
- Si existe versión/revisión del registro.
- Relación entre orden, suministro y cliente (¿una orden por suministro?).
- Qué campos puede modificar el origen después del alta.
- Si el origen puede cancelar/cerrar y con qué semántica.
- Catálogo de estados externos y su equivalencia con
  `pendiente/asignada/en_proceso/ejecutada/imposibilitada/cancelada`
  (el mapeo se hará en `WorkOrderMapper`, no en el dominio).
- Reglas de reintento e idempotencia del lado externo.

### 6. Operación

- Horario/frecuencia acordada de sincronización y ventana permitida.
- Rate limits y política de backoff.
- Contacto técnico y procedimiento ante incidentes.
- Certificados, IP allowlist o VPN necesarios.

## Cómo se activará (sin cambiar el dominio)

1. Implementar `WorkOrderSource.stream()` en `app/adapters/` (auth, paginación,
   reintentos, timeouts). Debe entregar payloads crudos y no interpretarlos.
2. Implementar `WorkOrderMapper.map()` con el mapeo oficial de campos/estados.
   Debe devolver `MappedWorkOrder` con `external_id` y `NormalizedWorkOrder`.
3. Registrar ambos en `build_container()` y añadir las variables de entorno del
   origen a `Settings` (URL, credenciales, timeout). Nunca con prefijo `VITE_`.
4. Añadir pruebas: contrato de `stream()`, mapeo de estados/fechas, payload
   inválido y reintentos.
5. Retirar los ítems correspondientes de `missing` y ejecutar
   `python -m app.cli status` + una corrida contra el sandbox.

El dominio, la idempotencia y las pruebas actuales no cambian: ya están
desacoplados del formato externo.

## Tarea programada / Taskiq

Hoy **no** se usa Taskiq y no se asume ningún broker ni scheduler. Motivos:

- no hay contrato externo, por lo que no existe una tarea real que programar;
- no hay broker configurado en el proyecto (Redis/RabbitMQ) ni scheduler;
- la corrida manual (`POST /api/v1/sync/runs`) y el CLI
  (`python -m app.cli sync`) cubren la necesidad operativa actual.

Cuando se defina la frecuencia, hay dos opciones:

| Opción | Cuándo | Requisitos |
|---|---|---|
| Cron del sistema / orquestador ejecutando el CLI | Baja frecuencia, una instancia | Contenedor con `DATABASE_URL` y salida monitoreada. |
| Taskiq | Varias instancias, reintentos y cola | Broker (p. ej. Redis), `taskiq` + `taskiq-redis`, scheduler (`taskiq scheduler`), worker separado y observabilidad. |

Cualquiera de las dos es segura frente a reintentos: el lock por origen y los
hashes evitan efectos duplicados. No se debe activar Taskiq sin broker real,
sin política de reintentos/backoff y sin monitoreo.

## Seguridad

- `DATABASE_URL` y credenciales del origen son secretos **solo de backend**.
- No se exponen en respuestas, logs ni mensajes de error; tampoco en `VITE_*`.
- El frontend nunca llama a la API externa ni usa `service_role`.
- Los payloads no se registran en logs (pueden contener datos personales); sólo
  se guardan en `ingest` para trazabilidad.
- Los errores por registro se truncan y no incluyen el payload completo.
- `GET /api/v1/sync/availability` expone únicamente la lista de requisitos
  faltantes, sin credenciales ni URLs internas.

## Preguntas abiertas

1. ¿El identificador externo es único y estable entre reenvíos?
2. ¿Puede el origen cambiar `code`, cliente, dirección o ubicación después del
   alta? ¿Qué debe prevalecer?
3. ¿Cómo notifica el origen una cancelación y cómo se distingue de una orden
   eliminada del lote?
4. ¿La sincronización debe ser incremental? ¿Con qué marca de agua?
5. ¿Se requiere historial de cada versión del payload o basta el dedupe por
   hash actual?
6. ¿La frecuencia será fija o por evento (webhook)? Un webhook cambiaría la
   frontera (endpoint de recepción firmado), no sólo el scheduler.
