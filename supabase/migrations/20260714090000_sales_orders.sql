create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  receipt_number text not null unique,
  sale_date timestamptz not null default now(),
  customer_name text,
  customer_contact text,
  payment_method text not null,
  subtotal numeric(12, 2) not null,
  discount_type text not null default 'None',
  discount_value numeric(12, 2) not null default 0,
  discount_amount numeric(12, 2) not null default 0,
  total_amount numeric(12, 2) not null,
  amount_paid numeric(12, 2),
  change_amount numeric(12, 2),
  remarks text,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'Completed',
  voided_at timestamptz,
  voided_by uuid references public.profiles(id) on delete restrict,
  void_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sales_orders_payment_method_allowed check (
    payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other')
  ),
  constraint sales_orders_discount_type_allowed check (
    discount_type in ('None', 'Amount', 'Percent')
  ),
  constraint sales_orders_status_allowed check (
    status in ('Completed', 'Voided')
  ),
  constraint sales_orders_amounts_non_negative check (
    subtotal >= 0
    and discount_value >= 0
    and discount_amount >= 0
    and total_amount >= 0
    and (amount_paid is null or amount_paid >= 0)
    and (change_amount is null or change_amount >= 0)
  )
);

create table if not exists public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  inventory_id uuid not null references public.inventory(id) on delete restrict,
  item_name_snapshot text not null,
  unit_snapshot text not null,
  quantity_sold numeric(12, 2) not null,
  unit_price numeric(12, 2) not null,
  line_total numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  constraint sales_order_items_quantity_positive check (quantity_sold > 0),
  constraint sales_order_items_amounts_non_negative check (
    unit_price >= 0
    and line_total >= 0
  )
);

create index if not exists sales_orders_sale_date_idx
  on public.sales_orders(sale_date);

create index if not exists sales_orders_recorded_by_idx
  on public.sales_orders(recorded_by);

create index if not exists sales_orders_status_idx
  on public.sales_orders(status);

create index if not exists sales_order_items_sales_order_id_idx
  on public.sales_order_items(sales_order_id);

create index if not exists sales_order_items_inventory_id_idx
  on public.sales_order_items(inventory_id);

drop trigger if exists sales_orders_set_updated_at
  on public.sales_orders;

create trigger sales_orders_set_updated_at
  before update on public.sales_orders
  for each row execute function public.set_updated_at();

alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;

drop policy if exists sales_orders_select_allowed
  on public.sales_orders;

create policy sales_orders_select_allowed
  on public.sales_orders
  for select
  to authenticated
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists sales_orders_insert_denied
  on public.sales_orders;

create policy sales_orders_insert_denied
  on public.sales_orders
  for insert
  to authenticated
  with check (false);

drop policy if exists sales_orders_update_allowed
  on public.sales_orders;

create policy sales_orders_update_allowed
  on public.sales_orders
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

drop policy if exists sales_orders_delete_denied
  on public.sales_orders;

create policy sales_orders_delete_denied
  on public.sales_orders
  for delete
  to authenticated
  using (false);

drop policy if exists sales_order_items_select_allowed
  on public.sales_order_items;

create policy sales_order_items_select_allowed
  on public.sales_order_items
  for select
  to authenticated
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists sales_order_items_insert_denied
  on public.sales_order_items;

create policy sales_order_items_insert_denied
  on public.sales_order_items
  for insert
  to authenticated
  with check (false);

drop policy if exists sales_order_items_update_denied
  on public.sales_order_items;

create policy sales_order_items_update_denied
  on public.sales_order_items
  for update
  to authenticated
  using (false);

drop policy if exists sales_order_items_delete_denied
  on public.sales_order_items;

create policy sales_order_items_delete_denied
  on public.sales_order_items
  for delete
  to authenticated
  using (false);

create or replace function public.record_sales_order(
  p_customer_name text,
  p_customer_contact text,
  p_payment_method text,
  p_discount_type text,
  p_discount_value numeric,
  p_amount_paid numeric,
  p_remarks text,
  p_items jsonb
)
returns public.sales_orders
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
  inventory_row public.inventory%rowtype;
  item jsonb;
  item_count integer;
  item_inventory_id uuid;
  item_quantity numeric(12, 2);
  item_unit_price numeric(12, 2);
  item_line_total numeric(12, 2);
  subtotal_value numeric(12, 2) := 0;
  discount_amount_value numeric(12, 2) := 0;
  total_value numeric(12, 2) := 0;
  change_value numeric(12, 2);
  receipt_value text;
