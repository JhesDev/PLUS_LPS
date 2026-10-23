-- PLUS_LPS :: seed de desarrollo (fase alpha)
--
-- Datos 100% ficticios para probar mapa, filtros, jornada, evidencias y RLS.
-- Se ejecuta con `supabase db reset` (config.toml -> db.seed.sql_paths).
--
-- Advertencias:
--   * NO hay contrato SAP/PLUZ: los identificadores externos y los payloads de
--     `ingest` son ficticios y no representan un contrato real.
--   * Las coordenadas son FICTICIAS de prueba: se derivan de centros urbanos
--     aproximados de cada distrito con un desplazamiento determinista acotado
--     hacia el este (tierra adentro). No hubo geocodificación real.
--   * Los usuarios demo NO traen contraseña utilizable. Para poder iniciar
--     sesión usa `scripts/create-demo-accounts.ps1` (lee las claves locales del
--     CLI en tiempo de ejecución y no guarda secretos en el repositorio).
--   * Las evidencias son SOLO metadatos: los binarios no existen en Storage.
--
-- Repetible: todos los identificadores son deterministas y las inserciones están
-- protegidas con `on conflict`/guardas, por lo que volver a ejecutarlo no duplica.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 1. Usuarios de Auth (ficticios, dominio .test)
-- ---------------------------------------------------------------------------
-- GoTrue escanea los columnas *_token como `string`; si quedan NULL, el login y
-- el Admin API fallan con "converting NULL to string is unsupported".
-- Por eso se insertan como cadena vacía, igual que hace GoTrue.

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new,
  email_change_token_current, email_change, phone_change,
  phone_change_token, reauthentication_token,
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
    '', '', '', '', '', '', '', '',
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
    '', '', '', '', '', '', '', '',
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
    '', '', '', '', '', '', '', '',
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
    '', '', '', '', '', '', '', '',
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
    '', '', '', '', '', '', '', '',
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333334',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.cuatro@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Cuatro"}'::jsonb,
    '', '', '', '', '', '', '', '',
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333335',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.cinco@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Cinco"}'::jsonb,
    '', '', '', '', '', '', '', '',
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333336',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.seis@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Seis"}'::jsonb,
    '', '', '', '', '', '', '', '',
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333337',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.siete@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Siete"}'::jsonb,
    '', '', '', '', '', '', '', '',
    now(), now()
  ),
  (
    '33333333-3333-4333-8333-333333333338',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    'tecnico.ocho@plus-lps.test',
    extensions.crypt(extensions.gen_random_uuid()::text, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"],"role":"tecnico"}'::jsonb,
    '{"full_name":"Técnico Demo Ocho"}'::jsonb,
    '', '', '', '', '', '', '', '',
    now(), now()
  )
on conflict (id) do nothing;

-- Identidades de email (sin contraseña útil: encrypted_password es aleatorio).
-- El `id` es generado, por lo que el objetivo de conflicto real es
-- (provider_id, provider); se usa `do nothing` sin objetivo para cubrir ambos.
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

-- ---------------------------------------------------------------------------
-- 2. Perfiles
-- ---------------------------------------------------------------------------
-- El trigger on_auth_user_created ya creó las filas; aquí se fijan nombre y rol.

insert into public.profiles (id, role, full_name, phone, is_active)
values
  ('11111111-1111-4111-8111-111111111111', 'coordinador', 'Coordinador Demo', '+51 900 000 001', true),
  ('22222222-2222-4222-8222-222222222222', 'despachador', 'Despachador Demo', '+51 900 000 002', true),
  ('33333333-3333-4333-8333-333333333331', 'tecnico', 'Técnico Demo Uno', '+51 900 000 011', true),
  ('33333333-3333-4333-8333-333333333332', 'tecnico', 'Técnico Demo Dos', '+51 900 000 012', true),
  ('33333333-3333-4333-8333-333333333333', 'tecnico', 'Técnico Demo Tres', '+51 900 000 013', true),
  ('33333333-3333-4333-8333-333333333334', 'tecnico', 'Técnico Demo Cuatro', '+51 900 000 014', true),
  ('33333333-3333-4333-8333-333333333335', 'tecnico', 'Técnico Demo Cinco', '+51 900 000 015', true),
  ('33333333-3333-4333-8333-333333333336', 'tecnico', 'Técnico Demo Seis', '+51 900 000 016', true),
  ('33333333-3333-4333-8333-333333333337', 'tecnico', 'Técnico Demo Siete', '+51 900 000 017', true),
  ('33333333-3333-4333-8333-333333333338', 'tecnico', 'Técnico Demo Ocho', '+51 900 000 018', true)
on conflict (id) do update
  set role = excluded.role,
      full_name = excluded.full_name,
      phone = excluded.phone,
      is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- 3. Datos operativos de técnicos
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
    now() - interval '40 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333334', 'TEC-004', 'Camión Demo D', 14,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0500, -12.0464), 4326),
    now() - interval '15 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333335', 'TEC-005', 'Moto Demo E', 10,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9950, -11.9950), 4326),
    now() - interval '30 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333336', 'TEC-006', 'Camioneta Demo F', 12,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0700, -11.9750), 4326),
    now() - interval '20 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333337', 'TEC-007', 'Moto Demo G', 10,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.1181, -12.0566), 4326),
    now() - interval '5 minutes', 'Cuadrilla ficticia de prueba'
  ),
  (
    '33333333-3333-4333-8333-333333333338', 'TEC-008', 'Camión Demo H', 14,
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9700, -12.1600), 4326),
    now() - interval '45 minutes', 'Cuadrilla ficticia de prueba'
  )
