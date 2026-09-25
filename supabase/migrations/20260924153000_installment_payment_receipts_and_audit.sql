alter table public.installment_payments
  add column if not exists receipt_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'installment-receipts',
  'installment-receipts',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

drop policy if exists installment_receipts_authenticated_select on storage.objects;
drop policy if exists installment_receipts_authenticated_insert on storage.objects;
drop policy if exists installment_receipts_authenticated_delete on storage.objects;

create policy installment_receipts_authenticated_select
  on storage.objects for select to authenticated
  using (bucket_id = 'installment-receipts');

create policy installment_receipts_authenticated_insert
  on storage.objects for insert to authenticated
  with check (bucket_id = 'installment-receipts');

create policy installment_receipts_authenticated_delete
  on storage.objects for delete to authenticated
  using (bucket_id = 'installment-receipts');

drop function if exists public.record_installment_payment(uuid, numeric, date, text, text, text, text);

create or replace function public.record_installment_payment(
  p_schedule_id uuid,
  p_amount numeric,
  p_payment_date date default current_date,
  p_payment_method text default 'Cash',
  p_transaction_reference text default null,
  p_other_payment_method text default null,
  p_notes text default null,
  p_receipt_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  schedule_row public.installment_schedule%rowtype;
  plan_row public.installment_plans%rowtype;
  order_row public.sales_orders%rowtype;
  already_paid numeric(12, 2);
  remaining_amount numeric(12, 2);
  payment_id uuid;
  plan_status text;
begin
  if auth.uid() is null then
    raise exception 'Sign in before recording an installment payment.';
  end if;

  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to record installment payments.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  if p_payment_date is null or p_payment_date > current_date then
    raise exception 'Payment date cannot be in the future.';
  end if;

  if p_payment_method not in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other') then
    raise exception 'Invalid payment method.';
  end if;

  if p_payment_method <> 'Cash' and nullif(btrim(p_transaction_reference), '') is null then
    raise exception 'Transaction ID is required for non-cash payment.';
  end if;

  if p_payment_method = 'Other' and nullif(btrim(p_other_payment_method), '') is null then
    raise exception 'Other payment method is required.';
  end if;

  select s.* into schedule_row
  from public.installment_schedule s
  where s.id = p_schedule_id
  for update;

  if not found then
    raise exception 'The installment period could not be found.';
  end if;

  select p.* into plan_row
  from public.installment_plans p
  where p.id = schedule_row.plan_id
  for update;

  select * into order_row
  from public.sales_orders
  where id = plan_row.sales_order_id
  for update;

  if plan_row.status <> 'Active' or order_row.status <> 'Completed' then
    raise exception 'This installment plan is no longer active.';
  end if;

  select coalesce(sum(amount), 0) into already_paid
  from public.installment_payments
  where schedule_id = schedule_row.id;

  remaining_amount := round(schedule_row.scheduled_amount - already_paid, 2);
  if p_amount > remaining_amount then
    raise exception 'Payment cannot exceed the selected installment balance of PHP %.', to_char(remaining_amount, 'FM999999990.00');
  end if;

  insert into public.installment_payments (
    plan_id,
    schedule_id,
    amount,
    payment_date,
    payment_method,
    transaction_reference,
    other_payment_method,
    notes,
    receipt_path,
    recorded_by
  )
  values (
    plan_row.id,
    schedule_row.id,
    round(p_amount, 2),
    p_payment_date,
    p_payment_method,
    nullif(btrim(p_transaction_reference), ''),
    nullif(btrim(p_other_payment_method), ''),
    nullif(btrim(p_notes), ''),
    nullif(btrim(p_receipt_path), ''),
    auth.uid()
  )
  returning id into payment_id;

  update public.sales_orders
  set amount_paid = round(coalesce(amount_paid, 0) + p_amount, 2),
      change_amount = null
  where id = order_row.id;

  if not exists (
    select 1
    from public.installment_schedule s
    where s.plan_id = plan_row.id
      and coalesce((select sum(ip.amount) from public.installment_payments ip where ip.schedule_id = s.id), 0) < s.scheduled_amount
  ) then
    plan_status := 'Completed';
  else
    plan_status := 'Active';
  end if;

  update public.installment_plans
  set status = plan_status,
      updated_at = now()
  where id = plan_row.id;

  return jsonb_build_object(
    'payment_id', payment_id,
    'plan_id', plan_row.id,
    'schedule_id', schedule_row.id,
    'plan_status', plan_status
  );
end;
$$;

revoke all on function public.record_installment_payment(uuid, numeric, date, text, text, text, text, text) from public;
grant execute on function public.record_installment_payment(uuid, numeric, date, text, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
