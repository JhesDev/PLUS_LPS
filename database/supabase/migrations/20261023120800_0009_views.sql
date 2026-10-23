-- PLUS_LPS :: 0009
-- Vistas de lectura para el mapa y la carga operativa.
-- security_invoker = true: las RLS de las tablas subyacentes se aplican
-- con los privilegios del usuario que consulta, no del dueño de la vista.

set search_path = public, extensions;

create or replace view public.v_work_orders_map
with (security_invoker = true)
as
select
  o.id,
  o.code,
  o.type,
  o.status,
  o.priority,
  o.supply_number,
  o.customer_name,
  o.address,
  o.district,
  o.zone,
  o.scheduled_at,
  o.due_at,
  o.location,
  extensions.ST_Y(o.location) as latitude,
  extensions.ST_X(o.location) as longitude,
  case
    when o.location is null then null
    else extensions.ST_AsGeoJSON(o.location)::jsonb
  end as geojson,
  a.technician_id,
  p.full_name as technician_name,
  a.assigned_at
from public.work_orders o
left join public.work_order_assignments a
  on a.work_order_id = o.id
 and a.unassigned_at is null
left join public.profiles p
  on p.id = a.technician_id;

comment on view public.v_work_orders_map is
  'Órdenes con lat/lng, GeoJSON y técnico vigente para el visor GIS. Respeta RLS.';

create or replace view public.v_technician_workload
with (security_invoker = true)
as
select
  p.id as technician_id,
  p.full_name,
  td.employee_code,
  td.current_location,
  td.location_updated_at,
  count(a.id) filter (
    where a.unassigned_at is null
      and o.status in ('asignada', 'en_proceso')
  ) as active_orders,
  count(a.id) filter (
    where a.unassigned_at is null
      and o.status = 'asignada'
  ) as assigned_orders,
  count(a.id) filter (
    where a.unassigned_at is null
      and o.status = 'en_proceso'
  ) as in_progress_orders
from public.profiles p
join public.technician_details td on td.profile_id = p.id
left join public.work_order_assignments a on a.technician_id = p.id
left join public.work_orders o on o.id = a.work_order_id
where p.role = 'tecnico'
  and p.is_active
group by p.id, p.full_name, td.employee_code, td.current_location, td.location_updated_at;

comment on view public.v_technician_workload is
  'Carga vigente por técnico (asignadas/en proceso) y última ubicación conocida. Respeta RLS.';

revoke all on public.v_work_orders_map from anon, authenticated;
revoke all on public.v_technician_workload from anon, authenticated;

grant select on public.v_work_orders_map to authenticated, service_role;
grant select on public.v_technician_workload to authenticated, service_role;