on conflict (profile_id) do update
  set employee_code = excluded.employee_code,
      vehicle_label = excluded.vehicle_label,
      max_daily_orders = excluded.max_daily_orders,
      current_location = excluded.current_location,
      location_updated_at = excluded.location_updated_at,
      notes = excluded.notes;

-- ---------------------------------------------------------------------------
-- 4. Catálogo de distritos de referencia (SOLO para el seed)
-- ---------------------------------------------------------------------------
-- Centros urbanos aproximados de Lima Metropolitana y Callao. Se usan como base
-- y luego el generador aplica un desplazamiento determinista acotado hacia el
-- este (tierra adentro) para no caer en el mar.

create temporary table if not exists _seed_district (
  idx  integer primary key,
  name text not null,
  zone text not null,
  lon  double precision not null,
  lat  double precision not null
);
truncate _seed_district;

insert into _seed_district (idx, name, zone, lon, lat) values
  (1,  'Comas',                     'Zona Norte',  -77.0480, -11.9380),
  (2,  'Independencia',             'Zona Norte',  -77.0530, -11.9900),
  (3,  'Los Olivos',                'Zona Norte',  -77.0700, -11.9750),
  (4,  'San Martín de Porres',      'Zona Norte',  -77.0800, -12.0100),
  (5,  'Puente Piedra',             'Zona Norte',  -77.0900, -11.8650),
  (6,  'Rímac',                     'Zona Norte',  -77.0280, -12.0300),
  (7,  'Carabayllo',                'Zona Norte',  -77.0300, -11.8900),
  (8,  'Ventanilla',                'Zona Callao', -77.1300, -11.8700),
  (9,  'San Juan de Lurigancho',    'Zona Este',   -76.9950, -11.9950),
  (10, 'El Agustino',               'Zona Este',   -76.9950, -12.0450),
  (11, 'Santa Anita',               'Zona Este',   -76.9700, -12.0400),
  (12, 'Ate',                       'Zona Este',   -76.9200, -12.0260),
  (13, 'La Molina',                 'Zona Este',   -76.9400, -12.0700),
  (14, 'Lurigancho',                'Zona Este',   -76.7000, -11.9400),
  (15, 'Mi Perú',                   'Zona Callao', -77.1200, -11.8500),
  (16, 'Cercado de Lima',           'Zona Centro', -77.0428, -12.0464),
  (17, 'Breña',                     'Zona Centro', -77.0500, -12.0600),
  (18, 'La Victoria',               'Zona Centro', -77.0200, -12.0700),
  (19, 'Lince',                     'Zona Centro', -77.0350, -12.0850),
  (20, 'Jesús María',               'Zona Centro', -77.0450, -12.0740),
  (21, 'Magdalena del Mar',         'Zona Centro', -77.0700, -12.0900),
  (22, 'Pueblo Libre',              'Zona Centro', -77.0650, -12.0700),
  (23, 'San Miguel',                'Zona Centro', -77.0900, -12.0770),
  (24, 'Surquillo',                 'Zona Sur',    -77.0200, -12.1130),
  (25, 'San Borja',                 'Zona Centro', -77.0000, -12.1000),
  (26, 'Santiago de Surco',         'Zona Sur',    -76.9950, -12.1450),
  (27, 'San Isidro',                'Zona Centro', -77.0365, -12.0972),
  (28, 'Miraflores',                'Zona Centro', -77.0300, -12.1200),
  (29, 'Barranco',                  'Zona Sur',    -77.0200, -12.1470),
  (30, 'Chorrillos',                'Zona Sur',    -77.0200, -12.1800),
  (31, 'San Juan de Miraflores',    'Zona Sur',    -76.9700, -12.1600),
  (32, 'Villa María del Triunfo',   'Zona Sur',    -76.9400, -12.1700),
  (33, 'Villa El Salvador',         'Zona Sur',    -76.9800, -12.2100),
  (34, 'Lurín',                     'Zona Sur',    -76.8700, -12.2700),
  (35, 'Pachacámac',                'Zona Sur',    -76.8700, -12.2300),
  (36, 'Callao',                    'Zona Callao', -77.1181, -12.0566),
  (37, 'Bellavista',                'Zona Callao', -77.1250, -12.0620),
  (38, 'La Perla',                  'Zona Callao', -77.1300, -12.0700),
  (39, 'Carmen de la Legua-Reynoso', 'Zona Callao', -77.1000, -12.0500),
  (40, 'La Punta',                  'Zona Callao', -77.1280, -12.0720);

