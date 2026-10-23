Trabaja como responsable de base de datos PostgreSQL/Supabase de PLUS_LPS.

Objetivo de esta fase:
Diseñar e implementar el esqueleto inicial de la base de datos para gestionar órdenes de trabajo, asignaciones a técnicos, rutas, estados y evidencias. La API externa todavía no está definida; no inventes sus endpoints ni su JSON.

Antes de modificar:
- Revisa AGENTS.md, el estado de Git, database/supabase/config.toml y la estructura existente.
- Respeta la ubicación real database/supabase. Confirma cómo debe ejecutarse Supabase CLI con esta estructura.
- No sobrescribas cambios existentes.

Diseña migraciones versionadas para un modelo canónico interno que contemple, según corresponda:
- perfiles vinculados a usuarios de Supabase Auth y roles: coordinador, despachador y técnico;
- órdenes, tipo y estado de trabajo, ubicación espacial y datos operativos;
- historial de asignaciones y cambios de estado;
- rutas o jornadas con paradas ordenadas, sin implementar optimización vial;
- metadatos de evidencias fotográficas y referencia a Supabase Storage; no guardes las imágenes binarias en PostgreSQL;
- una frontera de ingesta que permita guardar identificadores externos y, si resulta útil, el payload original en una zona de staging separada del modelo operativo.

PostGIS:
- Habilita la extensión mediante migración en el esquema extensions, si está disponible en el entorno local.
- Usa tipos espaciales y SRID adecuados para ubicaciones geográficas.
- Añade índices espaciales solo donde el modelo y las consultas lo justifiquen.
- No asumas que PostGIS ya está habilitado por la configuración actual.

Permisos:
- Coordinador: lectura y auditoría; no puede cambiar asignaciones ni órdenes.
- Despachador: puede gestionar asignaciones y rutas según las reglas acordadas.
- Técnico: solo puede consultar sus trabajos asignados y registrar el avance y resultado permitido.
- Define RLS y grants coherentes con esos límites. No confíes en user_metadata editable para autorizar roles.

Datos de desarrollo:
- Crea un seed reproducible con datos claramente ficticios y ubicaciones de ejemplo en Lima.
- Incluye órdenes en distintos estados, técnicos y asignaciones útiles para probar el mapa y las vistas.
- No uses datos reales, credenciales, claves ni usuarios remotos.
- Mantén el seed dedicado a INSERTs y datos de desarrollo.

No ejecutes despliegues, db push ni cambios en bases remotas. Valida localmente lo que permita la instalación actual; si no se puede, informa el comando o requisito faltante sin afirmar que quedó aplicado.

Entrega: resume el modelo, migraciones y seed creados, permisos/RLS, validaciones realizadas y decisiones que deberá revisar backend. No implementes backend ni frontend.