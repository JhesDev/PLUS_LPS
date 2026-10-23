# Prompt — Frontend: login, datos reales y mejora del mapa alpha

Implementa el alpha en `frontend`, coordinando contratos con DB Manager y Backend. Lee `AGENTS.md`, `frontend/README.md`, `database/supabase/README.md`, tipos, repositorio/store, sesión, router, componentes de mapa y evidencias. Revisa `git status` y conserva los cambios existentes.

## Estado actual confirmado

- Vue 3 + TypeScript + Vite + Pinia + Vue Router + MapLibre GL JS. No hay `@supabase/supabase-js` instalado.
- `operationsRepository.ts` define el puerto, pero `operations.ts` instancia directamente `DemoOperationsRepository`; la sesión y el selector de rol son simulados.
- `demoSeed.ts` es independiente del seed SQL y tiene pocos registros. La UI indica explícitamente que usa demo local.
- `MapCanvas.vue` activa `cluster: true`, define capas/click handlers de clusters y dibuja marcadores pequeños.
- `EvidenceUploader.vue` solo hace previsualización; el repo ya tiene bucket privado y tabla `work_order_evidence`.
- Rutas por rol: `/coordinacion`, `/despacho`, `/tecnico`. Coordinador sigue lectura/auditoría.
- Vista disponible de DB: `v_work_orders_map`; funciones RPC documentadas en DB README. No se conoce contrato SAP/PLUZ.

## Autenticación y datos

1. Integrar Supabase Auth con login/logout/restauración de sesión. Añadir `.env.example` claro con `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`; ignorar `.env.local`. La Publishable key es pública y visible en bundle; jamás incluir `service_role`, secret keys ni DSN.
2. El rol se obtiene de `public.profiles`/`GET /api/v1/me`, no de un selector, URL, `user_metadata` ni un campo controlable por el usuario. Proteger rutas y acciones en UI como experiencia; la seguridad real queda en RLS/backend. Mantener coordinador solo lectura.
3. Convertir el repositorio en una selección clara demo/connected y añadir adaptador Supabase. Leer la vista y tablas reales con filtros/paginación, mapearlos a `domain.ts` en un solo límite y no presentar datos ficticios como datos reales. Conservar el modo demo útil cuando las variables estén ausentes si eso encaja con arquitectura actual.
4. Aplicar las RPC existentes para asignar/desasignar/cambiar estado/ruta; no escribir tablas de historial/asignaciones directamente si las migraciones lo prohíben. Usar sesión del usuario para respetar RLS.
5. Para listas/tablas, implementar paginación o virtualización y filtros/búsqueda apropiados para n registros; no renderizar cientos/miles de tarjetas DOM a la vez. No exceder silenciosamente el límite de filas de Supabase. Para mapa, cargar las entidades visibles según el contrato disponible y mantener selección/filtrado coherente.

## Evidencias

- Subir el archivo al bucket privado `work-order-evidence` con la convención `{work_order_id}/{archivo}` y luego crear `work_order_evidence` con tipo, MIME, tamaño y datos disponibles. Permitir JPEG, PNG, WEBP y PDF hasta 10 MiB; validar cliente y manejar también errores de Storage/RLS.
- Usar rutas privadas y enlaces firmados de corta duración para previsualización. No volver público el bucket ni subir claves de servidor.
- Coordinar el caso de fallo parcial (objeto subido pero metadata rechazada) con DB/Backend sin introducir permisos de borrado amplios ni evidencias mutables.

## Mapa y disposición

- Desactivar clusters y eliminar capas/handlers que solo sirven para clusters. Mostrar cada orden como placemark individual, más grande y con contraste; conservar color por estado, tipo/icono, selección, polígonos y clic para seleccionar. Considerar solapamientos sin reintroducir agrupación.
- Mantener selector de estilo y sus atribuciones. Usar este catálogo y dejar **Positron como predeterminado**:

```ts
const BASEMAPS = {
  osm: 'https://demotiles.maplibre.org/style.json',
  positron: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  darkMatter: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
  voyager: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
}
```

- Al cambiar el estilo, restaurar capas/fuentes/listeners operativos de MapLibre porque `setStyle` puede quitarlos. Manejar error de carga y guardar la preferencia localmente.
- Añadir control accesible para ocultar/mostrar el panel lateral izquierdo y ajustar tamaño del mapa al cambiar el layout; hacerlo usable en móvil.
- Mejorar el encabezado de órdenes visibles y navegación de lista/tabla para gran volumen: conteo claro (filtradas vs total si se conoce), paginación/virtualización, filtros y vacío/carga/error.

## Aceptación

- Login, logout, refresco de página y rutas protegidas funcionan con las cuentas locales creadas siguiendo la guía de DB.
- Coordenadas/roles/acciones provienen de Supabase/backend; coordinador no puede escribir aunque fuerce la UI.
- CRUD permitido funciona con RLS/RPC; evidencias privadas quedan vinculadas a orden y usuario.
- Positron se ve por defecto; cambiar a los otros estilos no borra marcadores/capas de órdenes, rutas ni polígonos.
- Ningún cluster aparece; placemarks se distinguen. Panel lateral puede contraerse y volver.
- El listado/table no crea un nodo DOM por cada orden cargada sin límite.
- Actualizar README del frontend y `.env.example`; ejecutar typecheck, pruebas y build pertinentes según `AGENTS.md`.

No inventes contrato externo ni uses credenciales reales. Informa archivos tocados, variables nuevas, flujo de login, permisos probados y resultados de verificación.
