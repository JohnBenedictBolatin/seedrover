alter table public.installment_payments
  add column if not exists collection_group_id uuid,
  add column if not exists collection_type text;

with initial_collections as (
  select plan_id, gen_random_uuid() as collection_group_id
  from public.installment_payments
  where notes = 'Initial payment applied to installment schedule.'
  group by plan_id
)
update public.installment_payments payment
set collection_group_id = initial_collections.collection_group_id,
    collection_type = 'down_payment'
from initial_collections
where payment.plan_id = initial_collections.plan_id
  and payment.notes = 'Initial payment applied to installment schedule.'
  and payment.collection_group_id is null;

update public.installment_payments
set collection_group_id = id,
    collection_type = 'installment'
where collection_group_id is null;

alter table public.installment_payments
  alter column collection_group_id set default gen_random_uuid(),
  alter column collection_group_id set not null,
  alter column collection_type set default 'installment',
  alter column collection_type set not null;

alter table public.installment_payments
  add constraint installment_payments_collection_type_allowed
  check (collection_type in ('down_payment', 'installment'));

create or replace function public.create_installment_plan(
  p_sales_order_id uuid,
  p_frequency text,
  p_payment_amount numeric,
  p_initial_payment numeric default 0,
  p_initial_payment_method text default 'Cash'
)
returns public.installment_plans
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
  plan_row public.installment_plans%rowtype;
  schedule_row public.installment_schedule%rowtype;
  collection_group_id_value uuid;
  installment_count integer;
  installment_number integer;
  remaining_total numeric(12, 2);
  schedule_amount numeric(12, 2);
  allocation_remaining numeric(12, 2);
  allocation_amount numeric(12, 2);
  due_date_value date;
begin
  if auth.uid() is null then
    raise exception 'Sign in before creating an installment plan.';
  end if;

  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to create installment plans.';
  end if;

  if p_frequency not in ('Weekly', 'Monthly', 'Yearly') then
    raise exception 'Invalid installment frequency.';
  end if;

  if p_payment_amount is null or p_payment_amount <= 0 then
    raise exception 'Installment amount must be greater than zero.';
  end if;

  if coalesce(p_initial_payment, 0) < 0 then
    raise exception 'Initial payment cannot be negative.';
  end if;

  if p_initial_payment_method not in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other') then
    raise exception 'Invalid initial payment method.';
  end if;

  select * into order_row
  from public.sales_orders
  where id = p_sales_order_id
  for update;

  if not found then
    raise exception 'The sale could not be found.';
  end if;

  if order_row.status <> 'Completed' then
    raise exception 'Only completed sales can have installment plans.';
  end if;

  if order_row.payment_method <> 'Cash' and order_row.payment_method <> 'Installment' then
    raise exception 'The sale payment method is not eligible for an installment plan.';
  end if;

  if exists (select 1 from public.installment_plans where sales_order_id = order_row.id) then
    raise exception 'This sale already has an installment plan.';
  end if;

  if coalesce(p_initial_payment, 0) >= order_row.total_amount then
    raise exception 'An installment sale must have a remaining balance.';
  end if;

  update public.sales_orders
  set payment_method = 'Installment',
      transaction_reference = null,
      other_payment_method = null,
      amount_paid = coalesce(p_initial_payment, 0),
      change_amount = null
  where id = order_row.id;

  insert into public.installment_plans (
    sales_order_id,
    customer_name,
    customer_contact,
    receipt_number,
    frequency,
    payment_amount,
    total_amount,
    initial_payment,
    financed_amount
  )
  values (
    order_row.id,
    coalesce(order_row.customer_name, 'Walk-in customer'),
    order_row.customer_contact,
    order_row.receipt_number,
    p_frequency,
    round(p_payment_amount, 2),
    round(order_row.total_amount, 2),
    round(coalesce(p_initial_payment, 0), 2),
    round(order_row.total_amount - coalesce(p_initial_payment, 0), 2)
  )
  returning * into plan_row;

  installment_count := ceil(order_row.total_amount / p_payment_amount);
  remaining_total := round(order_row.total_amount, 2);

  for installment_number in 1..installment_count loop
    schedule_amount := least(round(p_payment_amount, 2), remaining_total);
    due_date_value := case p_frequency
      when 'Weekly' then (order_row.sale_date::date + (installment_number * interval '7 days'))::date
      when 'Monthly' then (order_row.sale_date::date + (installment_number * interval '1 month'))::date
      else (order_row.sale_date::date + (installment_number * interval '1 year'))::date
    end;

    insert into public.installment_schedule (plan_id, installment_number, due_date, scheduled_amount)
    values (plan_row.id, installment_number, due_date_value, schedule_amount)
    returning * into schedule_row;

    remaining_total := round(remaining_total - schedule_amount, 2);
  end loop;

  allocation_remaining := round(coalesce(p_initial_payment, 0), 2);
  if allocation_remaining > 0 then
    collection_group_id_value := gen_random_uuid();
  end if;

  for schedule_row in
    select * from public.installment_schedule
    where plan_id = plan_row.id
    order by installment_number
  loop
    exit when allocation_remaining <= 0;
    allocation_amount := least(allocation_remaining, schedule_row.scheduled_amount);

    insert into public.installment_payments (
      plan_id,
      schedule_id,
      amount,
      payment_date,
      payment_method,
      other_payment_method,
      notes,
      recorded_by,
      collection_group_id,
      collection_type
    )
    values (
      plan_row.id,
      schedule_row.id,
      allocation_amount,
      order_row.sale_date::date,
      p_initial_payment_method,
      case when p_initial_payment_method = 'Other' then 'Initial installment payment' else null end,
      'Initial payment applied to installment schedule.',
      auth.uid(),
      collection_group_id_value,
      'down_payment'
    );

    allocation_remaining := round(allocation_remaining - allocation_amount, 2);
  end loop;

  return plan_row;
end;
$$;

revoke all on function public.create_installment_plan(uuid, text, numeric, numeric, text) from public;
grant execute on function public.create_installment_plan(uuid, text, numeric, numeric, text) to authenticated;

notify pgrst, 'reload schema';
