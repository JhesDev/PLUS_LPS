-- PLUS_LPS :: pruebas del seed de volumen, coherencia referencial y evidencias
-- Ejecutar con: cd database/supabase && supabase test db
-- Se usa una transacción con ROLLBACK para no contaminar los datos del seed.
--
-- Referencias del seed:
--   orden 0005 asignada y vigente al técnico 1 (33333333-...-333333333331)
--   orden 0006 asignada y vigente al técnico 2 (33333333-...-333333333332)

begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(37);

-- ---------------------------------------------------------------------------
-- Volumen y variedad del seed
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.work_orders),
  612,
  'el seed deja 612 órdenes (600 generadas + 12 de muestra)'
);

select ok(
  (select count(*) from public.work_orders) >= 500,
  'el seed supera el mínimo de 500 órdenes'
);

select ok(
  (select count(*) from public.work_orders where location is null) >= 30,
  'existen al menos 30 órdenes sin coordenadas'
);

select is(
  (select count(distinct extensions.ST_SRID(location))::int
     from public.work_orders where location is not null),
  1,
  'todas las geometrías usan un único SRID'
);

select is(
  (select count(*)::int from public.work_orders
    where location is not null
      and extensions.ST_SRID(location) <> 4326),
  0,
  'todas las geometrías están en SRID 4326'
);

select is(
  (select count(*)::int from public.work_orders
    where location is not null
      and (extensions.ST_Y(location) < -12.40
        or extensions.ST_Y(location) > -11.70
        or extensions.ST_X(location) < -77.30
        or extensions.ST_X(location) > -76.50)),
  0,
  'todas las coordenadas caen dentro del área de Lima Metropolitana y Callao'
);

select ok(
  (select count(distinct district) from public.work_orders) >= 30,
  'el seed reparte las órdenes entre al menos 30 distritos'
);

select is(
  (select count(distinct status)::int from public.work_orders),
  6,
  'están representados los 6 estados de orden'
);

select is(
  (select count(distinct type)::int from public.work_orders),
  6,
  'están representados los 6 tipos de trabajo'
);

select is(
  (select count(distinct priority)::int from public.work_orders),
  5,
  'están representadas las 5 prioridades'
);

select is(
  (select count(distinct status)::int from public.routes),
  4,
  'están representados los 4 estados de ruta'
);

-- ---------------------------------------------------------------------------
-- Coherencia referencial y auditoría
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from (
     select work_order_id
       from public.work_order_assignments
      where unassigned_at is null
      group by work_order_id
     having count(*) > 1
   ) d),
  0,
  'ninguna orden tiene dos asignaciones vigentes'
);

select is(
  (select count(*)::int
     from public.work_order_assignments a
     join public.profiles p on p.id = a.technician_id
    where p.role <> 'tecnico' or not p.is_active),
  0,
  'todas las asignaciones apuntan a técnicos activos con rol tecnico'
);

select is(
  (select count(*)::int
     from public.work_orders o
    where o.status <> 'pendiente'
      and not exists (
        select 1 from public.work_order_status_history h
         where h.work_order_id = o.id
      )),
  0,
  'toda orden fuera de pendiente tiene auditoría de estado'
);

select is(
  (select count(*)::int
     from public.work_orders o
    where o.status <> 'pendiente'
      and (
        select h.to_status
          from public.work_order_status_history h
         where h.work_order_id = o.id
         order by h.changed_at desc, h.id desc
         limit 1
      ) is distinct from o.status),
  0,
  'el último estado auditado coincide con el estado actual de la orden'
);

select is(
  (select count(*)::int
     from (
       select technician_id, route_date
         from public.routes
        group by technician_id, route_date
       having count(*) > 1
     ) d),
  0,
  'un técnico no tiene dos rutas en la misma fecha'
);

select is(
  (select count(*)::int
     from (
       select route_id, work_order_id
         from public.route_stops
        group by route_id, work_order_id
       having count(*) > 1
     ) d),
  0,
  'una orden no se repite dentro de la misma ruta'
);

select is(
  (select count(*)::int from public.route_stops where stop_order < 1),
  0,
  'todas las paradas tienen un orden de parada positivo'
);

