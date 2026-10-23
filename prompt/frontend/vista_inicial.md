Trabaja como responsable frontend Vue de PLUS_LPS.

Objetivo:
Preparar el boceto funcional del panel operativo para coordinador y despachador, más una vista adaptable para técnico. La API externa aún no está disponible; usa únicamente datos locales de desarrollo claramente identificados o los registros del seed.

Antes de modificar:
- Revisa AGENTS.md, Git, estructura frontend, dependencias y contratos backend/database ya definidos.
- Confirma Vue, TypeScript, Vite, router y estado existentes antes de elegir librerías.
- No inventes endpoints, campos del servicio externo ni contratos de backend.

Vistas del boceto:
- Coordinador: mapa, métricas, filtros, tabla/lista, historial y auditoría en modo lectura; no mostrar acciones para modificar órdenes o asignaciones.
- Despachador: mapa de órdenes, filtros, detalle, selección individual o por polígono y flujo visual para asignar/reasignar técnicos.
- Técnico: experiencia móvil sencilla con sus órdenes asignadas, mapa/ruta, formulario de resultado e incorporación de evidencia fotográfica.
- Mostrar estados de carga, error, vacío y datos de demostración con claridad.

Mapa:
- Evalúa MapLibre GL JS para mostrar puntos y rutas, condicionado a compatibilidad con la configuración existente.
- No confundas el renderizado del mapa con el cálculo de rutas. Si no hay geometría de ruta disponible, representa la secuencia de paradas de demostración y déjalo señalado.
- No agregues proveedor de tiles o servicios de geocodificación/ruteo sin documentar la decisión y sus requisitos.

Supabase:
- Si implementas autenticación, usa Supabase Auth con publishable key y sesión del usuario.
- El cliente solo puede usar la publishable key; nunca pongas una secret/service_role key en código del navegador ni en variables VITE_*.
- No uses la clave como sustituto de autenticación/autorización. La autorización de datos corresponde a RLS y a los permisos del servidor.
- Accede directamente a Supabase solo para operaciones permitidas por el contrato y las políticas RLS existentes. Para otras operaciones, consume el backend.
- No eludas errores ni presentes datos ficticios como si vinieran de la API real.

Mantén separadas presentación, acceso a datos y estado de pantalla. Coordina cualquier cambio de contrato con backend y DB Manager. No implementes lógica de integración SAP/API que todavía no tiene contrato.