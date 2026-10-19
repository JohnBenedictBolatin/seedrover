begin;
select plan(14);

select ok(has_table_privilege('authenticated', 'public.crop_profiles', 'SELECT'),
  'authenticated users may read crop profiles subject to crops.view RLS');
select ok(has_table_privilege('authenticated', 'public.crop_profile_versions', 'SELECT'),
  'authenticated users may read crop profile versions subject to crops.view RLS');
select ok(has_table_privilege('authenticated', 'public.crop_activities', 'SELECT'),
  'authenticated users may read crop activities subject to crops.view RLS');
select ok(has_table_privilege('authenticated', 'public.crop_activities', 'INSERT'),
  'authenticated users may record crop activities subject to crops.manage RLS');
select ok(has_table_privilege('authenticated', 'public.crop_tasks', 'UPDATE'),
  'authenticated users may update crop tasks subject to crops.manage RLS');
select ok(has_table_privilege('authenticated', 'public.sales_transactions', 'SELECT'),
  'authenticated users may read sales subject to inventory/sales RLS');
select ok(has_table_privilege('authenticated', 'public.customers', 'INSERT'),
  'authenticated sales roles may create customers subject to RLS');
select ok(has_table_privilege('authenticated', 'public.customer_discounts', 'INSERT'),
  'authenticated sales roles may release discounts subject to RLS');
select ok(has_table_privilege('authenticated', 'public.farm_expenses', 'SELECT'),
  'authenticated users may read expenses subject to administrator-only RLS');
select ok(has_table_privilege('authenticated', 'public.weather_forecasts', 'SELECT'),
  'authenticated crop roles may read weather subject to crops.view RLS');
select ok(has_table_privilege('authenticated', 'public.crop_outcomes', 'SELECT'),
  'authenticated users may read crop outcomes subject to crops.view RLS');
select ok(not has_table_privilege('authenticated', 'public.crop_outcomes', 'INSERT'),
  'crop outcomes cannot be written directly by authenticated users');
select ok(has_column_privilege('authenticated', 'public.customer_payments', 'status', 'UPDATE'),
  'authorized inventory roles may mark a customer payment paid');
select ok(not has_column_privilege('authenticated', 'public.customer_payments', 'amount', 'UPDATE'),
  'customer payment amount cannot be changed after recording');

select * from finish();
rollback;
