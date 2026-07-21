create or replace function public.safe_activity_log(
  p_user_id uuid,
  p_activity text,
  p_description text,
  p_module text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values (
    p_user_id,
    p_activity,
    p_description,
    p_module
  );
exception
  when others then
    null;
end;
$$;

create or replace function public.safe_notification(
  p_recipient_id uuid,
  p_title text,
  p_message text,
  p_notification_type text,
  p_action_route text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (
    recipient_id,
    title,
    message,
    notification_type,
    action_route
  )
  values (
    p_recipient_id,
    p_title,
    p_message,
    p_notification_type,
    p_action_route
  );
exception
  when others then
    null;
end;
$$;

create or replace function public.void_sales_record(
  p_id uuid,
  p_source text,
  p_reason text default 'Voided from SeedRover.'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  receipt_row public.sales_orders%rowtype;
  standalone_row public.sales_transactions%rowtype;
  order_item record;
  clean_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if current_user_id is null then
    raise exception 'Sign in before voiding sales.';
  end if;

  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to void sales.';
  end if;

  clean_reason = coalesce(clean_reason, 'Voided from SeedRover.');

  if p_id is null then
    raise exception 'Missing sales record.';
  end if;

  if p_source = 'receipt' then
    select *
    into receipt_row
    from public.sales_orders
    where id = p_id
    for update;

    if not found then
      raise exception 'Receipt was not found.';
    end if;

    if receipt_row.status <> 'Completed' then
      raise exception 'Only completed receipts can be voided.';
    end if;

    update public.sales_orders
    set
      status = 'Voided',
      voided_at = now(),
      voided_by = current_user_id,
      void_reason = clean_reason
    where id = receipt_row.id
      and status = 'Completed';

    if not found then
      raise exception 'Receipt could not be voided. Please refresh and try again.';
    end if;

    for order_item in
      select inventory_id, quantity_sold
      from public.sales_order_items
      where sales_order_id = receipt_row.id
    loop
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
        order_item.inventory_id,
        'IN',
        order_item.quantity_sold,
        'Voided receipt ' || receipt_row.receipt_number || ': ' || clean_reason,
        current_user_id,
        'void_sale',
        receipt_row.id
      );
    end loop;

    update public.customer_discounts
    set
      status = 'Released',
      used_at = null,
      used_by = null,
      used_sales_order_id = null
    where used_sales_order_id = receipt_row.id;

    perform public.safe_activity_log(
      current_user_id,
      'Sales receipt voided',
      'Receipt ' || receipt_row.receipt_number || ' was voided. Reason: ' || clean_reason,
      'Sales'
    );

    return jsonb_build_object(
      'source', 'receipt',
      'id', receipt_row.id,
      'receiptNumber', receipt_row.receipt_number
    );
  elsif p_source = 'market' then
    select *
    into standalone_row
    from public.sales_transactions
    where id = p_id
    for update;

    if not found then
      raise exception 'Market distribution sale was not found.';
    end if;

    if standalone_row.status <> 'Completed' then
      raise exception 'Only completed market sales can be voided.';
    end if;

    update public.sales_transactions
    set
      status = 'Voided',
      voided_at = now(),
      voided_by = current_user_id,
      void_reason = clean_reason
    where id = standalone_row.id
      and status = 'Completed';

    if not found then
      raise exception 'Market distribution sale could not be voided. Please refresh and try again.';
    end if;

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
      standalone_row.inventory_id,
      'IN',
      standalone_row.quantity_sold,
      'Voided market distribution: ' || clean_reason,
      current_user_id,
      'void_sale',
      standalone_row.id
    );

    perform public.safe_activity_log(
      current_user_id,
      'Market distribution voided',
      'Market distribution sale was voided. Reason: ' || clean_reason,
      'Sales'
    );

    return jsonb_build_object(
      'source', 'market',
      'id', standalone_row.id
    );
  end if;

  raise exception 'Unknown sales source.';
end;
$$;

create or replace function public.harvest_crop_to_inventory(
  p_crop_id uuid,
  p_inventory_id uuid,
  p_quantity numeric,
  p_harvest_date date,
  p_remarks text default null
)
returns public.crops
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  crop_row public.crops%rowtype;
  inventory_row public.inventory%rowtype;
  harvest_row public.crop_harvests%rowtype;
  clean_remarks text := nullif(trim(coalesce(p_remarks, '')), '');
  harvest_note text;
begin
  if current_user_id is null then
    raise exception 'Sign in before recording harvest.';
  end if;

  if not public.has_permission('crops.manage') then
    raise exception 'Not allowed to record crop harvests.';
  end if;

  if p_crop_id is null or p_inventory_id is null then
    raise exception 'Choose the crop and inventory item for this harvest.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Harvest quantity must be greater than zero.';
  end if;

  if p_harvest_date is null then
    raise exception 'Harvest date is required.';
  end if;

  if p_harvest_date > current_date then
    raise exception 'Harvest date cannot be in the future.';
  end if;

  clean_remarks = coalesce(clean_remarks, 'Harvest recorded.');

  select *
  into crop_row
  from public.crops
  where id = p_crop_id
  for update;

  if not found then
    raise exception 'Crop record was not found.';
  end if;

  select *
  into inventory_row
  from public.inventory
  where id = p_inventory_id
  for update;

  if not found then
    raise exception 'Inventory item was not found.';
  end if;

  insert into public.crop_harvests (
    crop_id,
    inventory_id,
    quantity,
    unit,
    harvest_date,
    harvested_by,
    remarks
  )
  values (
    crop_row.id,
    inventory_row.id,
    p_quantity,
    inventory_row.unit,
    p_harvest_date,
    current_user_id,
    clean_remarks
  )
  returning * into harvest_row;

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
    inventory_row.id,
    'IN',
    p_quantity,
    'Harvest from ' || crop_row.crop_name || ': ' || clean_remarks,
    current_user_id,
    'harvest',
    harvest_row.id
  );

  harvest_note =
    to_char(p_harvest_date, 'YYYY-MM-DD')
    || ' - Harvested '
    || trim(to_char(p_quantity, 'FM9999999990.##'))
    || ' '
    || inventory_row.unit
    || ' into '
    || inventory_row.item_name
    || '. '
    || clean_remarks;

  update public.crops
  set
    growth_stage = 'Completed',
    crop_status = 'Completed',
    maintenance_notes = concat_ws(
      E'\n',
      nullif(trim(coalesce(crop_row.maintenance_notes, '')), ''),
      harvest_note
    ),
    updated_at = now()
  where id = crop_row.id
  returning * into crop_row;

  perform public.safe_activity_log(
    current_user_id,
    'Crop harvest recorded',
    crop_row.crop_name || ' harvest added to ' || inventory_row.item_name || ' inventory.',
    'Crops'
  );

  perform public.safe_notification(
    current_user_id,
    'Harvest added to inventory',
    trim(to_char(p_quantity, 'FM9999999990.##')) || ' ' || inventory_row.unit || ' of ' || crop_row.crop_name || ' was added to ' || inventory_row.item_name || '.',
    'Inventory',
    '/stocks'
  );

  return crop_row;
end;
$$;

revoke all on function public.safe_activity_log(uuid, text, text, text) from public;
revoke all on function public.safe_activity_log(uuid, text, text, text) from authenticated;
revoke all on function public.safe_notification(uuid, text, text, text, text) from public;
revoke all on function public.safe_notification(uuid, text, text, text, text) from authenticated;
grant execute on function public.void_sales_record(uuid, text, text) to authenticated;
grant execute on function public.harvest_crop_to_inventory(uuid, uuid, numeric, date, text) to authenticated;