begin
  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to record sales.';
  end if;

  if auth.uid() is null then
    raise exception 'Sign in before recording sales.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Sales items are required.';
  end if;

  item_count = jsonb_array_length(p_items);

  if item_count <= 0 then
    raise exception 'Add at least one item.';
  end if;

  if item_count > 50 then
    raise exception 'A receipt can contain up to 50 items.';
  end if;

  if p_payment_method not in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other') then
    raise exception 'Invalid payment method.';
  end if;

  if coalesce(p_discount_type, 'None') not in ('None', 'Amount', 'Percent') then
    raise exception 'Invalid discount type.';
  end if;

  for item in select value from jsonb_array_elements(p_items) loop
    item_inventory_id = (item ->> 'inventory_id')::uuid;
    item_quantity = (item ->> 'quantity')::numeric;
    item_unit_price = (item ->> 'unit_price')::numeric;

    if item_quantity is null or item_quantity <= 0 then
      raise exception 'Item quantity must be greater than zero.';
    end if;

    if item_unit_price is null or item_unit_price < 0 then
      raise exception 'Item price cannot be negative.';
    end if;

    select *
    into inventory_row
    from public.inventory
    where id = item_inventory_id
    for update;

    if not found then
      raise exception 'Inventory item was not found.';
    end if;

    if inventory_row.quantity < item_quantity then
      raise exception 'Insufficient stock for %.', inventory_row.item_name;
    end if;

    item_line_total = round(item_quantity * item_unit_price, 2);
    subtotal_value = subtotal_value + item_line_total;
  end loop;

  subtotal_value = round(subtotal_value, 2);

  if coalesce(p_discount_type, 'None') = 'Amount' then
    discount_amount_value = least(round(coalesce(p_discount_value, 0), 2), subtotal_value);
  elsif coalesce(p_discount_type, 'None') = 'Percent' then
    if coalesce(p_discount_value, 0) > 100 then
      raise exception 'Discount percent cannot be greater than 100.';
    end if;

    discount_amount_value = round(subtotal_value * coalesce(p_discount_value, 0) / 100, 2);
  end if;

  total_value = round(subtotal_value - discount_amount_value, 2);

  if p_amount_paid is not null and p_amount_paid < total_value then
    raise exception 'Amount paid cannot be lower than total amount.';
  end if;

  if p_amount_paid is not null then
    change_value = round(p_amount_paid - total_value, 2);
  end if;

  receipt_value = 'SR-' || to_char(now(), 'YYYYMMDD') || '-'
    || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.sales_orders (
    receipt_number,
    customer_name,
    customer_contact,
    payment_method,
    subtotal,
    discount_type,
    discount_value,
    discount_amount,
    total_amount,
    amount_paid,
    change_amount,
    remarks,
    recorded_by
  )
  values (
    receipt_value,
    nullif(trim(coalesce(p_customer_name, '')), ''),
    nullif(trim(coalesce(p_customer_contact, '')), ''),
    p_payment_method,
    subtotal_value,
    coalesce(p_discount_type, 'None'),
    coalesce(p_discount_value, 0),
    discount_amount_value,
    total_value,
    p_amount_paid,
    change_value,
    nullif(trim(coalesce(p_remarks, '')), ''),
    auth.uid()
  )
  returning * into order_row;

  for item in select value from jsonb_array_elements(p_items) loop
    item_inventory_id = (item ->> 'inventory_id')::uuid;
    item_quantity = (item ->> 'quantity')::numeric;
    item_unit_price = (item ->> 'unit_price')::numeric;

    select *
    into inventory_row
    from public.inventory
    where id = item_inventory_id
    for update;

    item_line_total = round(item_quantity * item_unit_price, 2);

    insert into public.sales_order_items (
      sales_order_id,
      inventory_id,
      item_name_snapshot,
      unit_snapshot,
      quantity_sold,
      unit_price,
      line_total
    )
    values (
      order_row.id,
      item_inventory_id,
      inventory_row.item_name,
      inventory_row.unit,
      item_quantity,
      item_unit_price,
      item_line_total
    );

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
      item_inventory_id,
      'OUT',
      item_quantity,
      'Sale receipt ' || order_row.receipt_number,
      auth.uid(),
      'sale',
      order_row.id
    );
  end loop;

  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values (
    auth.uid(),
    'Sales Receipt Recorded',
    order_row.receipt_number || ' recorded for PHP '
      || to_char(order_row.total_amount, 'FM9999999990.00') || '.',
    'Sales'
  );

  return order_row;
end;
$$;

grant execute on function public.record_sales_order(
  text,
  text,
  text,
  text,
  numeric,
  numeric,
  text,
  jsonb
) to authenticated;
