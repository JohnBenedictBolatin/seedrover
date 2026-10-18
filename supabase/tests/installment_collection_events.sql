begin;

select plan(2);

select ok(to_regclass('public.installment_payments') is null,
  'the removed installment payment table is not recreated');
select ok(to_regprocedure('public.rollback_failed_installment_sale(uuid, uuid, text)') is null,
  'the removed installment compensation function is not recreated');

select * from finish();
rollback;
