# PLUS_LPS

Boceto de una plataforma para visualizar y gestionar órdenes de trabajo en mapa. Incluye paneles para despacho, coordinación en modo lectura/auditoría y jornada del técnico.

## Estado actual

- **Frontend:** Vue 3, TypeScript, Vite y MapLibre. Usa datos locales ficticios; aún no consume órdenes del backend.
- **Backend:** FastAPI con `uv`. Expone salud, identidad y estado de sincronización. La conexión con SAP/PLUZ está pendiente de recibir el contrato de la API externa.
- **Base de datos:** Supabase local sobre PostgreSQL 17 con PostGIS. Las migraciones y el seed están en `database/supabase`.

## Requisitos

- Docker Desktop en ejecución y Supabase CLI.
- Python 3.12 o superior y [uv](https://docs.astral.sh/uv/).
- Node.js 20 o superior y npm.

## Arranque local

Inicia Supabase en una terminal:

```powershell
cd database/supabase
supabase start
supabase db reset
```

`supabase db reset` recrea la base local y aplica las migraciones y `seed.sql`.

En otra terminal, configura y arranca el backend:

```powershell
Copy-Item backend/.env.example backend/.env
```

Completa `backend/.env` con los valores del Supabase local (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` y `DATABASE_URL`; puedes consultarlos con `supabase status`). `SUPABASE_ANON_KEY` sigue aceptada por compatibilidad. No compartas ni versionas ese archivo.

```powershell
cd backend
uv sync --extra dev
uv run uvicorn app.main:app --reload
```

La API queda disponible en `http://127.0.0.1:8000` y su documentación en `http://127.0.0.1:8000/docs`.

En una tercera terminal, inicia el frontend:

```powershell
cd frontend
npm ci
npm run dev
```

Abre `http://localhost:5173`. El frontend funciona en modo demo y no requiere credenciales para mostrar sus datos ficticios.

## Documentación

- [Base de datos, migraciones y seed](database/supabase/README.md)
- [Backend, configuración y endpoints](backend/README.md)
- [Frontend y vistas](frontend/README.md)
- [Instrucciones para agentes](AGENTS.md)
