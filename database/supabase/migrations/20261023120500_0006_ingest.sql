-- PLUS_LPS :: 0006
-- Frontera de ingesta: zona de staging separada del modelo operativo.
-- No se asume el contrato de SAP: se almacena el payload original tal cual
-- (jsonb), su hash y el vínculo opcional con la orden ya normalizada.
-- El esquema "ingest" NO se expone en la API (config.toml solo public/graphql_public)
-- y no concede privilegios a anon/authenticated.

create schema if not exists ingest;

comment on schema ingest is
  'Staging de ingesta externa. Solo service_role/backend. No es modelo operativo ni se expone por PostgREST.';

create type ingest.batch_status as enum ('recibido', 'procesado', 'parcial', 'error');
create type ingest.record_status as enum ('recibido', 'procesado', 'omitido', 'error');

create table ingest.batches (
  id             uuid primary key default gen_random_uuid(),
  source         text not null default 'sap',
  received_at    timestamptz not null default now(),
  payload_hash   text,
  status         ingest.batch_status not null default 'recibido',
  records_count  integer not null default 0 check (records_count >= 0),
  notes          text,
  created_at     timestamptz not null default now(),
  constraint ingest_batches_source_not_blank check (btrim(source) <> '')
);

comment on table ingest.batches is
  'Lote de ingesta recibido de un sistema externo. Permite trazar reintentos y resultados.';

create index ingest_batches_received_idx on ingest.batches (received_at desc);
create index ingest_batches_status_idx on ingest.batches (status, received_at desc);

create table ingest.records (
  id             uuid primary key default gen_random_uuid(),
  batch_id       uuid not null references ingest.batches (id) on delete cascade,
  source         text not null default 'sap',
  entity         text not null default 'work_order',
  external_id    text,
  payload        jsonb not null,
  payload_hash   text not null,
  status         ingest.record_status not null default 'recibido',
  work_order_id  uuid references public.work_orders (id) on delete set null,
  error_message  text,
  processed_at   timestamptz,
  created_at     timestamptz not null default now(),
  constraint ingest_records_source_not_blank check (btrim(source) <> ''),
  constraint ingest_records_entity_not_blank check (btrim(entity) <> ''),
  constraint ingest_records_payload_hash_not_blank check (btrim(payload_hash) <> ''),
  -- Deduplicación de payloads idénticos del mismo origen/entidad.
  constraint ingest_records_payload_uk unique (source, entity, payload_hash)
);

comment on table ingest.records is
  'Registro crudo de ingesta. payload conserva el JSON original; work_order_id se llena cuando el backend normaliza.';

create index ingest_records_batch_idx on ingest.records (batch_id);
create index ingest_records_status_idx on ingest.records (status, created_at);
create index ingest_records_external_idx
  on ingest.records (source, external_id)
  where external_id is not null;

alter table ingest.batches enable row level security;
alter table ingest.records enable row level security;
