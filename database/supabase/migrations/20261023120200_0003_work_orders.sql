-- PLUS_LPS :: 0003
-- Órdenes de trabajo, asignaciones vigentes/históricas y auditoría de estados.
-- La orden guarda la referencia externa (source + id) para idempotencia de la
-- ingesta, sin acoplar el modelo interno al JSON de SAP (aún no definido).

set search_path = public, extensions;

create type public.work_order_type as enum (
  'corte',
  'reposicion',
  'inspeccion',
  'reconexion',
  'mantenimiento',
  'otro'
);

create type public.work_order_status as enum (
  'pendiente',
  'asignada',
  'en_proceso',
  'ejecutada',
  'imposibilitada',
  'cancelada'
);

create table public.work_orders (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  external_source   text,
  external_id       text,
  type              public.work_order_type not null,
  status            public.work_order_status not null default 'pendiente',
  priority          smallint not null default 3 check (priority between 1 and 5),
  customer_name     text,
  supply_number     text,
  address           text,
  district          text,
  zone              text,
  location          extensions.geometry(Point, 4326),
  scheduled_at      timestamptz,
  due_at            timestamptz,
  notes             text,
  cancellation_reason text,
  completed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references public.profiles (id) on delete set null,
  updated_by        uuid references public.profiles (id) on delete set null,
  constraint work_orders_code_not_blank check (btrim(code) <> ''),
  constraint work_orders_external_ref_pair
    check ((external_source is null) = (external_id is null)),
  constraint work_orders_external_source_not_blank
    check (external_source is null or btrim(external_source) <> '')
);

comment on table public.work_orders is
  'Modelo canónico interno de la orden de trabajo. location es nullable: una orden sin geocodificar sigue siendo válida.';
comment on column public.work_orders.location is
  'Punto WGS84 (SRID 4326). Solo se indexa/pinta cuando está informado.';
comment on column public.work_orders.external_source is
  'Sistema de origen (p. ej. sap). Junto a external_id forma la clave de idempotencia.';
comment on column public.work_orders.status is
  'Estado actual denormalizado. Los cambios pasan por update_work_order_status y quedan auditados.';

create unique index work_orders_external_ref_uidx
  on public.work_orders (external_source, external_id)
  where external_id is not null;

create index work_orders_status_schedule_idx
  on public.work_orders (status, scheduled_at);

create index work_orders_supply_number_idx
  on public.work_orders (supply_number)
  where supply_number is not null;

create index work_orders_district_idx
  on public.work_orders (district)
  where district is not null;

create index work_orders_location_gix
  on public.work_orders using gist (location)
  where location is not null;

-- Índice funcional para radios en metros (geography): asignación por proximidad.
create index work_orders_location_geog_gix
  on public.work_orders using gist ((location::extensions.geography))
  where location is not null;

create index work_orders_customer_trgm_idx
  on public.work_orders using gin (customer_name extensions.gin_trgm_ops);

create index work_orders_address_trgm_idx
  on public.work_orders using gin (address extensions.gin_trgm_ops);

-- Auditoría de actor: el cliente no puede falsificar created_by/updated_by
-- (esas columnas no se otorgan en los grants de la API).
create or replace function public.stamp_work_order_actor()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
    new.updated_by := coalesce(new.updated_by, auth.uid());
  else
    new.created_by := old.created_by;
    new.updated_by := coalesce(auth.uid(), new.updated_by);
  end if;
  return new;
end;
$$;

create trigger work_orders_stamp_actor
  before insert or update on public.work_orders
  for each row execute function public.stamp_work_order_actor();

create trigger work_orders_set_updated_at
  before update on public.work_orders
  for each row execute function public.set_updated_at();

create table public.work_order_assignments (
  id             uuid primary key default gen_random_uuid(),
  work_order_id  uuid not null references public.work_orders (id) on delete cascade,
  technician_id  uuid not null references public.profiles (id) on delete restrict,
  assigned_by    uuid references public.profiles (id) on delete set null,
  assigned_at    timestamptz not null default now(),
  unassigned_at  timestamptz,
  unassigned_by  uuid references public.profiles (id) on delete set null,
  end_reason     text,
  notes          text,
  constraint work_order_assignments_end_chk check (
    (unassigned_at is null and unassigned_by is null and end_reason is null)
    or unassigned_at is not null
  )
);

comment on table public.work_order_assignments is
  'Historial de asignaciones. La asignación vigente es la que tiene unassigned_at nulo (índice único parcial).';
comment on column public.work_order_assignments.end_reason is
  'Motivo de cierre: reasignada, desasignada, completada, imposibilitada, etc.';

-- Una sola asignación vigente por orden.
create unique index work_order_assignments_active_uidx
  on public.work_order_assignments (work_order_id)
  where unassigned_at is null;

create index work_order_assignments_active_technician_idx
  on public.work_order_assignments (technician_id)
  where unassigned_at is null;

create index work_order_assignments_history_idx
  on public.work_order_assignments (work_order_id, assigned_at desc);

-- Garantía de integridad: solo perfiles técnicos activos pueden recibir órdenes.
create or replace function public.enforce_technician_assignment()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.app_role;
  v_active boolean;
begin
  select role, is_active
    into v_role, v_active
    from public.profiles
   where id = new.technician_id;

  if v_role is distinct from 'tecnico'::public.app_role then
    raise exception 'El perfil % no tiene rol tecnico', new.technician_id
      using errcode = '23514';
  end if;

  if not coalesce(v_active, false) then
    raise exception 'El perfil % no esta activo', new.technician_id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger work_order_assignments_enforce_technician
  before insert or update of technician_id on public.work_order_assignments
  for each row execute function public.enforce_technician_assignment();

create table public.work_order_status_history (
  id             bigint generated always as identity primary key,
  work_order_id  uuid not null references public.work_orders (id) on delete cascade,
  from_status    public.work_order_status,
  to_status      public.work_order_status not null,
  changed_by     uuid references public.profiles (id) on delete set null,
  changed_at     timestamptz not null default now(),
  reason         text,
  location       extensions.geometry(Point, 4326),
  metadata       jsonb not null default '{}'::jsonb
);

comment on table public.work_order_status_history is
  'Auditoría append-only de cambios de estado. Se escribe por trigger; la API no inserta directamente.';
comment on column public.work_order_status_history.changed_by is
  'auth.uid() del actor. Queda nulo cuando el cambio lo hace un proceso con service_role sin JWT.';

create index work_order_status_history_order_idx
  on public.work_order_status_history (work_order_id, changed_at desc);

-- Registro automático de todo cambio de estado (incluye los hechos por RPC).
-- El motivo y la ubicación se transportan de forma transaccional con set_config
-- desde las funciones de negocio; nunca se confía en ellos para autorizar.
create or replace function public.log_work_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_reason text := nullif(current_setting('plus.status_reason', true), '');
  v_location_text text := nullif(current_setting('plus.status_location', true), '');
  v_location extensions.geometry(Point, 4326);
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if v_location_text is not null then
      v_location := extensions.ST_GeomFromEWKT(v_location_text);
    end if;

    insert into public.work_order_status_history (
      work_order_id, from_status, to_status, changed_by, reason, location
    )
    values (
      new.id, old.status, new.status, auth.uid(), v_reason, v_location
    );
  end if;

  return new;
end;
$$;

create trigger work_orders_log_status_change
  after update of status on public.work_orders
  for each row execute function public.log_work_order_status_change();
