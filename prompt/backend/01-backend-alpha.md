# Prompt — Backend: dejar FastAPI listo para el alpha

Trabaja en `backend` y su documentación. Antes de editar lee `AGENTS.md`, `backend/README.md`, `.env.example`, `app/config.py`, `factory.py`, `security.py`, `container.py`, routers, adaptador PostgreSQL, servicios y pruebas. Revisa `git status`.

## Estado actual

- Backend Python >=3.12 gestionado con `uv`; comando esperado: `uv sync --extra dev` y `uv run uvicorn app.main:app --reload`.
- Existen `GET /health`, `GET /api/v1/me`, `GET /api/v1/sync/availability` y `POST /api/v1/sync/runs`.
- Auth consulta Supabase Auth y `public.profiles.role`; las guardas de rol están en backend.
- La ingesta tiene staging/idempotencia en `ingest`; la API externa SAP/PLUZ no tiene contrato. La respuesta `503 INTEGRATION_PENDING` es intencional y no debe reemplazarse por un éxito simulado.
- Para alpha, el frontend usará Supabase Auth/Data API/Storage con Publishable key y RLS/RPC. No duplicar en FastAPI las mutaciones ya resueltas por RPC.

## Trabajo

1. Verificar los endpoints existentes contra el Supabase local, incluyendo autenticación, roles, CORS, configuración desde `.env` y cierre de recursos. Corregir errores de configuración o manejo de errores demostrables.
2. Alinear los nombres de variables del servidor con Publishable key sin romper configuración existente; si el backend solo necesita la clave pública para Auth, documentarlo. Cualquier clave secreta o acceso elevado permanece exclusivamente del lado servidor y nunca en `VITE_*`.
3. Asegurar respuestas HTTP/JSON estables para los casos sin token, perfil inactivo, rol no permitido, integración pendiente, corrida duplicada, error externo y error interno; no exponer DSN, tokens ni cuerpo sensible en logs/respuestas.
4. Verificar que `DATABASE_URL`/`uv` y el arranque local están documentados y que el healthcheck diferencia salud del proceso de disponibilidad de la integración/base cuando corresponda, sin cambiar el contrato innecesariamente.
5. No inventar endpoints/campos/autenticación SAP. Mientras falte contrato, disponibilidad explica qué falta y la corrida devuelve el error previsto. Si una operación de alpha requiere un endpoint servidor que no esté definido por el diseño actual, propone contrato y motivo antes de duplicar acceso directo a Supabase.
6. Actualizar `backend/README.md` con variables, comandos `uv` y límites reales del alpha.

## Aceptación

- Backend levanta con `uv` desde una instalación limpia y `.env` local.
- Endpoints existentes obedecen roles y errores documentados; no declaran exitosa la integración pendiente.
- `DATABASE_URL` y cualquier clave elevada nunca se entregan al frontend.
- Ejecutar pruebas unitarias/API pertinentes; las pruebas PostgreSQL solo si el stack local está disponible y configurado.

No despliegues ni modifiques Supabase remoto. Informa rutas/contratos verificados, archivos tocados, comandos y resultados de pruebas, así como cualquier bloqueo por falta del contrato externo.
