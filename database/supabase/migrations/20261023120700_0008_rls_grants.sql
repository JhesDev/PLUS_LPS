-- PLUS_LPS :: 0008
-- RLS y privilegios. Principio: denegar por defecto y conceder lo mínimo.
--
-- Matriz:
--   coordinador : SELECT en todo el modelo operativo. Sin escritura.
--   despachador : gestión operativa (órdenes, rutas, paradas, evidencias) + RPC.
--   tecnico     : SELECT de lo propio + RPC de avance/resultado/evidencias.
--   anon        : sin acceso.
--   service_role: backend (bypassa RLS), conserva grants.
--
-- Las asignaciones y el historial de estados NO se escriben por tabla:
-- solo mediante assign_work_order / unassign_work_order / update_work_order_status.

set search_path = public, extensions;

alter table public.profiles enable row level security;
alter table public.technician_details enable row level security;
alter table public.work_orders enable row level security;
alter table public.work_order_assignments enable row level security;
alter table public.work_order_status_history enable row level security;
alter table public.routes enable row level security;
alter table public.route_stops enable row level security;
alter table public.work_order_evidence enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or (select public.current_app_role()) in ('coordinador', 'despachador')
  );

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- technician_details
-- ---------------------------------------------------------------------------

create policy technician_details_select on public.technician_details
  for select to authenticated
  using (
    profile_id = auth.uid()
    or (select public.current_app_role()) in ('coordinador', 'despachador')
  );

create policy technician_details_insert on public.technician_details
  for insert to authenticated
  with check ((select public.current_app_role()) = 'despachador');

create policy technician_details_update on public.technician_details
  for update to authenticated
  using (
    profile_id = auth.uid()
    or (select public.current_app_role()) = 'despachador'
  )
  with check (
    profile_id = auth.uid()
    or (select public.current_app_role()) = 'despachador'
  );

-- ---------------------------------------------------------------------------
-- work_orders
-- ---------------------------------------------------------------------------

create policy work_orders_select on public.work_orders
  for select to authenticated
  using (
    (select public.current_app_role()) in ('coordinador', 'despachador')
    or (
      (select public.current_app_role()) = 'tecnico'
      and public.can_view_work_order(id)
    )
  );

create policy work_orders_insert on public.work_orders
  for insert to authenticated
  with check ((select public.current_app_role()) = 'despachador');

create policy work_orders_update on public.work_orders
  for update to authenticated
  using ((select public.current_app_role()) = 'despachador')
  with check ((select public.current_app_role()) = 'despachador');

-- ---------------------------------------------------------------------------
-- work_order_assignments (solo lectura; escritura vía RPC)
-- ---------------------------------------------------------------------------

create policy work_order_assignments_select on public.work_order_assignments
  for select to authenticated
  using (
    technician_id = auth.uid()
    or (select public.current_app_role()) in ('coordinador', 'despachador')
  );

-- ---------------------------------------------------------------------------
-- work_order_status_history (solo lectura; escritura vía trigger)
-- ---------------------------------------------------------------------------

create policy work_order_status_history_select on public.work_order_status_history
  for select to authenticated
  using (
    (select public.current_app_role()) in ('coordinador', 'despachador')
    or public.can_view_work_order(work_order_id)
  );

-- ---------------------------------------------------------------------------
-- routes
-- ---------------------------------------------------------------------------

create policy routes_select on public.routes
  for select to authenticated
  using (
    technician_id = auth.uid()
    or (select public.current_app_role()) in ('coordinador', 'despachador')
  );

create policy routes_insert on public.routes
  for insert to authenticated
  with check ((select public.current_app_role()) = 'despachador');

create policy routes_update on public.routes
  for update to authenticated
  using ((select public.current_app_role()) = 'despachador')
  with check ((select public.current_app_role()) = 'despachador');

-- ---------------------------------------------------------------------------
-- route_stops
-- ---------------------------------------------------------------------------

create policy route_stops_select on public.route_stops
  for select to authenticated
  using (
    (select public.current_app_role()) in ('coordinador', 'despachador')
    or exists (
      select 1
        from public.routes r
       where r.id = route_id
         and r.technician_id = auth.uid()
    )
  );

create policy route_stops_insert on public.route_stops
  for insert to authenticated
  with check ((select public.current_app_role()) = 'despachador');

create policy route_stops_update on public.route_stops
  for update to authenticated
  using ((select public.current_app_role()) = 'despachador')
  with check ((select public.current_app_role()) = 'despachador');

