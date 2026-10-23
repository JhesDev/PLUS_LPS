-- PLUS_LPS :: 0004
-- Rutas/jornadas y paradas ordenadas. No se implementa optimización vial:
-- el orden es una decisión operativa del despachador.

set search_path = public, extensions;

create type public.route_status as enum (
  'planificada',
  'en_curso',
  'completada',
  'cancelada'
);

create type public.route_stop_status as enum (
  'pendiente',
  'en_proceso',
  'completada',
  'omitida'
);

create table public.routes (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  technician_id  uuid not null references public.profiles (id) on delete restrict,
  route_date     date not null,
  status         public.route_status not null default 'planificada',
  started_at     timestamptz,
  completed_at   timestamptz,
  notes          text,
  created_by     uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint routes_code_not_blank check (btrim(code) <> ''),
  constraint routes_completed_requires_start
    check (completed_at is null or started_at is not null)
);

comment on table public.routes is
  'Jornada/ruta de un técnico. Una ruta puede contener paradas de órdenes de su asignación.';

create index routes_technician_date_idx on public.routes (technician_id, route_date);
create index routes_date_status_idx on public.routes (route_date, status);

create or replace function public.stamp_route_actor()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(new.created_by, auth.uid());
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

create trigger routes_stamp_actor
  before insert or update on public.routes
  for each row execute function public.stamp_route_actor();

create trigger routes_set_updated_at
  before update on public.routes
  for each row execute function public.set_updated_at();

-- Una ruta solo puede pertenecer a un técnico activo (misma garantía que las asignaciones).
create trigger routes_enforce_technician
  before insert or update of technician_id on public.routes
  for each row execute function public.enforce_technician_assignment();

create table public.route_stops (
  id             uuid primary key default gen_random_uuid(),
  route_id       uuid not null references public.routes (id) on delete cascade,
  work_order_id  uuid not null references public.work_orders (id) on delete restrict,
  stop_order     smallint not null check (stop_order > 0),
  status         public.route_stop_status not null default 'pendiente',
  planned_at     timestamptz,
  arrived_at     timestamptz,
  completed_at   timestamptz,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint route_stops_order_uidx unique (route_id, stop_order) deferrable initially deferred,
  constraint route_stops_order_uk unique (route_id, work_order_id)
);

comment on table public.route_stops is
  'Paradas ordenadas de una ruta. El estado de la parada no sustituye el estado de la orden.';

create index route_stops_work_order_idx on public.route_stops (work_order_id);
create index route_stops_route_status_idx on public.route_stops (route_id, status);

create trigger route_stops_set_updated_at
  before update on public.route_stops
  for each row execute function public.set_updated_at();
