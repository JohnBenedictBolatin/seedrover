create or replace function public.create_installment_plan_with_details(
  p_sales_order_id uuid,
  p_frequency text,
  p_installment_count integer,
  p_initial_payment numeric default 0,
  p_initial_payment_method text default 'Cash',
  p_initial_payment_transaction_reference text default null
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
  installment_number integer;
  remaining_total numeric(12, 2);
  schedule_amount numeric(12, 2);
  allocation_remaining numeric(12, 2);
  allocation_amount numeric(12, 2);
  due_date_value date;
  contact_digits text;
  normalized_contact text;
  payment_amount_value numeric(12, 2);
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

  if p_installment_count is null or p_installment_count < 1 or p_installment_count > 120 then
    raise exception 'Number of payments must be between 1 and 120.';
  end if;

  if coalesce(p_initial_payment, 0) < 0 then
    raise exception 'Initial payment cannot be negative.';
  end if;

  if p_initial_payment_method not in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other') then
    raise exception 'Invalid initial payment method.';
  end if;

  if coalesce(p_initial_payment, 0) > 0
    and p_initial_payment_method <> 'Cash'
    and nullif(btrim(p_initial_payment_transaction_reference), '') is null then
    raise exception 'Transaction ID is required for non-cash initial payment.';
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

  if order_row.total_amount <= 0
    or p_installment_count > floor(order_row.total_amount * 100)::integer then
    raise exception 'Number of payments is too high for the sale total.';
  end if;

  contact_digits := regexp_replace(coalesce(order_row.customer_contact, ''), '\D', '', 'g');
  normalized_contact := case
    when contact_digits ~ '^639[0-9]{9}$' then '0' || substr(contact_digits, 3)
    else contact_digits
  end;

  if normalized_contact <> '' then
    perform pg_advisory_xact_lock(hashtextextended(normalized_contact, 0));

    if exists (
      select 1
      from public.installment_plans active_plan
      where active_plan.status = 'Active'
        and active_plan.sales_order_id <> order_row.id
        and case
          when regexp_replace(coalesce(active_plan.customer_contact, ''), '\D', '', 'g') ~ '^639[0-9]{9}$'
            then '0' || substr(regexp_replace(coalesce(active_plan.customer_contact, ''), '\D', '', 'g'), 3)
          else regexp_replace(coalesce(active_plan.customer_contact, ''), '\D', '', 'g')
        end = normalized_contact
    ) then
      raise exception 'This customer still has an active installment. Complete or cancel it before creating another installment sale.';
    end if;
  end if;

  payment_amount_value := round(order_row.total_amount / p_installment_count, 2);
  if payment_amount_value <= 0 then
    raise exception 'Sale total is too small for the selected number of payments.';
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
    payment_amount_value,
    round(order_row.total_amount, 2),
    round(coalesce(p_initial_payment, 0), 2),
    round(order_row.total_amount - coalesce(p_initial_payment, 0), 2)
  )
  returning * into plan_row;

  remaining_total := round(order_row.total_amount, 2);
  for installment_number in 1..p_installment_count loop
    schedule_amount := (
      floor(order_row.total_amount * 100 / p_installment_count)
      + case
          when installment_number <= mod(round(order_row.total_amount * 100)::integer, p_installment_count) then 1
          else 0
        end
    ) / 100;
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
      transaction_reference,
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
      nullif(btrim(p_initial_payment_transaction_reference), ''),
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

revoke all on function public.create_installment_plan_with_details(uuid, text, integer, numeric, text, text) from public;
grant execute on function public.create_installment_plan_with_details(uuid, text, integer, numeric, text, text) to authenticated;

notify pgrst, 'reload schema';