create policy route_stops_delete on public.route_stops
  for delete to authenticated
  using ((select public.current_app_role()) = 'despachador');

-- ---------------------------------------------------------------------------
-- work_order_evidence
-- ---------------------------------------------------------------------------

create policy work_order_evidence_select on public.work_order_evidence
  for select to authenticated
  using (
    (select public.current_app_role()) in ('coordinador', 'despachador')
    or public.can_view_work_order(work_order_id)
  );

create policy work_order_evidence_insert on public.work_order_evidence
  for insert to authenticated
  with check (
    (select public.current_app_role()) = 'despachador'
    or (
      (select public.current_app_role()) = 'tecnico'
      and public.can_report_work_order(work_order_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Storage: políticas sobre los objetos del bucket de evidencias.
-- Convención: {work_order_id}/{archivo}. Sin políticas de UPDATE/DELETE:
-- las evidencias son append-only desde la API.
-- ---------------------------------------------------------------------------

create policy work_order_evidence_objects_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'work-order-evidence'
    and public.can_view_work_order(public.storage_order_id(name))
  );

create policy work_order_evidence_objects_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'work-order-evidence'
    and (
      (select public.current_app_role()) = 'despachador'
      or (
        (select public.current_app_role()) = 'tecnico'
        and public.can_report_work_order(public.storage_order_id(name))
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Privilegios: partir de cero para anon/authenticated y conceder por columna.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- anon no accede a ninguna tabla del modelo.
grant usage on schema public to anon, authenticated, service_role;

grant select on public.profiles to authenticated;
grant update (full_name, phone, updated_at) on public.profiles to authenticated;

grant select on public.technician_details to authenticated;
grant insert (profile_id, employee_code, vehicle_label, max_daily_orders, notes)
  on public.technician_details to authenticated;
grant update (employee_code, vehicle_label, max_daily_orders, notes,
              current_location, location_updated_at, updated_at)
  on public.technician_details to authenticated;

grant select on public.work_orders to authenticated;
grant insert (code, type, priority, customer_name, supply_number, address,
              district, zone, location, scheduled_at, due_at, notes)
  on public.work_orders to authenticated;
grant update (type, priority, customer_name, supply_number, address, district,
              zone, location, scheduled_at, due_at, notes, updated_at)
  on public.work_orders to authenticated;

grant select on public.work_order_assignments to authenticated;
grant select on public.work_order_status_history to authenticated;

grant select on public.routes to authenticated;
grant insert (code, technician_id, route_date, notes)
  on public.routes to authenticated;
grant update (code, technician_id, route_date, notes, updated_at)
  on public.routes to authenticated;

grant select on public.route_stops to authenticated;
grant insert (route_id, work_order_id, stop_order, planned_at, notes)
  on public.route_stops to authenticated;
grant update (stop_order, planned_at, notes, updated_at)
  on public.route_stops to authenticated;
grant delete on public.route_stops to authenticated;

grant select on public.work_order_evidence to authenticated;
grant insert (work_order_id, assignment_id, kind, storage_bucket, storage_path,
              mime_type, size_bytes, captured_at, location, metadata)
  on public.work_order_evidence to authenticated;

-- Funciones invocables por usuarios autenticados (helpers usados por RLS incluidos).
grant execute on function public.current_app_role() to authenticated;
grant execute on function public.can_view_work_order(uuid) to authenticated;
grant execute on function public.can_report_work_order(uuid) to authenticated;
grant execute on function public.storage_order_id(text) to authenticated;
grant execute on function public.assign_work_order(uuid, uuid, text) to authenticated;
grant execute on function public.unassign_work_order(uuid, text) to authenticated;
grant execute on function public.update_work_order_status(
  uuid, public.work_order_status, text, double precision, double precision
) to authenticated;
grant execute on function public.set_route_status(uuid, public.route_status) to authenticated;
grant execute on function public.set_route_stop_status(uuid, public.route_stop_status) to authenticated;

-- service_role: backend. Bypassa RLS por atributo de rol, pero necesita grants.
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- Staging: invisible para la API.
revoke all on schema ingest from public, anon, authenticated;
grant usage on schema ingest to service_role;
grant all on all tables in schema ingest to service_role;
grant usage, select on all sequences in schema ingest to service_role;

-- Endurecer objetos futuros creados por migraciones (rol postgres).
-- Cada migración nueva debe conceder explícitamente lo que exponga.
alter default privileges in schema public
  revoke all on tables from anon, authenticated;
alter default privileges in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges in schema ingest
  grant all on tables to service_role;
