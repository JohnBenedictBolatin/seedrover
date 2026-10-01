begin;

select plan(6);

select has_column('public', 'installment_payments', 'collection_group_id');
select has_column('public', 'installment_payments', 'collection_type');
select ok(
  not exists(
    select 1 from public.installment_payments
    where collection_group_id is null or collection_type is null
  ),
  'all existing installment payment allocations are classified and grouped'
);
select ok(
  exists(
    select 1 from pg_constraint
    where conrelid = 'public.installment_payments'::regclass
      and conname = 'installment_payments_collection_type_allowed'
  ),
  'collection types are constrained to down payments and installments'
);
select ok(
  position('collection_group_id_value := gen_random_uuid()' in pg_get_functiondef('public.create_installment_plan(uuid,text,numeric,numeric,text)'::regprocedure)) > 0,
  'one down payment group is shared across its schedule allocations'
);
select ok(
  position('collection_type' in pg_get_functiondef('public.create_installment_plan(uuid,text,numeric,numeric,text)'::regprocedure)) > 0,
  'new down payment allocations are explicitly classified'
);

select * from finish();
rollback;
