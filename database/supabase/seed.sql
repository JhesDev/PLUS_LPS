-- PLUS_LPS :: seed de desarrollo
-- Datos 100% ficticios para probar mapa, asignaciones, rutas y RLS.
-- Se ejecuta con `supabase db reset` (config.toml -> db.seed.sql_paths).
-- Los usuarios demo NO tienen contraseña conocida: se genera una aleatoria por
-- ejecución para no incorporar credenciales al repositorio. Para probar login,
-- usa el Admin API/Studio local y define una contraseña manualmente.
-- Diseñado para base local recién reseteada (no borra datos de producción).

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- Usuarios de Auth (ficticios, dominio .test)
-- ---------------------------------------------------------------------------

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values
  (
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'coordinador.demo@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"coordinador"}'::jsonb,
    '{"full_name":"Coordinador Demo"}'::jsonb,
    now(), now()
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'despachador.demo@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"despachador"}'::jsonb,
    '{"full_name":"Despachador Demo"}'::jsonb,
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333331',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.uno@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Uno"}'::jsonb,
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333332',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.dos@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Dos"}'::jsonb,
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333333',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.tres@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Tres"}'::jsonb,
    now(), now()
  )
on conflict (id) do nothing;

-- Identidades de email (sin contraseña útil: encrypted_password es aleatorio).
insert into auth.identities (
  provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
select
  u.id::text,
  u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email',
  now(), now(), now()
from auth.users u
where u.email like '%@plus-lps.test'
on conflict do nothing;

-- Perfiles: el trigger on_auth_user_created ya los creó; se fijan nombres/roles.
insert into public.profiles (id, role, full_name, phone, is_active)
values
  ('11111111-1111-4111-8111-111111111111', 'coordinador', 'Coordinador Demo', '+51 900 000 001', true),
  ('22222222-2222-4222-8222-222222222222', 'despachador', 'Despachador Demo', '+51 900 000 002', true),
  ('33333333-3333-4333-8333-333333333331', 'tecnico', 'Técnico Demo Uno', '+51 900 000 011', true),
  ('33333333-3333-4333-8333-333333333332', 'tecnico', 'Técnico Demo Dos', '+51 900 000 012', true),
  ('33333333-3333-4333-8333-333333333333', 'tecnico', 'Técnico Demo Tres', '+51 900 000 013', true)
on conflict (id) do update
  set role = excluded.role,
      full_name = excluded.full_name,
      phone = excluded.phone,
      is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Datos operativos de técnicos
-- ---------------------------------------------------------------------------

insert into public.technician_details (
  profile_id, employee_code, vehicle_label, max_daily_orders,
  current_location, location_updated_at, notes
)
values
  (
    '33333333-3333-4333-8333-333333333331', 'TEC-001', 'Moto Demo A', 12,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0300, -12.1200), 4326),
    now() - interval '10 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333332', 'TEC-002', 'Camioneta Demo B', 8,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0400, -12.0900), 4326),
    now() - interval '25 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333333', 'TEC-003', 'Moto Demo C', 10,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1450), 4326),
    now() - interval '1 day', 'Cuadrilla ficticia de prueba'
  )
on conflict (profile_id) do update
  set employee_code = excluded.employee_code,
      vehicle_label = excluded.vehicle_label,
      max_daily_orders = excluded.max_daily_orders,
      current_location = excluded.current_location,
      location_updated_at = excluded.location_updated_at,
      notes = excluded.notes;

-- ---------------------------------------------------------------------------
-- Órdenes de trabajo (Lima, ficticias)
-- ---------------------------------------------------------------------------

