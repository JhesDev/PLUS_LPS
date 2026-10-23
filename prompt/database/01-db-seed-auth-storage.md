# Prompt — DB Manager: seed, perfiles y evidencias para alpha

Trabaja solo en `database/supabase` y en documentación de DB estrictamente necesaria. Lee primero `AGENTS.md`, `database/supabase/README.md`, `seed.sql` y todas las migraciones que afecten perfiles, órdenes, asignaciones, rutas, evidencias, vistas y RLS. Revisa `git status`; no sobrescribas cambios ajenos.

## Contexto confirmado

- Supabase local usa PostgreSQL 17 y PostGIS; migraciones `0001`–`0009` definen el esquema.
- Existen `public.profiles`, técnicos, órdenes PostGIS, asignaciones/historial, rutas/paradas, `v_work_orders_map`, `v_technician_workload` y staging `ingest`.
- `seed.sql` tiene actualmente 12 órdenes y usuarios Auth demo cuyo password no se puede usar para iniciar sesión.
- La migración `0005_evidence` ya crea `work-order-evidence` privado (límite 10 MiB, JPEG/PNG/WEBP/PDF), metadatos append-only y convención `{work_order_id}/{archivo}`. `0008_rls_grants` ya define políticas de Storage y tabla; verificar su comportamiento antes de agregar permisos.
- `profiles.role` es fuente de verdad y el trigger confía en `raw_app_meta_data`, nunca en `user_metadata`.

## Trabajo

1. Revisar si RLS/grants actuales permiten al técnico asignado subir evidencia y guardar metadata, y permiten a los roles autorizados consultar evidencias. Probar los permisos por rol. Mantener el bucket privado, límites MIME/tamaño, ruta vinculada a la orden, `uploaded_by` del contexto Auth y políticas mínimas. Cambiar esquema solo con migración nueva; no editar migraciones ya aplicadas.
2. Diseñar un procedimiento local reproducible para crear cuentas de prueba utilizables y roles de demo. No guardar contraseñas, tokens ni `service_role` en SQL versionado, `.env.example` o frontend. Se permite documentar creación manual local en Supabase Studio o un helper local que lea secretos ignorados y los solicite de forma segura. Nunca permitir que el usuario se elija un rol elevando privilegios desde signup.
3. Ampliar el seed para que haya **al menos 500 órdenes en total**, con IDs deterministas e inserción repetible. Incluir los estados/tipos/prioridades y asignaciones/rutas necesarios para probar filtros, mapa y jornada; preservar coherencia referencial y auditoría. Incluir algunos casos sin ubicación para validar el comportamiento actual.
4. Ubicar los registros en Lima Metropolitana y Callao, con nombres de distritos coherentes y coordenadas plausibles en zonas urbanas, SRID 4326. No usar coordenadas aleatorias sin control, fuera del área, mar abierto ni afirmar geocodificación real. Si el repo no tiene límites distritales confiables, documentar que son coordenadas ficticias de prueba y validar su distribución espacial razonablemente.
5. Mantener los conteos y ejemplos de `database/supabase/README.md` actualizados.

## Aceptación

- `supabase db reset` puede ejecutarse repetidamente y deja 500+ órdenes sin duplicarlas.
- `supabase test db` cubre las reglas/políticas nuevas o modificadas para los tres roles y almacenamiento.
- El esquema de evidencias no guarda binarios/base64 en PostgreSQL y no vuelve público el bucket.
- Se informa qué cuentas/roles locales se deben crear y cómo hacerlo sin exponer secretos.

No inventes datos de SAP. No ejecutes `db push` ni cambios remotos. Informa archivos tocados, migraciones nuevas, pruebas ejecutadas y cualquier decisión pendiente del contrato.
