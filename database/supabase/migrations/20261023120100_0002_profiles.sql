-- PLUS_LPS :: 0002
-- Roles, perfiles vinculados a Supabase Auth y datos operativos del técnico.
-- El rol se guarda en public.profiles.role (no en user_metadata, que es editable
-- por el propio usuario). El alta toma el rol desde raw_app_meta_data (solo
-- modificable con service_role/Admin API); si no viene, el valor seguro es "tecnico".

set search_path = public, extensions;

create type public.app_role as enum ('coordinador', 'despachador', 'tecnico');

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.app_role not null default 'tecnico',
  full_name   text not null,
  phone       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint profiles_full_name_not_blank check (btrim(full_name) <> '')
);

comment on table public.profiles is
  'Perfil de aplicación por usuario de auth.users. Fuente de verdad del rol autorizado.';
comment on column public.profiles.role is
  'Rol autorizado. Solo service_role/Admin API debe modificarlo; RLS y grants impiden la auto-escalada.';
comment on column public.profiles.is_active is
  'Un perfil inactivo no obtiene rol efectivo en current_app_role() y no puede recibir asignaciones.';

create index profiles_role_active_idx on public.profiles (role) where is_active;

create table public.technician_details (
  profile_id         uuid primary key references public.profiles (id) on delete cascade,
  employee_code      text unique,
  vehicle_label      text,
  max_daily_orders   smallint not null default 10
                     check (max_daily_orders between 1 and 100),
  current_location   extensions.geometry(Point, 4326),
  location_updated_at timestamptz,
  notes              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.technician_details is
  'Datos operativos del técnico. No almacena credenciales ni datos de autenticación.';
comment on column public.technician_details.current_location is
  'Última posición GPS conocida del técnico (SRID 4326). Actualización opcional/futura.';

create index technician_details_location_gix
  on public.technician_details using gist (current_location)
  where current_location is not null;

-- Índice funcional para consultas de proximidad en metros (geography).
create index technician_details_location_geog_gix
  on public.technician_details using gist ((current_location::extensions.geography))
  where current_location is not null;

-- Trigger genérico de updated_at para tablas mutables.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger technician_details_set_updated_at
  before update on public.technician_details
  for each row execute function public.set_updated_at();

-- Alta automática de perfil al crear un usuario en Supabase Auth.
-- El nombre puede venir de raw_user_meta_data (editable, solo presentación).
-- El rol SOLO se acepta desde raw_app_meta_data (no editable por el usuario).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.app_role := 'tecnico';
  v_name text;
begin
  if new.raw_app_meta_data is not null
     and new.raw_app_meta_data ->> 'role' in ('coordinador', 'despachador', 'tecnico') then
    v_role := (new.raw_app_meta_data ->> 'role')::public.app_role;
  end if;

  v_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Usuario ' || left(new.id::text, 8)
  );

  insert into public.profiles (id, role, full_name)
  values (new.id, v_role, v_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