insert into public.work_orders (
  id, code, external_source, external_id, type, status, priority,
  customer_name, supply_number, address, district, zone, location,
  scheduled_at, due_at, notes, cancellation_reason, completed_at,
  created_by, updated_by
)
values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000001', 'WO-2026-0001', 'sap', 'DEMO-EXT-0001',
    'corte', 'pendiente', 2,
    'Cliente Ficticio 01', 'SUM-000001', 'Av. Demo 100, Miraflores', 'Miraflores', 'Zona Costa Verde',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0297, -12.1219), 4326),
    date_trunc('day', now()) + interval '9 hours',
    date_trunc('day', now()) + interval '18 hours',
    'Orden ficticia para pruebas de mapa.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000002', 'WO-2026-0002', null, null,
    'reposicion', 'pendiente', 3,
    'Cliente Ficticio 02', 'SUM-000002', 'Calle Demo 201, San Isidro', 'San Isidro', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0365, -12.0972), 4326),
    date_trunc('day', now()) + interval '10 hours',
    date_trunc('day', now()) + interval '19 hours',
    'Orden ficticia para pruebas de asignación.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000003', 'WO-2026-0003', null, null,
    'inspeccion', 'pendiente', 4,
    'Cliente Ficticio 03', 'SUM-000003', 'Av. Demo 302, Santiago de Surco', 'Santiago de Surco', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9950, -12.1450), 4326),
    date_trunc('day', now()) + interval '11 hours',
    date_trunc('day', now()) + interval '20 hours',
    'Inspección ficticia.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000004', 'WO-2026-0004', null, null,
    'reconexion', 'pendiente', 5,
    'Cliente Ficticio 04', 'SUM-000004', 'Jr. Demo 403, La Victoria', 'La Victoria', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0250, -12.0650), 4326),
    date_trunc('day', now()) + interval '12 hours',
    date_trunc('day', now()) + interval '21 hours',
    'Reconexión ficticia.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 'WO-2026-0005', null, null,
    'corte', 'asignada', 1,
    'Cliente Ficticio 05', 'SUM-000005', 'Av. Demo 504, Callao', 'Callao', 'Zona Callao',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.1181, -12.0566), 4326),
    date_trunc('day', now()) + interval '8 hours',
    date_trunc('day', now()) + interval '14 hours',
    'Corte ficticio prioritario.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000006', 'WO-2026-0006', null, null,
    'mantenimiento', 'asignada', 3,
    'Cliente Ficticio 06', 'SUM-000006', 'Calle Demo 605, San Miguel', 'San Miguel', 'Zona Costa Verde',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0830, -12.0770), 4326),
    date_trunc('day', now()) + interval '13 hours',
    date_trunc('day', now()) + interval '20 hours',
    'Mantenimiento ficticio.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'WO-2026-0007', null, null,
    'reposicion', 'en_proceso', 2,
    'Cliente Ficticio 07', 'SUM-000007', 'Av. Demo 706, Jesús María', 'Jesús María', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0450, -12.0740), 4326),
    date_trunc('day', now()) + interval '8 hours',
    date_trunc('day', now()) + interval '16 hours',
    'Reposición ficticia en curso.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000008', 'WO-2026-0008', null, null,
    'corte', 'en_proceso', 1,
    'Cliente Ficticio 08', 'SUM-000008', 'Jr. Demo 808, Lince', 'Lince', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0350, -12.0850), 4326),
    date_trunc('day', now()) + interval '9 hours',
    date_trunc('day', now()) + interval '17 hours',
    'Corte ficticio en curso.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', null, null,
    'inspeccion', 'ejecutada', 3,
    'Cliente Ficticio 09', 'SUM-000009', 'Av. Demo 909, Barranco', 'Barranco', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1470), 4326),
    now() - interval '1 day',
    now() - interval '20 hours',
    'Inspección ficticia finalizada.', null, now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', null, null,
    'reconexion', 'imposibilitada', 4,
    'Cliente Ficticio 10', 'SUM-000010', 'Calle Demo 1010, Ate', 'Ate', 'Zona Este',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9200, -12.0260), 4326),
    now() - interval '1 day',
    now() - interval '18 hours',
    'Reconexión ficticia imposibilitada.', null, now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000011', 'WO-2026-0011', null, null,
    'corte', 'cancelada', 5,
    'Cliente Ficticio 11', 'SUM-000011', 'Av. Demo 1111, Surquillo', 'Surquillo', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1130), 4326),
    date_trunc('day', now()) + interval '15 hours',
    date_trunc('day', now()) + interval '23 hours',
    'Orden ficticia cancelada.', 'Duplicado de demostración', null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000012', 'WO-2026-0012', null, null,
    'mantenimiento', 'pendiente', 3,
    'Cliente Ficticio 12', 'SUM-000012', 'Calle Demo 1212, Pueblo Libre', 'Pueblo Libre', 'Zona Centro',
    null,
    date_trunc('day', now()) + interval '16 hours',
    date_trunc('day', now()) + interval '23 hours',
    'Orden ficticia SIN geocodificar (location NULL).', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Asignaciones (4 vigentes + 2 cerradas)
