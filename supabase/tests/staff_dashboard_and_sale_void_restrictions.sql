begin;

select plan(8);

select has_function('public'::name, 'has_permission'::name, array['text']::name[]);
select has_function('public'::name, 'void_sales_record'::name, array['uuid', 'text', 'text']::name[]);
select has_function('public'::name, 'void_sales_record_internal'::name, array['uuid', 'text', 'text']::name[]);
select ok(to_regprocedure('public.rollback_failed_installment_sale(uuid, uuid, text)') is null,
  'the removed installment compensation function stays unavailable');

select ok(
  has_function_privilege('authenticated', 'public.void_sales_record(uuid, text, text)', 'EXECUTE'),
  'authenticated users can call the role-checked sale void function'
);
select ok(
  not has_function_privilege('authenticated', 'public.void_sales_record_internal(uuid, text, text)', 'EXECUTE'),
  'authenticated users cannot bypass the role check through the internal void function'
);
select ok(
  has_function_privilege('authenticated', 'public.void_sales_record_v2(jsonb)', 'EXECUTE'),
  'authenticated users can use the idempotent sale cancellation workflow'
);
select ok(
  not has_function_privilege('anon', 'public.void_sales_record_v2(jsonb)', 'EXECUTE'),
  'anonymous users cannot cancel sales'
);

select * from finish();
rollback;
