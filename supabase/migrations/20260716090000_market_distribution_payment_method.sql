alter table public.sales_transactions
  add column if not exists payment_method text;

alter table public.sales_transactions
  drop constraint if exists sales_transactions_payment_method_allowed,
  add constraint sales_transactions_payment_method_allowed check (
    payment_method is null
    or payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other')
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
  text,
  text
) to authenticated;