-- ---------------------------------------------------------------------------

insert into public.work_order_assignments (
  id, work_order_id, technician_id, assigned_by, assigned_at,
  unassigned_at, unassigned_by, end_reason, notes
)
values
  (
    'cccccccc-cccc-4ccc-8ccc-000000000005',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
    '33333333-3333-4333-8333-333333333331',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '3 hours',
    null, null, null, 'Asignación ficticia vigente'
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-000000000006',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000006',
    '33333333-3333-4333-8333-333333333332',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '3 hours',
    null, null, null, 'Asignación ficticia vigente'
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-000000000007',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
    '33333333-3333-4333-8333-333333333331',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '5 hours',
    null, null, null, 'Asignación ficticia vigente'
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-000000000008',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000008',
    '33333333-3333-4333-8333-333333333332',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '4 hours',
    null, null, null, 'Asignación ficticia vigente'
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-000000000009',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '2 days',
    now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222',
    'completada', 'Asignación ficticia cerrada'
  ),
  (
    'cccccccc-cccc-4ccc-8ccc-000000000010',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '2 days',
    now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222',
    'imposibilitada', 'Asignación ficticia cerrada'
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Rutas y paradas
-- ---------------------------------------------------------------------------

insert into public.routes (
  id, code, technician_id, route_date, status, started_at, completed_at, notes, created_by
)
values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000001', 'RUTA-2026-0001',
    '33333333-3333-4333-8333-333333333331', current_date, 'en_curso',
    now() - interval '1 hour', null, 'Ruta ficticia en curso', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000002', 'RUTA-2026-0002',
    '33333333-3333-4333-8333-333333333332', current_date, 'planificada',
    null, null, 'Ruta ficticia planificada', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000003', 'RUTA-2026-0003',
    '33333333-3333-4333-8333-333333333333', current_date - 1, 'completada',
    now() - interval '1 day 8 hours', now() - interval '1 day 1 hour',
    'Ruta ficticia histórica', '22222222-2222-4222-8222-222222222222'
  )
on conflict (id) do nothing;

insert into public.route_stops (
  id, route_id, work_order_id, stop_order, status, planned_at, arrived_at, completed_at, notes
)
values
  (
    'dddddddd-dddd-4ddd-8ddd-000000000001',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 1, 'pendiente',
    date_trunc('day', now()) + interval '9 hours', null, null, 'Parada ficticia 1'
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-000000000002',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 2, 'en_proceso',
    date_trunc('day', now()) + interval '11 hours', now() - interval '30 minutes', null, 'Parada ficticia 2'
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-000000000003',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000006', 1, 'pendiente',
    date_trunc('day', now()) + interval '13 hours', null, null, 'Parada ficticia 3'
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-000000000004',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000008', 2, 'pendiente',
    date_trunc('day', now()) + interval '15 hours', null, null, 'Parada ficticia 4'
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-000000000005',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000003',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 1, 'completada',
    now() - interval '1 day 8 hours', now() - interval '1 day 7 hours',
    now() - interval '1 day 6 hours', 'Parada ficticia 5'
  ),
  (
    'dddddddd-dddd-4ddd-8ddd-000000000006',
    'bbbbbbbb-bbbb-4bbb-8bbb-000000000003',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 2, 'omitida',
    now() - interval '1 day 6 hours', now() - interval '1 day 5 hours',
    now() - interval '1 day 5 hours', 'Parada ficticia 6'
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Historial de estados (demostración de auditoría)
-- ---------------------------------------------------------------------------

insert into public.work_order_status_history (
  work_order_id, from_status, to_status, changed_by, changed_at, reason
)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 'pendiente', 'asignada',
   '22222222-2222-4222-8222-222222222222', now() - interval '3 hours', 'Asignación ficticia'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'pendiente', 'asignada',
   '22222222-2222-4222-8222-222222222222', now() - interval '5 hours', 'Asignación ficticia'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'asignada', 'en_proceso',
   '33333333-3333-4333-8333-333333333331', now() - interval '1 hour', 'Inicio ficticio de trabajo'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'pendiente', 'asignada',
   '22222222-2222-4222-8222-222222222222', now() - interval '2 days', 'Asignación ficticia'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'asignada', 'en_proceso',
   '33333333-3333-4333-8333-333333333333', now() - interval '1 day 4 hours', 'Inicio ficticio'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'en_proceso', 'ejecutada',
   '33333333-3333-4333-8333-333333333333', now() - interval '1 day', 'Trabajo ficticio ejecutado'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'pendiente', 'asignada',
   '22222222-2222-4222-8222-222222222222', now() - interval '2 days', 'Asignación ficticia'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'asignada', 'en_proceso',
   '33333333-3333-4333-8333-333333333333', now() - interval '1 day 4 hours', 'Inicio ficticio'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'en_proceso', 'imposibilitada',
   '33333333-3333-4333-8333-333333333333', now() - interval '1 day', 'Acceso ficticio bloqueado'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-000000000011', 'pendiente', 'cancelada',
   '22222222-2222-4222-8222-222222222222', now() - interval '6 hours', 'Duplicado ficticio');

