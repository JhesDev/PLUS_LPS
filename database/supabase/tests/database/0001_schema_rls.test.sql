-- PLUS_LPS :: pruebas de esquema, RLS y reglas de negocio
-- Ejecutar con: cd database/supabase && supabase test db
-- Se usa una transacción con ROLLBACK para no contaminar el seed.
-- Usuarios demo del seed:
--   coordinador 11111111-1111-4111-8111-111111111111
--   despachador 22222222-2222-4222-8222-222222222222
--   tecnico 1   33333333-3333-4333-8333-333333333331
--   tecnico 2   33333333-3333-4333-8333-333333333332

begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(24);

-- ---------------------------------------------------------------------------
-- Coordinador: lectura total, escritura nula
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.work_orders),
  12,
  'coordinador ve todas las órdenes'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
with intento as (
  update public.work_orders
     set notes = 'intento-coordinador'
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001'
  returning 1
)
select is(
  (select count(*)::int from intento),
  0,
  'coordinador no puede modificar órdenes (RLS)'
);
reset role;

-- ---------------------------------------------------------------------------
-- Despachador: escribe campos operativos, nunca status por tabla
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
with intento as (
  update public.work_orders
     set notes = 'nota-despachador'
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001'
  returning 1
)
select is(
  (select count(*)::int from intento),
  1,
  'despachador puede actualizar campos operativos'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$update public.work_orders
       set status = 'cancelada'
     where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000002'$$,
  '42501',
  null,
  'despachador no puede cambiar status por tabla (solo RPC)'
);
reset role;

-- ---------------------------------------------------------------------------
-- Técnico: solo lo suyo
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.work_orders),
  2,
  'técnico 1 solo ve sus 2 órdenes asignadas'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (
    select count(*)::int
      from public.work_orders
     where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000006'
  ),
  0,
  'técnico 1 no ve una orden de otro técnico'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.assign_work_order(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000002'::uuid,
      '33333333-3333-4333-8333-333333333331'::uuid
    )$$,
  '42501',
  null,
  'técnico no puede asignar órdenes'
);
reset role;

-- ---------------------------------------------------------------------------
-- RPC de asignación y avance
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.assign_work_order(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000002'::uuid,
      '33333333-3333-4333-8333-333333333331'::uuid,
      'Asignación de prueba pgTAP'
    )$$,
  'despachador asigna una orden por RPC'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select status::text from public.work_orders
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000002'),
  'asignada',
  'la orden asignada queda en estado asignada'
);
reset role;

select is(
  (select count(*)::int
     from public.work_order_status_history
    where work_order_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000002'),
  1,
  'la asignación deja auditoría de estado'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.update_work_order_status(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000007'::uuid,
      'ejecutada'::public.work_order_status,
      'Trabajo terminado (prueba pgTAP)'
    )$$,
  'técnico asignado ejecuta su orden en proceso'
);
reset role;

select is(
  (select count(*)::int
     from public.work_order_status_history
    where work_order_id = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007'),
  3,
  'la ejecución deja auditoría de estado'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.update_work_order_status(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005'::uuid,
      'ejecutada'::public.work_order_status,
      'Salto inválido'
    )$$,
  '23514',
  null,
  'técnico no puede saltar de asignada a ejecutada'
);
reset role;

-- ---------------------------------------------------------------------------
-- Escrituras directas denegadas / escalada de rol
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$update public.work_order_assignments
       set notes = 'intento'
     where id = 'cccccccc-cccc-4ccc-8ccc-000000000005'$$,
  '42501',
  null,
  'técnico no puede escribir asignaciones directamente'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$update public.profiles
       set role = 'despachador'
     where id = '33333333-3333-4333-8333-333333333331'$$,
  '42501',
  null,
  'un técnico no puede auto-escalar su rol'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
with intento as (
  update public.profiles
     set full_name = 'Perfil ajeno'
   where id = '33333333-3333-4333-8333-333333333332'
  returning 1
)
select is(
  (select count(*)::int from intento),
  0,
  'técnico no puede editar el perfil de otro técnico'
);
reset role;

-- ---------------------------------------------------------------------------
-- Evidencias: convención de ruta y append-only
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.work_order_evidence (work_order_id, storage_path)
    values (
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      'otra-orden/antes.jpg'
    )$$,
  '23514',
  null,
  'la ruta de Storage debe pertenecer a la orden'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into public.work_order_evidence (work_order_id, storage_path, kind)
    values (
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000009/despues-2.jpg',
      'despues'
    )$$,
  'despachador registra metadatos de evidencia válidos'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select public.update_work_order_status(
      'aaaaaaaa-aaaa-4aaa-8aaa-000000000005'::uuid,
      'cancelada'::public.work_order_status,
      'Intento de cancelación'
    )$$,
  '23514',
  null,
  'técnico no puede cancelar una orden'
);
reset role;

-- ---------------------------------------------------------------------------
-- Altas operativas del despachador y validación de técnico en rutas
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into public.work_orders (code, type, priority, customer_name)
    values ('WO-TEST-PGTAP', 'inspeccion', 3, 'Cliente de prueba pgTAP')$$,
  'despachador crea una orden con columnas permitidas'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.work_orders (code, type, priority, customer_name)
    values ('WO-TEST-COORD', 'inspeccion', 3, 'Intento coordinador')$$,
  '42501',
  null,
  'coordinador no puede crear órdenes'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.routes (code, technician_id, route_date)
    values (
      'RUTA-TEST-MAL',
      '11111111-1111-4111-8111-111111111111',
      current_date
    )$$,
  '23514',
  null,
  'una ruta no puede pertenecer a un perfil no técnico'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into public.routes (code, technician_id, route_date)
    values (
      'RUTA-TEST-OK',
      '33333333-3333-4333-8333-333333333333',
      current_date
    )$$,
  'despachador crea una ruta para un técnico activo'
);
reset role;

-- ---------------------------------------------------------------------------
-- Staging fuera del alcance de la API
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333331","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$select count(*) from ingest.records$$,
  '42501',
  null,
  'authenticated no accede al esquema ingest'
);
reset role;

select * from finish();
rollback;
