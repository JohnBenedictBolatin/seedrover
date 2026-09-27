begin;

select plan(8);

select has_function('public', 'has_permission', array['text']);
select has_function('public', 'void_sales_record', array['uuid', 'text', 'text']);
select has_function('public', 'void_sales_record_internal', array['uuid', 'text', 'text']);
select has_function('public', 'rollback_failed_installment_sale', array['uuid', 'uuid', 'text']);

select ok(
  has_function_privilege('authenticated', 'public.void_sales_record(uuid, text, text)', 'EXECUTE'),
  'authenticated users can call the role-checked sale void function'
);
select ok(
  not has_function_privilege('authenticated', 'public.void_sales_record_internal(uuid, text, text)', 'EXECUTE'),
  'authenticated users cannot bypass the role check through the internal void function'
);
select ok(
  not has_function_privilege('authenticated', 'public.rollback_failed_installment_sale(uuid, uuid, text)', 'EXECUTE'),
  'authenticated users cannot call the installment compensation function'
);
select ok(
  has_function_privilege('service_role', 'public.rollback_failed_installment_sale(uuid, uuid, text)', 'EXECUTE'),
  'the server service role can compensate for a failed installment setup'
);

select * from finish();
rollback;
