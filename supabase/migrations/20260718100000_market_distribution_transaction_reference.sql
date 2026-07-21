alter table public.sales_transactions
  add column if not exists transaction_reference text;

drop function if exists public.record_inventory_sale(
  uuid,
  numeric,
  numeric,
  timestamptz,
  text,
  text,
  text
);

drop function if exists public.record_inventory_sale(
  uuid,
  numeric,
  numeric,
  timestamptz,
  text,
  text
);

create or replace function public.record_inventory_sale(
  p_inventory_id uuid,
  p_quantity_sold numeric,
  p_unit_price numeric,
  p_sale_date timestamptz,
  p_customer_name text default null,
  p_remarks text default null,
  p_payment_method text default 'Cash',
  p_transaction_reference text default null
)
returns public.sales_transactions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_inventory public.inventory%rowtype;
  completed_sale public.sales_transactions%rowtype;
  normalized_reference text;
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

  normalized_reference = nullif(trim(coalesce(p_transaction_reference, '')), '');

  if p_payment_method <> 'Cash' and normalized_reference is null then
    raise exception 'Transaction ID is required for non-cash market distribution sales.';
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
    transaction_reference,
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
    case when p_payment_method = 'Cash' then null else normalized_reference end,
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

grant execute on function public.record_inventory_sale(
  uuid,
  numeric,
  numeric,
  timestamptz,
  text,
  text,
  text,
  text
) to authenticated;