-- ---------------------------------------------------------------------------
-- 5. Órdenes de muestra (escenarios concretos, IDs legibles)
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
    'Cliente Ficticio 0001', 'SUM-000001', 'Av. Demo 100, Miraflores', 'Miraflores', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0297, -12.1219), 4326),
    date_trunc('day', now()) + interval '9 hours',
    date_trunc('day', now()) + interval '18 hours',
    'Orden ficticia para pruebas de mapa.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000002', 'WO-2026-0002', null, null,
    'reposicion', 'pendiente', 3,
    'Cliente Ficticio 0002', 'SUM-000002', 'Calle Demo 201, San Isidro', 'San Isidro', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0365, -12.0972), 4326),
    date_trunc('day', now()) + interval '10 hours',
    date_trunc('day', now()) + interval '19 hours',
    'Orden ficticia para pruebas de asignación.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000003', 'WO-2026-0003', null, null,
    'inspeccion', 'pendiente', 4,
    'Cliente Ficticio 0003', 'SUM-000003', 'Av. Demo 302, Santiago de Surco', 'Santiago de Surco', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9950, -12.1450), 4326),
    date_trunc('day', now()) + interval '11 hours',
    date_trunc('day', now()) + interval '20 hours',
    'Inspección ficticia.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000004', 'WO-2026-0004', null, null,
    'reconexion', 'pendiente', 5,
    'Cliente Ficticio 0004', 'SUM-000004', 'Jr. Demo 403, La Victoria', 'La Victoria', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0250, -12.0650), 4326),
    date_trunc('day', now()) + interval '12 hours',
    date_trunc('day', now()) + interval '21 hours',
    'Reconexión ficticia.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 'WO-2026-0005', null, null,
    'corte', 'asignada', 1,
    'Cliente Ficticio 0005', 'SUM-000005', 'Av. Demo 504, Callao', 'Callao', 'Zona Callao',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.1181, -12.0566), 4326),
    date_trunc('day', now()) + interval '8 hours',
    date_trunc('day', now()) + interval '14 hours',
    'Corte ficticio prioritario.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000006', 'WO-2026-0006', null, null,
    'mantenimiento', 'asignada', 3,
    'Cliente Ficticio 0006', 'SUM-000006', 'Calle Demo 605, San Miguel', 'San Miguel', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0830, -12.0770), 4326),
    date_trunc('day', now()) + interval '13 hours',
    date_trunc('day', now()) + interval '20 hours',
    'Mantenimiento ficticio.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'WO-2026-0007', null, null,
    'reposicion', 'en_proceso', 2,
    'Cliente Ficticio 0007', 'SUM-000007', 'Av. Demo 706, Jesús María', 'Jesús María', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0450, -12.0740), 4326),
    date_trunc('day', now()) + interval '8 hours',
    date_trunc('day', now()) + interval '16 hours',
    'Reposición ficticia en curso.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000008', 'WO-2026-0008', null, null,
    'corte', 'en_proceso', 1,
    'Cliente Ficticio 0008', 'SUM-000008', 'Jr. Demo 808, Lince', 'Lince', 'Zona Centro',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0350, -12.0850), 4326),
    date_trunc('day', now()) + interval '9 hours',
    date_trunc('day', now()) + interval '17 hours',
    'Corte ficticio en curso.', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', null, null,
    'inspeccion', 'ejecutada', 3,
    'Cliente Ficticio 0009', 'SUM-000009', 'Av. Demo 909, Barranco', 'Barranco', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1470), 4326),
    now() - interval '1 day',
    now() - interval '20 hours',
    'Inspección ficticia finalizada.', null, now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', null, null,
    'reconexion', 'imposibilitada', 4,
    'Cliente Ficticio 0010', 'SUM-000010', 'Calle Demo 1010, Ate', 'Ate', 'Zona Este',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-76.9200, -12.0260), 4326),
    now() - interval '1 day',
    now() - interval '18 hours',
    'Reconexión ficticia imposibilitada.', null, now() - interval '1 day',
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000011', 'WO-2026-0011', null, null,
    'corte', 'cancelada', 5,
    'Cliente Ficticio 0011', 'SUM-000011', 'Av. Demo 1111, Surquillo', 'Surquillo', 'Zona Sur',
    extensions.ST_SetSRID(extensions.ST_MakePoint(-77.0200, -12.1130), 4326),
    date_trunc('day', now()) + interval '15 hours',
    date_trunc('day', now()) + interval '23 hours',
    'Orden ficticia cancelada.', 'Duplicado de demostración', null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-000000000012', 'WO-2026-0012', null, null,
    'mantenimiento', 'pendiente', 3,
    'Cliente Ficticio 0012', 'SUM-000012', 'Calle Demo 1212, Pueblo Libre', 'Pueblo Libre', 'Zona Centro',
    null,
    date_trunc('day', now()) + interval '16 hours',
    date_trunc('day', now()) + interval '23 hours',
    'Orden ficticia SIN geocodificar (location NULL).', null, null,
    '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222'
  )