-- ---------------------------------------------------------------------------
-- Evidencias (solo metadatos; los binarios NO existen en este seed)
-- ---------------------------------------------------------------------------

insert into public.work_order_evidence (
  id, work_order_id, assignment_id, kind, storage_bucket, storage_path,
  mime_type, size_bytes, captured_at, location, uploaded_by, metadata
)
values
  (
    'ffffffff-ffff-4fff-8fff-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
    'cccccccc-cccc-4ccc-8ccc-000000000009',
    'despues', 'work-order-evidence',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009/despues-1.jpg',
    'image/jpeg', 204800, now() - interval '1 day',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1470), 4326),
    '33333333-3333-4333-8333-333333333333',
    '{"demo": true}'::jsonb
  ),
  (
    'ffffffff-ffff-4fff-8fff-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
    'cccccccc-cccc-4ccc-8ccc-000000000009',
    'firma', 'work-order-evidence',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009/firma.png',
    'image/png', 51200, now() - interval '1 day',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1470), 4326),
    '33333333-3333-4333-8333-333333333333',
    '{"demo": true}'::jsonb
  ),
  (
    'ffffffff-ffff-4fff-8fff-000000000003',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
    'cccccccc-cccc-4ccc-8ccc-000000000010',
    'antes', 'work-order-evidence',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010/antes-1.jpg',
    'image/jpeg', 102400, now() - interval '1 day 4 hours',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9200, -12.0260), 4326),
    '33333333-3333-4333-8333-333333333333',
    '{"demo": true}'::jsonb
  );

-- ---------------------------------------------------------------------------
-- Staging de ingesta (payload genérico: el contrato SAP NO está definido)
-- ---------------------------------------------------------------------------

insert into ingest.batches (
  id, source, received_at, payload_hash, status, records_count, notes
)
values (
  'eeeeeeee-eeee-4eee-8eee-000000000001',
  'sap',
  now() - interval '2 hours',
  'demo-batch-hash-1',
  'procesado',
  2,
  'Lote ficticio de demostración. Reemplazar por el contrato real de SAP.'
)
on conflict (id) do nothing;

insert into ingest.records (
  id, batch_id, source, entity, external_id, payload, payload_hash,
  status, work_order_id, error_message, processed_at
)
values
  (
    '99999999-9999-4999-8999-000000000001',
    'eeeeeeee-eeee-4eee-8eee-000000000001',
    'sap', 'work_order', 'DEMO-EXT-0001',
    '{"demo": true, "note": "payload ficticio; contrato SAP pendiente"}'::jsonb,
    'demo-record-hash-1',
    'procesado',
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000001',
    null,
    now() - interval '1 hour'
  ),
  (
    '99999999-9999-4999-8999-000000000002',
    'eeeeeeee-eeee-4eee-8eee-000000000001',
    'sap', 'work_order', 'DEMO-EXT-0002',
    '{"demo": true, "note": "registro ficticio no normalizado"}'::jsonb,
    'demo-record-hash-2',
    'error',
    null,
    'Demostración: contrato SAP no definido; no se normaliza.',
    now() - interval '1 hour'
  )
on conflict (id) do nothing;
