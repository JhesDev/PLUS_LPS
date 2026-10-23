-- PLUS_LPS :: 0007
-- Helpers de autorización y RPC de negocio.
-- Reglas:
--   * El rol se resuelve SIEMPRE desde public.profiles, nunca desde el JWT/user_metadata.
--   * Las tablas de asignaciones/auditoría no se escriben directamente desde la API:
--     solo estas funciones SECURITY DEFINER, que validan rol y transiciones.
--   * service_role puede operar sin JWT (backend), conservando trazabilidad por trigger.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_service_request()
returns boolean
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(auth.role() = 'service_role', false);
$$;

comment on function public.is_service_request() is
  'True cuando la petición usa la service_role key. No autoriza por sí sola a un usuario final.';

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role
    from public.profiles p
   where p.id = auth.uid()
     and p.is_active;
$$;

comment on function public.current_app_role() is
  'Rol efectivo del usuario autenticado. NULL si no tiene perfil o está inactivo.';

create or replace function public.can_view_work_order(p_work_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when p_work_order_id is null then false
    when public.current_app_role() in ('coordinador', 'despachador') then true
    when public.current_app_role() = 'tecnico' then
      exists (
        select 1
          from public.work_order_assignments a
         where a.work_order_id = p_work_order_id
           and a.technician_id = auth.uid()
           and a.unassigned_at is null
      )
      or exists (
        select 1
          from public.route_stops rs
          join public.routes r on r.id = rs.route_id
         where rs.work_order_id = p_work_order_id
           and r.technician_id = auth.uid()
      )
    else false
  end;
$$;

comment on function public.can_view_work_order(uuid) is
  'Visibilidad de una orden: staff completo; técnico solo si está asignado o la tiene en una ruta.';

create or replace function public.can_report_work_order(p_work_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.work_order_assignments a
     where a.work_order_id = p_work_order_id
       and a.technician_id = auth.uid()
       and a.unassigned_at is null
  );
$$;

comment on function public.can_report_work_order(uuid) is
  'True si el técnico autenticado tiene la orden asignada de forma vigente (puede reportar avance/evidencias).';

-- Extrae el work_order_id de la convención de rutas de Storage: {uuid}/{archivo}.
-- Devuelve NULL en lugar de fallar si la ruta no cumple el formato.
create or replace function public.storage_order_id(p_name text)
returns uuid
language plpgsql
immutable
set search_path = public, pg_temp
as $$
begin
  return split_part(p_name, '/', 1)::uuid;
exception
  when others then
    return null;
end;
$$;

comment on function public.storage_order_id(text) is
  'Parsea {work_order_id}/... de Storage de forma segura; NULL si no es un UUID válido.';

-- ---------------------------------------------------------------------------
-- Asignaciones
-- ---------------------------------------------------------------------------

create or replace function public.assign_work_order(
  p_work_order_id uuid,
  p_technician_id uuid,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_order public.work_orders%rowtype;
  v_previous_id uuid;
  v_previous_tech uuid;
  v_assignment_id uuid;
  v_reason text;
begin
  if not (public.current_app_role() = 'despachador' or public.is_service_request()) then
    raise exception 'Solo un despachador puede asignar órdenes'
      using errcode = '42501';
  end if;

  select *
    into v_order
    from public.work_orders
   where id = p_work_order_id
   for update;

  if not found then
    raise exception 'La orden % no existe', p_work_order_id
      using errcode = 'P0002';
  end if;

  if v_order.status in ('ejecutada', 'cancelada') then
    raise exception 'La orden % está en estado % y no admite asignación',
      v_order.code, v_order.status
      using errcode = '23514';
  end if;

  perform 1
    from public.profiles
   where id = p_technician_id
     and role = 'tecnico'
     and is_active;

  if not found then
    raise exception 'El técnico % no existe, no tiene rol tecnico o está inactivo', p_technician_id
      using errcode = '23514';
  end if;

  select id, technician_id
    into v_previous_id, v_previous_tech
    from public.work_order_assignments
   where work_order_id = p_work_order_id
     and unassigned_at is null
   for update;

  -- Reasignar al mismo técnico es idempotente: solo actualiza la nota.
  if v_previous_id is not null and v_previous_tech = p_technician_id then
    update public.work_order_assignments
       set notes = coalesce(nullif(btrim(p_notes), ''), notes)
     where id = v_previous_id;
    return v_previous_id;
  end if;

  if v_previous_id is not null then
    update public.work_order_assignments
       set unassigned_at = now(),
           unassigned_by = v_actor,
           end_reason = 'reasignada'
     where id = v_previous_id;
    v_reason := 'Reasignada a otro técnico';
  else
    v_reason := 'Asignada a técnico';
  end if;

  insert into public.work_order_assignments (
    work_order_id, technician_id, assigned_by, notes
  )
  values (
    p_work_order_id, p_technician_id, v_actor, nullif(btrim(p_notes), '')
  )
  returning id into v_assignment_id;

  perform set_config('plus.status_reason', v_reason, true);
  update public.work_orders
     set status = 'asignada'
   where id = p_work_order_id;

  return v_assignment_id;
end;
$$;

comment on function public.assign_work_order(uuid, uuid, text) is
  'Despachador/service_role: cierra la asignación vigente y crea una nueva; deja la orden en asignada. Idempotente para el mismo técnico.';

create or replace function public.unassign_work_order(
  p_work_order_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_order public.work_orders%rowtype;
  v_assignment_id uuid;
  v_reason text := coalesce(nullif(btrim(p_reason), ''), 'desasignada');
begin
  if not (public.current_app_role() = 'despachador' or public.is_service_request()) then
    raise exception 'Solo un despachador puede desasignar órdenes'
      using errcode = '42501';
  end if;

  select *
    into v_order
    from public.work_orders
   where id = p_work_order_id
   for update;

  if not found then
    raise exception 'La orden % no existe', p_work_order_id
      using errcode = 'P0002';
  end if;

  if v_order.status in ('ejecutada', 'cancelada') then
    raise exception 'La orden % está en estado % y no admite desasignación',
      v_order.code, v_order.status
      using errcode = '23514';
  end if;

  select id
    into v_assignment_id
    from public.work_order_assignments
   where work_order_id = p_work_order_id
     and unassigned_at is null
   for update;

  if v_assignment_id is null then
    raise exception 'La orden % no tiene una asignación vigente', v_order.code
      using errcode = 'P0002';
  end if;

  update public.work_order_assignments
     set unassigned_at = now(),
         unassigned_by = v_actor,
         end_reason = v_reason
   where id = v_assignment_id;

  perform set_config('plus.status_reason', 'Desasignada: ' || v_reason, true);
  update public.work_orders
     set status = 'pendiente'
   where id = p_work_order_id;

  return v_assignment_id;
end;
$$;

comment on function public.unassign_work_order(uuid, text) is
  'Despachador/service_role: cierra la asignación vigente y devuelve la orden a pendiente.';

-- ---------------------------------------------------------------------------
-- Estados de la orden
-- ---------------------------------------------------------------------------

create or replace function public.update_work_order_status(
  p_work_order_id uuid,
  p_status public.work_order_status,
  p_reason text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_role public.app_role := public.current_app_role();
  v_is_service boolean := public.is_service_request();
  v_order public.work_orders%rowtype;
  v_reason text := nullif(btrim(p_reason), '');
  v_location extensions.geometry(Point, 4326);
  v_allowed boolean := false;
begin
  if v_role is null and not v_is_service then
    raise exception 'Usuario sin perfil activo' using errcode = '42501';
  end if;

  if v_role = 'coordinador' then
    raise exception 'El coordinador solo tiene acceso de lectura/auditoría'
      using errcode = '42501';
  end if;

  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Latitud y longitud deben informarse juntas'
      using errcode = '22023';
  end if;

  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then
    raise exception 'Latitud fuera de rango: %', p_latitude using errcode = '22023';
  end if;

  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then
    raise exception 'Longitud fuera de rango: %', p_longitude using errcode = '22023';
  end if;

  select *
    into v_order
    from public.work_orders
   where id = p_work_order_id
   for update;

  if not found then
    raise exception 'La orden % no existe', p_work_order_id
      using errcode = 'P0002';
  end if;

  if v_order.status = p_status then
    raise exception 'La orden % ya está en estado %', v_order.code, p_status
      using errcode = '22023';
  end if;

  if v_role = 'tecnico' then
    if not public.can_report_work_order(p_work_order_id) then
      raise exception 'El técnico no tiene la orden % asignada de forma vigente', v_order.code
        using errcode = '42501';
    end if;

    v_allowed := (v_order.status, p_status) in (
      ('asignada'::public.work_order_status, 'en_proceso'::public.work_order_status),
      ('en_proceso'::public.work_order_status, 'ejecutada'::public.work_order_status),
      ('en_proceso'::public.work_order_status, 'imposibilitada'::public.work_order_status)
    );
  elsif v_role = 'despachador' then
    v_allowed := (v_order.status, p_status) in (
      ('pendiente'::public.work_order_status, 'cancelada'::public.work_order_status),
      ('asignada'::public.work_order_status, 'en_proceso'::public.work_order_status),
      ('asignada'::public.work_order_status, 'cancelada'::public.work_order_status),
      ('en_proceso'::public.work_order_status, 'ejecutada'::public.work_order_status),
      ('en_proceso'::public.work_order_status, 'imposibilitada'::public.work_order_status),
      ('en_proceso'::public.work_order_status, 'cancelada'::public.work_order_status),
      ('imposibilitada'::public.work_order_status, 'pendiente'::public.work_order_status)
    );
  end if;

  -- service_role puede corregir excepcionalmente cualquier transición.
  if not v_is_service and not v_allowed then
    raise exception 'Transición de estado no permitida: % -> % (rol %)',
      v_order.status, p_status, coalesce(v_role::text, 'service_role')
      using errcode = '23514';
  end if;

  if p_status in ('imposibilitada', 'cancelada') and v_reason is null then
    raise exception 'El estado % requiere un motivo', p_status
      using errcode = '23514';
  end if;

  if p_latitude is not null then
    v_location := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitude, p_latitude),
      4326
    );
  end if;

  perform set_config(
    'plus.status_reason',
    coalesce(v_reason, 'Cambio de estado: ' || v_order.status || ' -> ' || p_status),
    true
  );
  perform set_config(
    'plus.status_location',
    coalesce(extensions.ST_AsEWKT(v_location), ''),
    true
  );

  update public.work_orders
     set status = p_status,
         completed_at = case
           when p_status in ('ejecutada', 'imposibilitada') then now()
           else null
         end,
         cancellation_reason = case
           when p_status = 'cancelada' then v_reason
           else null
         end
   where id = p_work_order_id;
end;
$$;

comment on function public.update_work_order_status(uuid, public.work_order_status, text, double precision, double precision) is
  'Despachador o técnico asignado: aplica transiciones válidas y deja auditoría con motivo/ubicación.';

-- ---------------------------------------------------------------------------
-- Rutas
-- ---------------------------------------------------------------------------

create or replace function public.set_route_status(
  p_route_id uuid,
  p_status public.route_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.app_role := public.current_app_role();
  v_is_service boolean := public.is_service_request();
  v_route public.routes%rowtype;
  v_allowed boolean := false;
begin
  if v_role is null and not v_is_service then
    raise exception 'Usuario sin perfil activo' using errcode = '42501';
  end if;

  if v_role = 'coordinador' then
    raise exception 'El coordinador solo tiene acceso de lectura/auditoría'
      using errcode = '42501';
  end if;

  select *
    into v_route
    from public.routes
   where id = p_route_id
   for update;

  if not found then
    raise exception 'La ruta % no existe', p_route_id
      using errcode = 'P0002';
  end if;

  if v_route.status = p_status then
    raise exception 'La ruta % ya está en estado %', v_route.code, p_status
      using errcode = '22023';
  end if;

  if v_role = 'despachador' then
    v_allowed := (v_route.status, p_status) in (
      ('planificada'::public.route_status, 'en_curso'::public.route_status),
      ('planificada'::public.route_status, 'cancelada'::public.route_status),
      ('en_curso'::public.route_status, 'completada'::public.route_status),
      ('en_curso'::public.route_status, 'cancelada'::public.route_status)
    );
  elsif v_role = 'tecnico' then
    if v_route.technician_id <> auth.uid() then
      raise exception 'El técnico no es dueño de la ruta %', v_route.code
        using errcode = '42501';
    end if;

    v_allowed := (v_route.status, p_status) in (
      ('planificada'::public.route_status, 'en_curso'::public.route_status),
      ('en_curso'::public.route_status, 'completada'::public.route_status)
    );
  end if;

  if not v_is_service and not v_allowed then
    raise exception 'Transición de ruta no permitida: % -> %',
      v_route.status, p_status
      using errcode = '23514';
  end if;

  update public.routes
     set status = p_status,
         started_at = case
           when p_status = 'en_curso' then coalesce(started_at, now())
           else started_at
         end,
         completed_at = case
           when p_status = 'completada' then coalesce(completed_at, now())
           else completed_at
         end
   where id = p_route_id;
end;
$$;

comment on function public.set_route_status(uuid, public.route_status) is
  'Despachador/técnico dueño de la ruta: aplica transiciones válidas de la jornada.';

create or replace function public.set_route_stop_status(
  p_stop_id uuid,
  p_status public.route_stop_status
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.app_role := public.current_app_role();
  v_is_service boolean := public.is_service_request();
  v_stop public.route_stops%rowtype;
  v_technician_id uuid;
  v_allowed boolean := false;
begin
  if v_role is null and not v_is_service then
    raise exception 'Usuario sin perfil activo' using errcode = '42501';
  end if;

  if v_role = 'coordinador' then
    raise exception 'El coordinador solo tiene acceso de lectura/auditoría'
      using errcode = '42501';
  end if;

  select rs.*
    into v_stop
    from public.route_stops rs
   where rs.id = p_stop_id
   for update;

  if not found then
    raise exception 'La parada % no existe', p_stop_id
      using errcode = 'P0002';
  end if;

  select technician_id into v_technician_id
    from public.routes
   where id = v_stop.route_id;

  if v_role = 'tecnico' and v_technician_id <> auth.uid() then
    raise exception 'El técnico no es dueño de la ruta de la parada %', p_stop_id
      using errcode = '42501';
  end if;

  if v_stop.status = p_status then
    raise exception 'La parada % ya está en estado %', p_stop_id, p_status
      using errcode = '22023';
  end if;

  v_allowed := (v_stop.status, p_status) in (
    ('pendiente'::public.route_stop_status, 'en_proceso'::public.route_stop_status),
    ('pendiente'::public.route_stop_status, 'omitida'::public.route_stop_status),
    ('en_proceso'::public.route_stop_status, 'completada'::public.route_stop_status),
    ('en_proceso'::public.route_stop_status, 'omitida'::public.route_stop_status)
  );

  if not v_is_service and not v_allowed then
    raise exception 'Transición de parada no permitida: % -> %',
      v_stop.status, p_status
      using errcode = '23514';
  end if;

  update public.route_stops
     set status = p_status,
         arrived_at = case
           when p_status = 'en_proceso' then coalesce(arrived_at, now())
           else arrived_at
         end,
         completed_at = case
           when p_status in ('completada', 'omitida') then coalesce(completed_at, now())
           else completed_at
         end
   where id = p_stop_id;
end;
$$;

comment on function public.set_route_stop_status(uuid, public.route_stop_status) is
  'Despachador o técnico dueño: registra avance de una parada sin alterar la orden.';
