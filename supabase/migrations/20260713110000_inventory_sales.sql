alter table public.inventory
  add column if not exists unit_cost numeric(12, 2),
  add column if not exists selling_price numeric(12, 2);

alter table public.inventory
  drop constraint if exists inventory_unit_cost_non_negative,
  add constraint inventory_unit_cost_non_negative check (
    unit_cost is null or unit_cost >= 0
  );

alter table public.inventory
  drop constraint if exists inventory_selling_price_non_negative,
  add constraint inventory_selling_price_non_negative check (
    selling_price is null or selling_price >= 0
  );

alter table public.inventory_transactions
  add column if not exists source text not null default 'manual',
  add column if not exists source_id uuid;

alter table public.inventory_transactions
  drop constraint if exists inventory_transactions_source_allowed,
  add constraint inventory_transactions_source_allowed check (
    source in ('manual', 'sale', 'void_sale')
  );

create table if not exists public.sales_transactions (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.inventory(id) on delete restrict,
  quantity_sold numeric(12, 2) not null,
  unit_price numeric(12, 2) not null,
  total_amount numeric(12, 2) not null,
  sale_date timestamptz not null,
  customer_name text,
  remarks text,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'Completed',
  voided_at timestamptz,
  voided_by uuid references public.profiles(id) on delete restrict,
  void_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sales_transactions_quantity_positive check (quantity_sold > 0),
  constraint sales_transactions_unit_price_non_negative check (unit_price >= 0),
  constraint sales_transactions_total_amount_non_negative check (
    total_amount >= 0
  ),
  constraint sales_transactions_status_allowed check (
    status in ('Completed', 'Voided')
  ),
  constraint sales_transactions_void_fields_valid check (
    (
      status = 'Completed'
      and voided_at is null
      and voided_by is null
      and void_reason is null
    )
    or (
      status = 'Voided'
      and voided_at is not null
      and voided_by is not null
      and nullif(trim(void_reason), '') is not null
    )
  )
);

create index if not exists sales_transactions_inventory_id_idx
  on public.sales_transactions(inventory_id);

create index if not exists sales_transactions_recorded_by_idx
  on public.sales_transactions(recorded_by);

create index if not exists sales_transactions_sale_date_idx
  on public.sales_transactions(sale_date);

create index if not exists sales_transactions_status_idx
  on public.sales_transactions(status);

drop trigger if exists sales_transactions_set_updated_at
  on public.sales_transactions;

create trigger sales_transactions_set_updated_at
  before update on public.sales_transactions
  for each row execute function public.set_updated_at();

create or replace function public.protect_sales_transaction_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.inventory_id is distinct from old.inventory_id
    or new.quantity_sold is distinct from old.quantity_sold
    or new.unit_price is distinct from old.unit_price
    or new.total_amount is distinct from old.total_amount
    or new.sale_date is distinct from old.sale_date
    or new.recorded_by is distinct from old.recorded_by
    or new.created_at is distinct from old.created_at then
    raise exception 'Completed sale fields cannot be changed directly.';
  end if;

  return new;
end;
$$;

drop trigger if exists sales_transactions_protect_fields
  on public.sales_transactions;

create trigger sales_transactions_protect_fields
  before update on public.sales_transactions
  for each row execute function public.protect_sales_transaction_fields();

alter table public.sales_transactions enable row level security;

drop policy if exists sales_transactions_select_allowed
  on public.sales_transactions;

create policy sales_transactions_select_allowed
  on public.sales_transactions
  for select
  to authenticated
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists sales_transactions_insert_denied
  on public.sales_transactions;

create policy sales_transactions_insert_denied
  on public.sales_transactions
  for insert
  to authenticated
  with check (false);

drop policy if exists sales_transactions_update_allowed
  on public.sales_transactions;

create policy sales_transactions_update_allowed
  on public.sales_transactions
  for update
  to authenticated
  using (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  )
  with check (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  );

drop policy if exists sales_transactions_delete_denied
  on public.sales_transactions;

create policy sales_transactions_delete_denied
  on public.sales_transactions
  for delete
  to authenticated
  using (false);

insert into public.permissions (permission_key, module, description)
values
  ('stocks.sales.record', 'Stocks', 'Record inventory sales.'),
  ('stocks.pricing.manage', 'Stocks', 'Edit stock unit cost and selling price.')
on conflict (permission_key) do update
set
  module = excluded.module,
  description = excluded.description,
  updated_at = now();

