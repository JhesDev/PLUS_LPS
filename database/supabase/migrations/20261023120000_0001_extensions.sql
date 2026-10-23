-- PLUS_LPS :: 0001
-- Extensiones requeridas por el modelo operativo.
-- PostGIS y pg_trgm se instalan en el esquema "extensions" (convención Supabase),
-- no en "public", para no contaminar el esquema expuesto por la API.
-- No se asume que estén preinstaladas: la migración las habilita explícitamente.

set search_path = public, extensions;

create schema if not exists extensions;

create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

comment on extension postgis is 'Tipos y funciones espaciales para ubicaciones de órdenes y técnicos (SRID 4326).';
comment on extension pg_trgm is 'Búsqueda por similitud de cliente/dirección en el mapa y tablas.';
