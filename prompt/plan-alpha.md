# Prompt maestro — Actualización del modo alpha

Actúa sobre el repositorio PLUS_LPS existente para llevar el boceto a un alpha conectado a Supabase local. Antes de editar, lee `AGENTS.md`, los README de cada módulo y el código relacionado. Respeta las migraciones versionadas como fuente de verdad, revisa `git status` y conserva cambios existentes.

## Meta

1. Permitir inicio/cierre de sesión real con Supabase Auth y obtener perfil/rol desde `public.profiles`.
2. Mostrar y operar los datos persistidos de Supabase conforme a RLS y las RPC existentes.
3. Subir evidencias al bucket privado y guardar sus metadatos.
4. Aumentar el seed local a por lo menos **500 órdenes** ficticias, todas de Lima Metropolitana o Callao, para probar volumen.
5. Mejorar la lectura del mapa y listas sin agrupar placemarks.
6. Mantener coordinador en modo lectura/auditoría.

## Decisión de arquitectura para alpha

- Frontend: Supabase Auth y acceso directo a `public`/Storage usando `@supabase/supabase-js`, la sesión del usuario, una clave **Publishable** y las políticas RLS/RPC. El cliente no recibe `service_role` ni claves secretas.
- Backend: FastAPI conserva la identidad/autorización para sus endpoints y procesos de servidor, especialmente la futura ingesta externa. No duplicar reglas que ya viven en RLS/RPC.
- La integración SAP/PLUZ sigue pendiente. No inventar endpoints, credenciales ni JSON externos; `/api/v1/sync/runs` debe comunicar `503 INTEGRATION_PENDING` hasta recibir contrato oficial.
- Las escrituras de asignación, estado, ruta e historial respetan las RPC documentadas. No escribir directamente en tablas protegidas cuando la base exige RPC.
- El bucket `work-order-evidence` y parte de sus políticas ya existen. Inspeccionarlos y reutilizarlos antes de cambiar esquema o permisos.

## Secuencia de trabajo

1. **DB Manager**: inspeccionar migraciones/RLS, resolver una forma segura de crear usuarios locales utilizables sin guardar contraseñas ni claves en el repo, ampliar seed de forma determinista y revisar upload/lectura de evidencias.
2. **Backend**: verificar y completar el comportamiento de los endpoints existentes/configuración local sin simular una API externa inexistente; documentar los límites reales.
3. **Frontend**: implementar login, sesión, lectura/escritura Supabase, evidencias, mapa y listas. Consumir los contratos confirmados por DB y backend.
4. Ejecutar las comprobaciones relevantes definidas por `AGENTS.md`; comunicar contratos cambiados y resultados a los módulos dependientes.

## Criterios de aceptación alpha

- Un usuario puede iniciar y cerrar sesión; el rol procede del perfil en DB, no de un selector de rol ni de `user_metadata`.
- RLS limita los datos y acciones por rol; coordinador solo consulta/audita.
- El seed es repetible y crea al menos 500 órdenes espacialmente plausibles dentro de Lima Metropolitana/Callao, con variedad de estados, tipos, prioridades, asignaciones y casos sin coordenadas.
- Las evidencias usan Storage privado, validación de tipo/tamaño y metadatos relacionados con la orden; no se filtran URLs públicas ni claves secretas.
- El mapa inicia en CARTO Positron; hay selector para los cuatro estilos pedidos. No se agrupan puntos y los marcadores de órdenes se distinguen mejor.
- El panel lateral se puede ocultar/mostrar. Lista y tabla soportan volúmenes grandes con paginación/virtualización y filtros claros.
- No presentar datos demo como datos conectados, ni una sincronización SAP como exitosa si sigue sin contrato.

## Límites

No desplegar, no modificar servicios remotos, no crear commits, no mostrar secretos. No reescribir todo el repositorio. Si un requisito no puede implementarse con el contrato actual, deja el límite explícito y entrega el contrato propuesto sin inventar comportamiento.

## Prompts por módulo

- DB: [`01-db-seed-auth-storage.md`](01-db-seed-auth-storage.md)
- Backend: [`02-backend-alpha.md`](02-backend-alpha.md)
- Frontend: [`03-frontend-alpha.md`](03-frontend-alpha.md)