-- ---------------------------------------------------------------------------
-- Evidencias: forma, distribución y Storage
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int
     from public.work_order_evidence
    where storage_path not like work_order_id::text || '/%'),
  0,
  'toda evidencia sigue la convención {work_order_id}/{archivo}'
);

select is(
  (select count(*)::int
     from public.work_order_evidence
    where storage_bucket <> 'work-order-evidence'),
  0,
  'todas las evidencias apuntan al bucket de evidencias'
);

select is(
  (select count(*)::int from public.work_order_evidence where assignment_id is null),
  0,
  'toda evidencia generada está ligada a una asignación'
);

select is(
  (select count(*)::int from (
     select p.id
       from public.profiles p
      where p.role = 'tecnico'
        and p.is_active
        and not exists (
          select 1 from public.work_order_evidence e
           where e.uploaded_by = p.id
        )
   ) d),
  0,
  'cada técnico activo tiene al menos una evidencia de ejemplo'
);

select is(
  (select count(*)::int
     from information_schema.columns
    where table_schema = 'public'
      and table_name = 'work_order_evidence'
      and data_type = 'bytea'),
  0,
  'la tabla de evidencias no almacena binarios'
);

select is(
  (select "public" from storage.buckets where id = 'work-order-evidence'),
  false,
  'el bucket de evidencias es privado'
);

select is(
  (select file_size_limit from storage.buckets where id = 'work-order-evidence'),
  10485760::bigint,
  'el bucket limita el tamaño a 10 MiB'
);

select ok(
  (select allowed_mime_types from storage.buckets where id = 'work-order-evidence')
    @> array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
  'el bucket restringe los MIME permitidos'
);

-- ---------------------------------------------------------------------------
-- Usuarios demo utilizables por GoTrue
-- ---------------------------------------------------------------------------
-- GoTrue escanea los columnas *_token como string: un NULL rompe el login y el
-- Admin API ("converting NULL to string is unsupported").

select is(
  (select count(*)::int
     from auth.users
    where email like '%@plus-lps.test'
      and (
        confirmation_token is null
        or recovery_token is null
        or email_change_token_new is null
        or email_change_token_current is null
        or email_change is null
        or phone_change is null
        or phone_change_token is null
        or reauthentication_token is null
      )),
  0,
  'los usuarios demo tienen los tokens como cadena vacía (GoTrue puede cargarlos)'
);

select is(
  (select count(*)::int from public.profiles where role = 'tecnico' and is_active),
  8,
  'el seed deja 8 técnicos activos'
);

-- ---------------------------------------------------------------------------
-- Evidencias: RLS por rol
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.work_order_evidence),
  27,
  'coordinador ve todas las evidencias del seed'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.work_order_evidence),
  3,
  'técnico 1 solo ve las 3 evidencias de sus órdenes'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.work_order_evidence (work_order_id, storage_path)
    values (
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005/coordinador.jpg'
    )$$,
  '42501',
  null,
  'coordinador no puede registrar metadatos de evidencia'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.work_order_evidence (work_order_id, storage_path)
    values (
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000006',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000006/ajena.jpg'
    )$$,
  '42501',
  null,
  'técnico no puede registrar evidencia de una orden ajena'
);
reset role;

-- ---------------------------------------------------------------------------
-- Storage: políticas de objetos por rol
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    values (
      'work-order-evidence',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005/pgtap-tecnico.jpg',
      '33333333-3333-4333-8333-333333333331',
      '33333333-3333-4333-8333-333333333331',
      '{"size": 1024, "mimetype": "image/jpeg"}'::jsonb
    )$$,
  'técnico asignado puede subir un objeto a su orden'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'work-order-evidence',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000006/pgtap-ajena.jpg'
    )$$,
  '42501',
  null,
  'técnico no puede subir objetos a una orden ajena'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'work-order-evidence',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005/pgtap-coordinador.jpg'
    )$$,
  '42501',
  null,
  'coordinador no puede subir objetos al bucket de evidencias'
);
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is(
  (select count(*)::int from storage.objects),
  0,
  'anon no ve ningún objeto de Storage'
);
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'work-order-evidence',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005/pgtap-anon.jpg'
    )$$,
  '42501',
  null,
  'anon no puede subir objetos al bucket de evidencias'
);
reset role;

select * from finish();
rollback;
