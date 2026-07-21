create extension if not exists "pgcrypto";

alter table public.inventory
  add column if not exists stock_code text,
  add column if not exists unit_cost numeric(12, 2),
  add column if not exists selling_price numeric(12, 2),
  add column if not exists image_path text;

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
  payment_method text,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'Completed',
  voided_at timestamptz,
  voided_by uuid references public.profiles(id) on delete restrict,
  void_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.sales_transactions
  add column if not exists payment_method text,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.profiles(id) on delete restrict,
  add column if not exists void_reason text;

alter table public.sales_transactions
  drop constraint if exists sales_transactions_payment_method_allowed,
  add constraint sales_transactions_payment_method_allowed check (
    payment_method is null
    or payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other')
  ),
  drop constraint if exists sales_transactions_status_allowed,
  add constraint sales_transactions_status_allowed check (
    status in ('Completed', 'Voided')
  );

create index if not exists sales_transactions_inventory_id_idx
  on public.sales_transactions(inventory_id);

create index if not exists sales_transactions_sale_date_idx
  on public.sales_transactions(sale_date);

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
  updated_at timestamptz not null default now()
);

alter table public.sales_orders
  add column if not exists customer_contact text,
  add column if not exists amount_paid numeric(12, 2),
  add column if not exists change_amount numeric(12, 2),
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.profiles(id) on delete restrict,
  add column if not exists void_reason text;

alter table public.sales_orders
  drop constraint if exists sales_orders_payment_method_allowed,
  add constraint sales_orders_payment_method_allowed check (
    payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other')
  ),
  drop constraint if exists sales_orders_discount_type_allowed,
  add constraint sales_orders_discount_type_allowed check (
    discount_type in ('None', 'Amount', 'Percent')
  ),
  drop constraint if exists sales_orders_status_allowed,
  add constraint sales_orders_status_allowed check (
    status in ('Completed', 'Voided')
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
  created_at timestamptz not null default now()
);

create index if not exists sales_orders_sale_date_idx
  on public.sales_orders(sale_date);

create index if not exists sales_order_items_sales_order_id_idx
  on public.sales_order_items(sales_order_id);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_key text not null unique,
  display_name text not null,
  contact_number text,
  alternate_contact text,
  customer_type text not null default 'Farm Buyer',
  tags text[] not null default '{}',
  notes text,
  location text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.customers
  drop constraint if exists customers_type_allowed,
  add constraint customers_type_allowed check (
    customer_type in ('Farm Buyer', 'Market Buyer', 'Wholesale', 'Restaurant', 'Retail', 'Other')
  );

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
  updated_at timestamptz not null default now()
);

alter table public.customer_discounts
  drop constraint if exists customer_discounts_type_allowed,
  add constraint customer_discounts_type_allowed check (discount_type in ('Amount', 'Percent')),
  drop constraint if exists customer_discounts_status_allowed,
  add constraint customer_discounts_status_allowed check (status in ('Released', 'Used', 'Cancelled')),
  drop constraint if exists customer_discounts_value_positive,
  add constraint customer_discounts_value_positive check (discount_value > 0),
  drop constraint if exists customer_discounts_percent_max,
  add constraint customer_discounts_percent_max check (
    discount_type <> 'Percent' or discount_value <= 100
  );

alter table public.customer_discounts
  drop constraint if exists customer_discounts_used_sales_order_fk,
  add constraint customer_discounts_used_sales_order_fk
  foreign key (used_sales_order_id) references public.sales_orders(id) on delete set null;

alter table public.sales_orders
  add column if not exists customer_discount_id uuid references public.customer_discounts(id) on delete set null,
  add column if not exists discount_code text;

create index if not exists customers_customer_key_idx
  on public.customers(customer_key);

create index if not exists customer_discounts_code_idx
  on public.customer_discounts(discount_code);

create index if not exists customer_discounts_status_idx
  on public.customer_discounts(status);

create index if not exists customer_discounts_customer_key_idx
  on public.customer_discounts(customer_key);

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

drop trigger if exists customer_discounts_set_updated_at on public.customer_discounts;
create trigger customer_discounts_set_updated_at
  before update on public.customer_discounts
  for each row execute function public.set_updated_at();

alter table public.sales_transactions enable row level security;
alter table public.sales_orders enable row level security;
alter table public.sales_order_items enable row level security;
alter table public.customers enable row level security;
alter table public.customer_discounts enable row level security;

drop policy if exists customers_select_allowed on public.customers;
create policy customers_select_allowed
  on public.customers
  for select
  to authenticated
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
    or public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customers_insert_allowed on public.customers;
create policy customers_insert_allowed
  on public.customers
  for insert
  to authenticated
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customers_update_allowed on public.customers;
create policy customers_update_allowed
  on public.customers
  for update
  to authenticated
  using (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  )
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customer_discounts_select_allowed on public.customer_discounts;
create policy customer_discounts_select_allowed
  on public.customer_discounts
  for select
  to authenticated
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
  to authenticated
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customer_discounts_update_allowed on public.customer_discounts;
create policy customer_discounts_update_allowed
  on public.customer_discounts
  for update
  to authenticated
  using (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  )
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

create or replace function public.record_inventory_sale(
  p_inventory_id uuid,
  p_quantity_sold numeric,
  p_unit_price numeric,
  p_sale_date timestamptz,
  p_customer_name text default null,
  p_remarks text default null,
  p_payment_method text default 'Cash'
)
returns public.sales_transactions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_inventory public.inventory%rowtype;
  completed_sale public.sales_transactions%rowtype;
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

  if p_payment_method not in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other') then
    raise exception 'Invalid payment method.';
  end if;

  select *
  into current_inventory
  from public.inventory
  where id = p_inventory_id
  for update;

  if not found then
    raise exception 'Inventory item was not found.';
  end if;

  if current_inventory.quantity < p_quantity_sold then
    raise exception 'Insufficient stock for sale.';
  end if;

  insert into public.sales_transactions (
    inventory_id,
    quantity_sold,
    unit_price,
    total_amount,
    sale_date,
    customer_name,
    remarks,
    payment_method,
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
    p_payment_method,
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

  update public.inventory
  set
    updated_by = auth.uid(),
    updated_at = now()
  where id = p_inventory_id;

  return completed_sale;
end;
$$;

create or replace function public.record_sales_order(
  p_customer_name text,
  p_customer_contact text,
  p_payment_method text,
  p_discount_type text,
  p_discount_value numeric,
  p_amount_paid numeric,
  p_remarks text,
  p_items jsonb,
  p_discount_code text default null
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

  return order_row;
end;
$$;

grant execute on function public.record_inventory_sale(
  uuid,
  numeric,
  numeric,
  timestamptz,
  text,
  text,
  text
) to authenticated;

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