create or replace function public.has_permission(requested_permission text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  with current_user_context as (
    select p.id, r.role_name
    from public.profiles p
    join public.roles r on r.id = p.role_id
    where p.id = auth.uid()
      and p.is_active
    limit 1
  )
  select exists (
    select 1
    from current_user_context c
    where c.role_name = 'System Administrator'
      or (
        c.role_name = 'Farm Planting Manager'
        and requested_permission = any(array[
          'dashboard.view',
          'rover.view',
          'rover.control',
          'rover.camera.view',
          'rover.planting.control',
          'crops.view',
          'crops.manage',
          'notifications.view',
          'profile.view',
          'profile.manage_self'
        ])
      )
      or (
        c.role_name = 'Farm Inventory Manager'
        and requested_permission = any(array[
          'dashboard.view',
          'stocks.view',
          'stocks.manage',
          'stocks.transactions.view',
          'stocks.sales.record',
          'stocks.pricing.manage',
          'notifications.view',
          'profile.view',
          'profile.manage_self'
        ])
      )
      or requested_permission = any(array[
        'profile.view',
        'profile.manage_self'
      ])
      or exists (
        select 1
        from public.profile_permissions pp
        join public.permissions perm on perm.id = pp.permission_id
        where pp.profile_id = c.id
          and perm.permission_key = requested_permission
      )
  );
$$;

create or replace function public.record_inventory_sale(
  p_inventory_id uuid,
  p_quantity_sold numeric,
  p_unit_price numeric,
  p_sale_date timestamptz,
  p_customer_name text default null,
  p_remarks text default null
)
returns public.sales_transactions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_inventory public.inventory%rowtype;
  completed_sale public.sales_transactions%rowtype;
  previous_quantity numeric(12, 2);
  next_quantity numeric(12, 2);
  previous_status text;
  next_status text;
  notification_title text;
begin
  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to record sales.';
  end if;

  if auth.uid() is null then
    raise exception 'Sign in before recording sales.';
  end if;

  if p_quantity_sold is null or p_quantity_sold <= 0 then
    raise exception 'Quantity sold must be greater than zero.';
  end if;

  if p_unit_price is null or p_unit_price < 0 then
    raise exception 'Unit price cannot be negative.';
  end if;

  if p_sale_date is null then
    raise exception 'Sale date is required.';
  end if;

  select *
  into current_inventory
  from public.inventory
  where id = p_inventory_id
  for update;

  if not found then
    raise exception 'Inventory item was not found.';
  end if;

  previous_quantity = current_inventory.quantity;

  if previous_quantity < p_quantity_sold then
    raise exception 'Insufficient stock for sale.';
  end if;

  previous_status = case
    when previous_quantity <= 0 then 'Out of Stock'
    when previous_quantity <= current_inventory.minimum_quantity * 0.5
      then 'Critical Stock'
    when previous_quantity <= current_inventory.minimum_quantity
      then 'Low Stock'
    else 'In Stock'
  end;

  insert into public.sales_transactions (
    inventory_id,
    quantity_sold,
    unit_price,
    total_amount,
    sale_date,
    customer_name,
    remarks,
    recorded_by
  )
  values (
    p_inventory_id,
    p_quantity_sold,
    p_unit_price,
    round(p_quantity_sold * p_unit_price, 2),
    p_sale_date,
    nullif(trim(coalesce(p_customer_name, '')), ''),
    nullif(trim(coalesce(p_remarks, '')), ''),
    auth.uid()
  )
  returning * into completed_sale;

  insert into public.inventory_transactions (
    inventory_id,
    transaction_type,
    quantity,
    remarks,
    performed_by,
    source,
    source_id
  )
  values (
    p_inventory_id,
    'OUT',
    p_quantity_sold,
    'Sale recorded: PHP ' || to_char(completed_sale.total_amount, 'FM9999999990.00'),
    auth.uid(),
    'sale',
    completed_sale.id
  );

  select quantity
  into next_quantity
  from public.inventory
  where id = p_inventory_id;

  next_status = case
    when next_quantity <= 0 then 'Out of Stock'
    when next_quantity <= current_inventory.minimum_quantity * 0.5
      then 'Critical Stock'
    when next_quantity <= current_inventory.minimum_quantity
      then 'Low Stock'
    else 'In Stock'
  end;

  update public.inventory
  set
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_inventory_id;

  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values (
    auth.uid(),
    'Sale Recorded',
    current_inventory.item_name || ': ' || p_quantity_sold || ' '
      || current_inventory.unit || ' sold for PHP '
      || to_char(completed_sale.total_amount, 'FM9999999990.00') || '.',
    'Stocks'
  );

  if next_status in ('Low Stock', 'Critical Stock', 'Out of Stock')
    and next_status is distinct from previous_status then
    notification_title = case next_status
      when 'Out of Stock' then 'Out of Stock'
      when 'Critical Stock' then 'Critical Stock'
      else 'Low Stock'
    end;

    insert into public.notifications (
      recipient_id,
      title,
      message,
      notification_type,
      action_route
    )
    values (
      auth.uid(),
      notification_title || ': ' || current_inventory.item_name,
      current_inventory.item_name || ' is now ' || lower(next_status) || '.',
      'Inventory',
      '/stocks/' || p_inventory_id
    );
  end if;

  return completed_sale;
end;
$$;

grant execute on function public.record_inventory_sale(
  uuid,
  numeric,
  numeric,
  timestamptz,
  text,
  text
) to authenticated;
