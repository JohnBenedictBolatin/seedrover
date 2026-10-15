begin;

create or replace function public.record_sales_order(
  p_customer_name text,
  p_customer_contact text,
  p_payment_method text,
  p_discount_type text,
  p_discount_value numeric,
  p_amount_paid numeric,
  p_remarks text,
  p_items jsonb,
  p_discount_code text default null,
  p_transaction_reference text default null,
  p_other_payment_method text default null
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
  normalized_reference text := nullif(trim(coalesce(p_transaction_reference, '')), '');
  normalized_other_method text := nullif(trim(coalesce(p_other_payment_method, '')), '');
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

  if p_payment_method <> 'Cash' and normalized_reference is null then
    raise exception 'Transaction ID is required for non-cash sales.';
  end if;

  if p_payment_method = 'Other' and normalized_other_method is null then
    raise exception 'Other payment method is required.';
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
    transaction_reference,
    other_payment_method,
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
    case when p_payment_method = 'Cash' then null else normalized_reference end,
    case when p_payment_method = 'Other' then normalized_other_method else null end,
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
      source_id,
      target_batch_id
    )
    values (
      item_inventory_id,
      'OUT',
      item_quantity,
      'Sale receipt ' || order_row.receipt_number,
      auth.uid(),
      'sale',
      order_row.id,
      nullif(item ->> 'batch_id', '')::uuid
    );
  end loop;

  return order_row;
end;
$$;
create or replace function public.record_inventory_sale_receipt(
  p_inventory_id uuid,
  p_quantity_sold numeric,
  p_unit_price numeric,
  p_sale_date timestamptz,
  p_customer_name text,
  p_customer_contact text,
  p_remarks text,
  p_payment_method text,
  p_transaction_reference text,
  p_other_payment_method text,
  p_target_batch_id uuid
)
returns public.sales_orders
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
begin
  p_customer_contact := public.normalize_contact_number(p_customer_contact);
  if p_customer_contact is null then
    raise exception 'Customer contact is required.';
  end if;

  order_row := public.record_sales_order(
    p_customer_name,
    p_customer_contact,
    p_payment_method,
    'None',
    0,
    round(p_quantity_sold * p_unit_price, 2),
    p_remarks,
    jsonb_build_array(jsonb_build_object(
      'inventory_id', p_inventory_id,
      'quantity', p_quantity_sold,
      'unit_price', p_unit_price,
      'batch_id', p_target_batch_id
    )),
    null,
    p_transaction_reference,
    p_other_payment_method
  );

  if p_sale_date is not null then
    update public.sales_orders
    set sale_date = p_sale_date
    where id = order_row.id
    returning * into order_row;

    update public.inventory_transactions
    set created_at = p_sale_date
    where source = 'sale'
      and source_id = order_row.id;
  end if;

  return order_row;
end;
$$;

revoke all on function public.record_sales_order(
  text, text, text, text, numeric, numeric, text, jsonb, text, text, text
) from public;
grant execute on function public.record_sales_order(
  text, text, text, text, numeric, numeric, text, jsonb, text, text, text
) to authenticated;

revoke all on function public.record_inventory_sale_receipt(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text, uuid
) from public;
grant execute on function public.record_inventory_sale_receipt(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text, uuid
) to authenticated;

commit;
