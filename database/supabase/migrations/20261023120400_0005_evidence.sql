-- PLUS_LPS :: 0005
-- Metadatos de evidencias. Los binarios viven en Supabase Storage:
-- aquí solo se guarda la referencia lógica y datos de contexto.
-- Bucket privado "work-order-evidence"; convención de ruta:
--   {work_order_id}/{archivo}
-- No se guardan imágenes ni base64 en PostgreSQL.

set search_path = public, extensions;

create type public.evidence_kind as enum (
  'antes',
  'durante',
  'despues',
  'firma',
  'documento',
  'otro'
);

create table public.work_order_evidence (
  id              uuid primary key default gen_random_uuid(),
  work_order_id   uuid not null references public.work_orders (id) on delete cascade,
  assignment_id   uuid references public.work_order_assignments (id) on delete set null,
  kind            public.evidence_kind not null default 'durante',
  storage_bucket  text not null default 'work-order-evidence',
  storage_path    text not null,
  mime_type       text,
  size_bytes      bigint check (size_bytes is null or size_bytes > 0),
  captured_at     timestamptz,
  location        extensions.geometry(Point, 4326),
  uploaded_by     uuid references public.profiles (id) on delete set null,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  constraint work_order_evidence_path_not_blank check (btrim(storage_path) <> ''),
  constraint work_order_evidence_path_belongs_to_order
    check (storage_path like work_order_id::text || '/%'),
  constraint work_order_evidence_path_no_traversal
    check (position('..' in storage_path) = 0),
  constraint work_order_evidence_bucket_path_uk unique (storage_bucket, storage_path)
);

comment on table public.work_order_evidence is
  'Metadatos append-only de evidencias. El binario se sube a Storage con la ruta {work_order_id}/{archivo}.';
comment on column public.work_order_evidence.uploaded_by is
  'Se fija con auth.uid() en el trigger; no se otorga al cliente para evitar suplantación.';

create index work_order_evidence_order_idx
  on public.work_order_evidence (work_order_id, created_at desc);

create index work_order_evidence_assignment_idx
  on public.work_order_evidence (assignment_id)
  where assignment_id is not null;

create or replace function public.validate_evidence()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_assignment_order uuid;
begin
  if new.assignment_id is not null then
    select work_order_id
      into v_assignment_order
      from public.work_order_assignments
     where id = new.assignment_id;

    if v_assignment_order is null or v_assignment_order <> new.work_order_id then
      raise exception 'La asignación % no pertenece a la orden %',
        new.assignment_id, new.work_order_id
        using errcode = '23514';
    end if;
  end if;

  new.uploaded_by := coalesce(auth.uid(), new.uploaded_by);
  return new;
end;
$$;

create trigger work_order_evidence_validate
  before insert on public.work_order_evidence
  for each row execute function public.validate_evidence();

-- Bucket privado para evidencias. La creación es idempotente.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'work-order-evidence',
  'work-order-evidence',
  false,
  10485760, -- 10 MiB
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;
