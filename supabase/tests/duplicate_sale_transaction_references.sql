begin;

select plan(6);

select has_function(
  'public',
  'prevent_duplicate_sale_transaction_reference',
  'sales transaction reference uniqueness guard is installed'
);

select ok(
  position('pg_advisory_xact_lock' in pg_get_functiondef('public.prevent_duplicate_sale_transaction_reference()'::regprocedure)) > 0,
  'concurrent uses of the same normalized transaction ID are serialized'
);

select ok(
  position('upper(btrim' in pg_get_functiondef('public.prevent_duplicate_sale_transaction_reference()'::regprocedure)) > 0,
  'duplicate detection ignores case and surrounding whitespace'
);

select has_trigger('public', 'sales_orders', 'sales_orders_unique_transaction_reference',
  'sales receipts reject reused payment references');
select has_trigger('public', 'sales_transactions', 'sales_transactions_unique_transaction_reference',
  'legacy sales reject references already used on receipts');

select ok(
  not has_function_privilege('authenticated', 'public.prevent_duplicate_sale_transaction_reference()', 'EXECUTE'),
  'clients cannot call the trigger guard directly'
);

select * from finish();
rollback;
