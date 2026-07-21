create table if not exists public.customer_discounts (
  id uuid primary key default gen_random_uuid(),
  discount_code text not null unique,
  customer_key text not null,
  customer_name text not null,
  customer_contact text,
  discount_type text not null,
  discount_value numeric(12, 2) not null,
  valid_until date,
  notes text,
  status text not null default 'Released',
  released_by uuid references public.profiles(id) on delete set null,
  used_by uuid references public.profiles(id) on delete set null,
  used_sales_order_id uuid,
  released_at timestamptz not null default now(),
  used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_discounts_type_allowed check (discount_type in ('Amount', 'Percent')),
  constraint customer_discounts_status_allowed check (status in ('Released', 'Used', 'Cancelled')),
  constraint customer_discounts_value_positive check (discount_value > 0),
  constraint customer_discounts_percent_max check (
    discount_type <> 'Percent' or discount_value <= 100
  )
);

alter table public.customer_discounts
  add constraint customer_discounts_used_sales_order_fk
  foreign key (used_sales_order_id) references public.sales_orders(id) on delete set null;

alter table public.sales_orders
  add column if not exists customer_discount_id uuid references public.customer_discounts(id) on delete set null,
  add column if not exists discount_code text;

create index if not exists customer_discounts_code_idx
  on public.customer_discounts(discount_code);

create index if not exists customer_discounts_status_idx
  on public.customer_discounts(status);

create index if not exists customer_discounts_customer_key_idx
  on public.customer_discounts(customer_key);

drop trigger if exists customer_discounts_set_updated_at on public.customer_discounts;
create trigger customer_discounts_set_updated_at
  before update on public.customer_discounts
  for each row execute function public.set_updated_at();

alter table public.customer_discounts enable row level security;

drop policy if exists customer_discounts_select_allowed on public.customer_discounts;
create policy customer_discounts_select_allowed
  on public.customer_discounts
  for select
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
    or public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customer_discounts_insert_allowed on public.customer_discounts;
create policy customer_discounts_insert_allowed
  on public.customer_discounts
  for insert
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customer_discounts_update_allowed on public.customer_discounts;
create policy customer_discounts_update_allowed
  on public.customer_discounts
  for update
  using (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  )
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customer_discounts_delete_denied on public.customer_discounts;
create policy customer_discounts_delete_denied
  on public.customer_discounts
  for delete
  using (false);

create or replace function public.record_sales_order(
  p_customer_name text,
  p_customer_contact text,
  p_payment_method text,
  p_discount_type text,
  p_discount_value numeric,
  p_amount_paid numeric,
  p_remarks text,
  p_items jsonb,
  p_discount_code text
)
returns public.sales_orders
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
  inventory_row public.inventory%rowtype;
  discount_row public.customer_discounts%rowtype;
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
  normalized_discount_code text := upper(nullif(trim(coalesce(p_discount_code, '')), ''));
  applied_discount_type text := 'None';
  applied_discount_value numeric(12, 2) := 0;
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

  if normalized_discount_code is not null then
    select *
    into discount_row
    from public.customer_discounts
    where discount_code = normalized_discount_code
    for update;

    if not found then
      raise exception 'Discount code was not found.';
    end if;

    if discount_row.status <> 'Released' then
      raise exception 'Discount code is no longer available.';
    end if;

    if discount_row.valid_until is not null and discount_row.valid_until < current_date then
      raise exception 'Discount code is expired.';
    end if;

    if nullif(trim(coalesce(p_customer_name, '')), '') is not null
      and lower(trim(discount_row.customer_name)) <> lower(trim(p_customer_name)) then
      raise exception 'Discount code is assigned to another customer.';
    end if;

    applied_discount_type = discount_row.discount_type;
    applied_discount_value = discount_row.discount_value;

    if discount_row.discount_type = 'Amount' then
      discount_amount_value = least(round(discount_row.discount_value, 2), subtotal_value);
    else
      discount_amount_value = round(subtotal_value * discount_row.discount_value / 100, 2);
    end if;
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
    discount_code,
    customer_discount_id,
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
    applied_discount_type,
    applied_discount_value,
    discount_amount_value,
    normalized_discount_code,
    case when normalized_discount_code is null then null else discount_row.id end,
    total_value,
    p_amount_paid,
    change_value,
    nullif(trim(coalesce(p_remarks, '')), ''),
    auth.uid()
  )
  returning * into order_row;

  if normalized_discount_code is not null then
    update public.customer_discounts
    set status = 'Used',
        used_at = now(),
        used_by = auth.uid(),
        used_sales_order_id = order_row.id
    where id = discount_row.id;
  end if;

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
  jsonb,
  text
) to authenticated;
