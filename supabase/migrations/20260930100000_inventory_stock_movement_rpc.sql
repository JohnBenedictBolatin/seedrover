create or replace function public.record_inventory_movement(
  p_inventory_id uuid,
  p_transaction_type text,
  p_quantity numeric,
  p_reason text default null,
  p_remarks text default null
)
returns public.inventory_transactions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  inventory_row public.inventory%rowtype;
  movement_row public.inventory_transactions%rowtype;
  clean_reason text := nullif(trim(coalesce(p_reason, '')), '');
  clean_remarks text := nullif(trim(coalesce(p_remarks, '')), '');
  movement_remarks text;
begin
  if current_user_id is null then
    raise exception 'Sign in before changing inventory.';
  end if;

  if not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to change inventory stock.';
  end if;

  if p_transaction_type not in ('IN', 'OUT', 'ADJUSTMENT') then
    raise exception 'Choose a valid inventory movement type.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero.';
  end if;

  select *
    into inventory_row
    from public.inventory
   where id = p_inventory_id
   for update;

  if not found then
    raise exception 'Inventory item was not found.';
  end if;

  if inventory_row.unit <> 'kg' then
    raise exception 'Inventory quantities must use kg as the unit. Update this item before stocking it.';
  end if;

  if p_transaction_type = 'OUT' and inventory_row.quantity < p_quantity then
    raise exception 'Insufficient stock for inventory transaction.';
  end if;

  movement_remarks := concat_ws(
    E'\n',
    case
      when clean_reason is null then null
      when p_transaction_type = 'IN' then 'Source: ' || clean_reason
      else 'Reason: ' || clean_reason
    end,
    coalesce(
      clean_remarks,
      case p_transaction_type
        when 'IN' then 'Stock received.'
        when 'OUT' then 'Stock issued.'
        else 'Stock adjusted.'
      end
    )
  );

  insert into public.inventory_transactions (
    inventory_id,
    transaction_type,
    quantity,
    remarks,
    source,
    performed_by
  )
  values (
    p_inventory_id,
    p_transaction_type,
    p_quantity,
    movement_remarks,
    'manual',
    current_user_id
  )
  returning * into movement_row;

  return movement_row;
end;
$$;

revoke all on function public.record_inventory_movement(uuid, text, numeric, text, text)
  from public;
grant execute on function public.record_inventory_movement(uuid, text, numeric, text, text)
  to authenticated;