on conflict (id) do nothing;

-- Asignaciones de los casos de muestra (4 vigentes + 2 cerradas).
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

-- Historial de estados de los casos de muestra.
-- Se inserta desde un CTE con guarda NOT EXISTS para poder re-ejecutar el seed
-- sin duplicar auditoría.
with data (work_order_id, from_status, to_status, changed_by, changed_at, reason) as (
  values
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000005'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '3 hours', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000006'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '3 hours', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000007'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '5 hours', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000007'::uuid, 'asignada', 'en_proceso',
     '33333333-3333-4333-8333-333333333331'::uuid, now() - interval '1 hour', 'Inicio ficticio de trabajo'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000008'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '4 hours', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000008'::uuid, 'asignada', 'en_proceso',
     '33333333-3333-4333-8333-333333333332'::uuid, now() - interval '2 hours', 'Inicio ficticio de trabajo'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '2 days', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009'::uuid, 'asignada', 'en_proceso',
     '33333333-3333-4333-8333-333333333333'::uuid, now() - interval '1 day 4 hours', 'Inicio ficticio'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009'::uuid, 'en_proceso', 'ejecutada',
     '33333333-3333-4333-8333-333333333333'::uuid, now() - interval '1 day', 'Trabajo ficticio ejecutado'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010'::uuid, 'pendiente', 'asignada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '2 days', 'Asignación ficticia'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010'::uuid, 'asignada', 'en_proceso',
     '33333333-3333-4333-8333-333333333333'::uuid, now() - interval '1 day 4 hours', 'Inicio ficticio'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010'::uuid, 'en_proceso', 'imposibilitada',
     '33333333-3333-4333-8333-333333333333'::uuid, now() - interval '1 day', 'Acceso ficticio bloqueado'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000011'::uuid, 'pendiente', 'cancelada',
     '22222222-2222-4222-8222-222222222222'::uuid, now() - interval '6 hours', 'Duplicado ficticio')
)
insert into public.work_order_status_history (
  work_order_id, from_status, to_status, changed_by, changed_at, reason
)
select
  d.work_order_id,
  d.from_status::public.work_order_status,
  d.to_status::public.work_order_status,
  d.changed_by,
  d.changed_at,
  d.reason
from data d
where not exists (
  select 1
    from public.work_order_status_history h
   where h.work_order_id = d.work_order_id
     and h.to_status = d.to_status::public.work_order_status
     and h.reason = d.reason
);

