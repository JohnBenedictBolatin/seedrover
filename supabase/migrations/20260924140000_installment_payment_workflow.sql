-- Comprehensive installment plans, scheduled periods, and payment history.
create table if not exists public.installment_plans (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null unique references public.sales_orders(id) on delete cascade,
  customer_name text not null,
  customer_contact text,
  receipt_number text not null,
  frequency text not null,
  payment_amount numeric(12, 2) not null,
  total_amount numeric(12, 2) not null,
  initial_payment numeric(12, 2) not null default 0,
  financed_amount numeric(12, 2) not null,
  status text not null default 'Active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint installment_plans_frequency_allowed check (frequency in ('Weekly', 'Monthly', 'Yearly')),
  constraint installment_plans_status_allowed check (status in ('Active', 'Completed', 'Cancelled')),
  constraint installment_plans_amounts_valid check (
    payment_amount > 0
    and total_amount > 0
    and initial_payment >= 0
    and financed_amount >= 0
    and initial_payment <= total_amount
  )
);

create table if not exists public.installment_schedule (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.installment_plans(id) on delete cascade,
  installment_number integer not null,
  due_date date not null,
  scheduled_amount numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  constraint installment_schedule_amount_positive check (scheduled_amount > 0),
  constraint installment_schedule_number_positive check (installment_number > 0),
  constraint installment_schedule_plan_number_unique unique (plan_id, installment_number)
);

create table if not exists public.installment_payments (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.installment_plans(id) on delete cascade,
  schedule_id uuid not null references public.installment_schedule(id) on delete cascade,
  amount numeric(12, 2) not null,
  payment_date date not null default current_date,
  payment_method text not null,
  transaction_reference text,
  other_payment_method text,
  notes text,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint installment_payments_amount_positive check (amount > 0),
  constraint installment_payments_method_allowed check (payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other')),
  constraint installment_payments_other_method_valid check (
    payment_method <> 'Other' or nullif(btrim(other_payment_method), '') is not null
  )
);

alter table public.installment_plans enable row level security;
alter table public.installment_schedule enable row level security;
alter table public.installment_payments enable row level security;

drop policy if exists installment_plans_select_allowed on public.installment_plans;
create policy installment_plans_select_allowed
  on public.installment_plans for select to authenticated
  using (
    public.is_admin()
    or public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists installment_schedule_select_allowed on public.installment_schedule;
create policy installment_schedule_select_allowed
  on public.installment_schedule for select to authenticated
  using (
    public.is_admin()
    or public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists installment_payments_select_allowed on public.installment_payments;
create policy installment_payments_select_allowed
  on public.installment_payments for select to authenticated
  using (
    public.is_admin()
    or public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

revoke insert, update, delete on public.installment_plans from authenticated;
revoke insert, update, delete on public.installment_schedule from authenticated;
revoke insert, update, delete on public.installment_payments from authenticated;
grant select on public.installment_plans, public.installment_schedule, public.installment_payments to authenticated;

create index if not exists installment_schedule_plan_due_date_idx
  on public.installment_schedule(plan_id, due_date);
create index if not exists installment_payments_schedule_idx
  on public.installment_payments(schedule_id, payment_date);

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
  schedule_id_value uuid;
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
      recorded_by
    )
    values (
      plan_row.id,
      schedule_row.id,
      allocation_amount,
      order_row.sale_date::date,
      p_initial_payment_method,
      case when p_initial_payment_method = 'Other' then 'Initial installment payment' else null end,
      'Initial payment applied to installment schedule.',
      auth.uid()
    );

    allocation_remaining := round(allocation_remaining - allocation_amount, 2);
  end loop;

  return plan_row;
end;
$$;

create or replace function public.record_installment_payment(
  p_schedule_id uuid,
  p_amount numeric,
  p_payment_date date default current_date,
  p_payment_method text default 'Cash',
  p_transaction_reference text default null,
  p_other_payment_method text default null,
  p_notes text default null
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

create or replace function public.cancel_installment_plan_on_void()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'Voided' and old.status is distinct from 'Voided' then
    update public.installment_plans
    set status = 'Cancelled', updated_at = now()
    where sales_order_id = new.id and status <> 'Completed';
  end if;
  return new;
end;
$$;

drop trigger if exists sales_orders_cancel_installment_plan on public.sales_orders;
create trigger sales_orders_cancel_installment_plan
  after update of status on public.sales_orders
  for each row execute function public.cancel_installment_plan_on_void();

revoke all on function public.create_installment_plan(uuid, text, numeric, numeric, text) from public;
grant execute on function public.create_installment_plan(uuid, text, numeric, numeric, text) to authenticated;
revoke all on function public.record_installment_payment(uuid, numeric, date, text, text, text, text) from public;
grant execute on function public.record_installment_payment(uuid, numeric, date, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
