begin;

select plan(14);

select has_table('public', 'action_submissions', 'submission journal is installed');
select has_table('public', 'crop_harvest_corrections', 'harvest correction audit is installed');
select ok((select relrowsecurity from pg_class where oid = 'public.action_submissions'::regclass),
  'submission journal has row-level security enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.crop_harvest_corrections'::regclass),
  'correction audit has row-level security enabled');
select ok(not has_table_privilege('authenticated', 'public.action_submissions', 'SELECT'),
  'clients cannot read other operation payloads directly');
select ok(not has_table_privilege('authenticated', 'public.crop_harvest_corrections', 'INSERT'),
  'clients cannot write directly to the correction audit');
select ok(not has_table_privilege('authenticated', 'public.inventory_transactions', 'INSERT'),
  'clients cannot bypass idempotent inventory movement workflows');
select ok(not has_table_privilege('authenticated', 'public.crop_harvests', 'INSERT'),
  'clients cannot bypass transactional harvest workflows');
select ok(not has_table_privilege('authenticated', 'public.sales_orders', 'UPDATE'),
  'clients cannot bypass the authorized sale cancellation workflow');
select ok(not has_table_privilege('authenticated', 'public.sales_order_items', 'INSERT'),
  'clients cannot create sale items outside the sale workflow');
select ok(has_function_privilege('authenticated', 'public.record_sales_order_v2(jsonb)', 'EXECUTE'),
  'authenticated sales use the versioned idempotent entry point');
select ok(not has_function_privilege('anon', 'public.record_sales_order_v2(jsonb)', 'EXECUTE'),
  'anonymous users cannot record sales');
select ok(has_function_privilege('authenticated', 'public.correct_crop_harvest(jsonb)', 'EXECUTE'),
  'harvest correction is mediated by its guarded function');
select ok(not has_function_privilege('anon', 'public.correct_crop_harvest(jsonb)', 'EXECUTE'),
  'anonymous users cannot correct harvest records');

select * from finish();
rollback;