-- Evidencias de muestra (solo metadatos; los binarios NO existen en este seed).
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
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 6. Generador determinista de volumen
-- ---------------------------------------------------------------------------
-- Rango 101..700 -> 600 órdenes generadas. Sumadas a las 12 de muestra el total
-- es 612. El estado, tipo, prioridad, distrito y desplazamiento espacial derivan
-- de md5(i) con semillas distintas, por lo que son reproducibles y no aleatorios
-- sin control. i % 17 = 0 deja la orden SIN coordenadas (caso a tolerar).

do $$
declare
  v_despachador uuid := '22222222-2222-4222-8222-222222222222';
  v_tecnicos uuid[];
  v_total_tecnicos integer;
  v_i integer;
  v_hash integer;
  v_order_id uuid;
  v_status public.work_order_status;
  v_type public.work_order_type;
  v_priority smallint;
  v_district text;
  v_zone text;
  v_lon double precision;
  v_lat double precision;
  v_location extensions.geometry(Point, 4326);
  v_scheduled timestamptz;
  v_completed timestamptz;
  v_hist_at timestamptz;
  v_tech uuid;
  v_assignment_id uuid;
begin
  select array_agg(p.id order by td.employee_code)
    into v_tecnicos
    from public.profiles p
    join public.technician_details td on td.profile_id = p.id
   where p.role = 'tecnico'
     and p.is_active;

  v_total_tecnicos := coalesce(array_length(v_tecnicos, 1), 0);

  if v_total_tecnicos = 0 then
    raise exception 'El seed necesita técnicos activos antes de generar órdenes';
  end if;

  for v_i in 101..700 loop
    v_order_id := ('aaaaaaaa-aaaa-4aaa-8aaa-' || lpad(to_hex(v_i)::text, 12, '0'))::uuid;

    continue when exists (
      select 1 from public.work_orders where id = v_order_id
    );

    -- Estado: 30% pendiente, 20% asignada, 20% en_proceso, 20% ejecutada,
    -- 6% imposibilitada, 4% cancelada.
    v_hash := ('x' || substr(md5('st:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
    v_status := (case
      when v_hash % 100 < 30 then 'pendiente'
      when v_hash % 100 < 50 then 'asignada'
      when v_hash % 100 < 70 then 'en_proceso'
      when v_hash % 100 < 90 then 'ejecutada'
      when v_hash % 100 < 96 then 'imposibilitada'
      else 'cancelada'
    end)::public.work_order_status;

    v_hash := ('x' || substr(md5('ty:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
    v_type := (case v_hash % 16
      when 0 then 'corte'
      when 1 then 'corte'
      when 2 then 'corte'
      when 3 then 'corte'
      when 4 then 'reposicion'
      when 5 then 'reposicion'
      when 6 then 'reposicion'
      when 7 then 'inspeccion'
      when 8 then 'inspeccion'
      when 9 then 'inspeccion'
      when 10 then 'reconexion'
      when 11 then 'reconexion'
      when 12 then 'mantenimiento'
      when 13 then 'mantenimiento'
      when 14 then 'mantenimiento'
      else 'otro'
    end)::public.work_order_type;

    v_hash := ('x' || substr(md5('pr:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
    v_priority := (case
      when v_hash % 10 < 2 then 1
      when v_hash % 10 < 5 then 2
      when v_hash % 10 < 8 then 3
      when v_hash % 10 = 8 then 4
      else 5
    end)::smallint;

    v_hash := ('x' || substr(md5('di:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
    select d.name, d.zone, d.lon, d.lat
      into v_district, v_zone, v_lon, v_lat
      from pg_temp._seed_district d
     where d.idx = (v_hash % 40) + 1;

    -- Desplazamiento acotado: hasta ~670 m al norte/sur y hasta ~780 m al este.
    if v_i % 17 <> 0 then
      v_hash := ('x' || substr(md5('la:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
      v_lat := round((v_lat + ((v_hash % 1201) - 600) / 100000.0)::numeric, 6)::double precision;

      v_hash := ('x' || substr(md5('lo:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
      v_lon := round((v_lon + (v_hash % 701) / 100000.0)::numeric, 6)::double precision;

      v_location := extensions.ST_SetSRID(extensions.ST_MakePoint(v_lon, v_lat), 4326);
    else
      v_location := null;
    end if;

    if v_status in ('ejecutada', 'imposibilitada') then
      v_scheduled := date_trunc('day', now())
                     - ((v_i % 6) + 1) * interval '1 day'
                     + make_interval(hours => 8 + (v_i % 9));
      v_completed := v_scheduled + interval '3 hours' + ((v_i % 7) * interval '20 minutes');
    else
      v_scheduled := date_trunc('day', now())
                     + ((v_i % 5) - 2) * interval '1 day'
                     + make_interval(hours => 8 + (v_i % 9));
      v_completed := null;
    end if;

    insert into public.work_orders (
      id, code, external_source, external_id, type, status, priority,
      customer_name, supply_number, address, district, zone, location,
      scheduled_at, due_at, notes, cancellation_reason, completed_at,
      created_by, updated_by
    )
    values (
      v_order_id,
      'WO-2026-' || lpad(v_i::text, 4, '0'),
      case when v_i % 3 = 0 then 'sap' else null end,
      case when v_i % 3 = 0 then 'DEMO-EXT-' || lpad(v_i::text, 6, '0') else null end,
      v_type,
      v_status,
      v_priority,
      'Cliente Ficticio ' || lpad(v_i::text, 4, '0'),
      'SUM-' || lpad(v_i::text, 6, '0'),
      'Dirección Demo ' || v_i || ', ' || v_district,
      v_district,
      v_zone,
      v_location,
      v_scheduled,
      v_scheduled + interval '8 hours',
      'Orden ficticia generada para pruebas de volumen.',
      case when v_status = 'cancelada'
           then 'Cancelada en datos ficticios de prueba'
           else null end,
      v_completed,
      v_despachador,
      v_despachador
    );

    v_hist_at := v_scheduled - interval '2 hours';

    if v_status in ('asignada', 'en_proceso', 'ejecutada', 'imposibilitada') then
      v_hash := ('x' || substr(md5('te:' || v_i::text), 1, 8))::bit(32)::int & 2147483647;
      v_tech := v_tecnicos[1 + (v_hash % v_total_tecnicos)];
      v_assignment_id := ('cccccccc-cccc-4ccc-8ccc-' || lpad(to_hex(v_i)::text, 12, '0'))::uuid;

      insert into public.work_order_assignments (
        id, work_order_id, technician_id, assigned_by, assigned_at,
        unassigned_at, unassigned_by, end_reason, notes
      )
      values (
        v_assignment_id,
        v_order_id,
        v_tech,
        v_despachador,
        v_hist_at,
        -- La asignación queda vigente aunque la orden llegue a un estado
        -- terminal: así el técnico conserva visibilidad de su trabajo y puede
        -- seguir registrando evidencias. `unassigned_at` marca reasignación o
        -- desasignación explícita, no "en progreso".
        null,
        null,
        null,
        'Asignación ficticia generada'
      );

      insert into public.work_order_status_history (
        work_order_id, from_status, to_status, changed_by, changed_at, reason
      )
      values (
        v_order_id, 'pendiente', 'asignada', v_despachador, v_hist_at,
        'Asignación ficticia generada'
      );

      if v_status <> 'asignada' then
        insert into public.work_order_status_history (
          work_order_id, from_status, to_status, changed_by, changed_at, reason
        )
        values (
          v_order_id, 'asignada', 'en_proceso', v_tech,
          v_hist_at + interval '1 hour', 'Inicio ficticio de trabajo'
        );
      end if;

      if v_status = 'ejecutada' then
        insert into public.work_order_status_history (
          work_order_id, from_status, to_status, changed_by, changed_at, reason
        )
        values (
          v_order_id, 'en_proceso', 'ejecutada', v_tech, v_completed,
          'Trabajo ficticio ejecutado'
        );
      elsif v_status = 'imposibilitada' then
        insert into public.work_order_status_history (
          work_order_id, from_status, to_status, changed_by, changed_at, reason
        )
        values (
          v_order_id, 'en_proceso', 'imposibilitada', v_tech, v_completed,
          'Motivo ficticio de imposibilidad'
        );
      end if;
    elsif v_status = 'cancelada' then
      insert into public.work_order_status_history (
        work_order_id, from_status, to_status, changed_by, changed_at, reason
      )
      values (
        v_order_id, 'pendiente', 'cancelada', v_despachador, v_hist_at,
        'Cancelada en datos ficticios de prueba'
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Evidencias generadas (solo metadatos)
-- ---------------------------------------------------------------------------
-- Para cada técnico se registran las 3 evidencias de sus órdenes ejecutadas más
-- recientes. Reparte la muestra entre todos los técnicos (a diferencia de un
-- criterio por índice, que puede sesgar la distribución) y garantiza que cada
-- uno tenga material para probar la galería.
-- IMPORTANTE: el binario NO existe en Storage; es una referencia de demo.

insert into public.work_order_evidence (
  id, work_order_id, assignment_id, kind, storage_bucket, storage_path,
  mime_type, size_bytes, captured_at, location, uploaded_by, metadata
)
select
  ('ffffffff-ffff-4fff-8fff-' || right(a.work_order_id::text, 12))::uuid,
  a.work_order_id,
  a.id,
  'despues',
  'work-order-evidence',
  a.work_order_id::text || '/despues.jpg',
  'image/jpeg',
  102400 + (a.rn * 2048),
  o.completed_at,
  o.location,
  a.technician_id,
  '{"demo": true, "binario": "no-existe"}'::jsonb
from (
  select
    a.id,
    a.work_order_id,
    a.technician_id,
    row_number() over (
      partition by a.technician_id
      order by o.completed_at desc nulls last, o.code
    ) as rn
  from public.work_order_assignments a
  join public.work_orders o on o.id = a.work_order_id
  where o.status = 'ejecutada'
) a
join public.work_orders o on o.id = a.work_order_id
where a.rn <= 3
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 8. Rutas y paradas generadas
-- ---------------------------------------------------------------------------
-- Una ruta por técnico para hoy (con sus órdenes activas como paradas), una ruta
-- completada para ayer (con sus órdenes ejecutadas/imposibilitadas) y una ruta
-- cancelada de ejemplo para probar el filtro de estados de ruta.

with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
),
act as (
  select
    a.technician_id,
    o.id as work_order_id,
    o.status,
    o.scheduled_at,
    row_number() over (
      partition by a.technician_id
      order by o.scheduled_at, o.code
    ) as stop_order
  from public.work_order_assignments a
  join public.work_orders o on o.id = a.work_order_id
  where a.unassigned_at is null
    and o.status in ('asignada', 'en_proceso')
)
insert into public.routes (
  id, code, technician_id, route_date, status, started_at, notes, created_by
)
select
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(100 + t.rn)::text, 12, '0'))::uuid,
  'RUTA-' || to_char(current_date, 'YYYYMMDD') || '-' || lpad(t.rn::text, 3, '0'),
  t.technician_id,
  current_date,
  (case
     when exists (
       select 1 from act a
        where a.technician_id = t.technician_id
          and a.status = 'en_proceso'
     ) then 'en_curso'
     else 'planificada'
   end)::public.route_status,
  case
    when exists (
      select 1 from act a
       where a.technician_id = t.technician_id
         and a.status = 'en_proceso'
    ) then date_trunc('day', now()) + interval '8 hours'
    else null
  end,
  'Ruta ficticia del día generada para pruebas de jornada.',
  '22222222-2222-4222-8222-222222222222'
from tec t
on conflict (id) do nothing;

with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
),
act as (
  select
    a.technician_id,
    o.id as work_order_id,
    o.status,
    o.scheduled_at,
    row_number() over (
      partition by a.technician_id
      order by o.scheduled_at, o.code
    ) as stop_order
  from public.work_order_assignments a
  join public.work_orders o on o.id = a.work_order_id
  where a.unassigned_at is null
    and o.status in ('asignada', 'en_proceso')
)
insert into public.route_stops (
  id, route_id, work_order_id, stop_order, status, planned_at, arrived_at, notes
)
select
  ('dddddddd-dddd-4ddd-8ddd-' || lpad(to_hex(1000 + t.rn * 100 + a.stop_order)::text, 12, '0'))::uuid,
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(100 + t.rn)::text, 12, '0'))::uuid,
  a.work_order_id,
  a.stop_order,
  (case when a.status = 'en_proceso' then 'en_proceso' else 'pendiente'
   end)::public.route_stop_status,
  a.scheduled_at,
  case when a.status = 'en_proceso' then a.scheduled_at + interval '15 minutes' else null end,
  'Parada ficticia generada para pruebas de jornada.'
from tec t
join act a on a.technician_id = t.technician_id
where a.stop_order <= 12
on conflict (id) do nothing;

-- Ruta de ayer, completada u omitida según la orden.
with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
),
done as (
  select
    a.technician_id,
    o.id as work_order_id,
    o.status,
    o.completed_at,
    row_number() over (
      partition by a.technician_id
      order by o.completed_at nulls last, o.code
    ) as stop_order
  from public.work_order_assignments a
  join public.work_orders o on o.id = a.work_order_id
  where o.status in ('ejecutada', 'imposibilitada')
)
insert into public.routes (
  id, code, technician_id, route_date, status, started_at, completed_at, notes, created_by
)
select
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(200 + t.rn)::text, 12, '0'))::uuid,
  'RUTA-' || to_char(current_date - 1, 'YYYYMMDD') || '-' || lpad(t.rn::text, 3, '0'),
  t.technician_id,
  current_date - 1,
  'completada'::public.route_status,
  date_trunc('day', now()) - interval '1 day' + interval '8 hours',
  date_trunc('day', now()) - interval '1 day' + interval '17 hours',
  'Ruta ficticia completada (generada) para pruebas de historial.',
  '22222222-2222-4222-8222-222222222222'
from tec t
where exists (select 1 from done d where d.technician_id = t.technician_id)
on conflict (id) do nothing;

with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
),
done as (
  select
    a.technician_id,
    o.id as work_order_id,
    o.status,
    o.completed_at,
    row_number() over (
      partition by a.technician_id
      order by o.completed_at nulls last, o.code
    ) as stop_order
  from public.work_order_assignments a
  join public.work_orders o on o.id = a.work_order_id
  where o.status in ('ejecutada', 'imposibilitada')
)
insert into public.route_stops (
  id, route_id, work_order_id, stop_order, status, planned_at, arrived_at, completed_at, notes
)
select
  ('dddddddd-dddd-4ddd-8ddd-' || lpad(to_hex(2000 + t.rn * 100 + d.stop_order)::text, 12, '0'))::uuid,
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(200 + t.rn)::text, 12, '0'))::uuid,
  d.work_order_id,
  d.stop_order,
  (case when d.status = 'ejecutada' then 'completada' else 'omitida'
   end)::public.route_stop_status,
  d.completed_at - interval '1 hour',
  d.completed_at - interval '45 minutes',
  d.completed_at,
  'Parada ficticia de la ruta completada.'
from tec t
join done d on d.technician_id = t.technician_id
where d.stop_order <= 12
on conflict (id) do nothing;

-- Ruta cancelada de ejemplo (sin paradas) para el último técnico del catálogo.
with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
)
insert into public.routes (
  id, code, technician_id, route_date, status, notes, created_by
)
select
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(300 + t.rn)::text, 12, '0'))::uuid,
  'RUTA-' || to_char(current_date - 2, 'YYYYMMDD') || '-' || lpad(t.rn::text, 3, '0'),
  t.technician_id,
  current_date - 2,
  'cancelada'::public.route_status,
  'Ruta ficticia cancelada para pruebas del filtro de estados.',
  '22222222-2222-4222-8222-222222222222'
from tec t
where t.rn = 8
on conflict (id) do nothing;

-- Rutas planificadas para mañana (sin paradas todavía) en los tres primeros
-- técnicos del catálogo: dan población real al filtro de rutas "planificada".
with tec as (
  select
    p.id as technician_id,
    row_number() over (order by td.employee_code) as rn
  from public.profiles p
  join public.technician_details td on td.profile_id = p.id
  where p.role = 'tecnico'
    and p.is_active
)
insert into public.routes (
  id, code, technician_id, route_date, status, notes, created_by
)
select
  ('bbbbbbbb-bbbb-4bbb-8bbb-' || lpad(to_hex(400 + t.rn)::text, 12, '0'))::uuid,
  'RUTA-' || to_char(current_date + 1, 'YYYYMMDD') || '-' || lpad(t.rn::text, 3, '0'),
  t.technician_id,
  current_date + 1,
  'planificada'::public.route_status,
  'Ruta ficticia planificada para mañana (sin paradas aún).',
  '22222222-2222-4222-8222-222222222222'
from tec t
where t.rn <= 3
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 9. Staging de ingesta (payload genérico: el contrato SAP NO está definido)
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

-- ---------------------------------------------------------------------------
-- 10. Resumen (queda en el log de `supabase db reset`)
-- ---------------------------------------------------------------------------

select
  (select count(*) from public.work_orders) as ordenes,
  (select count(*) from public.work_orders where location is null) as ordenes_sin_ubicacion,
  (select count(distinct district) from public.work_orders) as distritos,
  (select count(*) from public.work_order_assignments) as asignaciones,
  (select count(*) from public.work_order_assignments where unassigned_at is null) as asignaciones_vigentes,
  (select count(*) from public.work_order_status_history) as historial,
  (select count(*) from public.routes) as rutas,
  (select count(*) from public.route_stops) as paradas,
  (select count(*) from public.work_order_evidence) as evidencias,
  (select count(*) from public.profiles where role = 'tecnico') as tecnicos;
