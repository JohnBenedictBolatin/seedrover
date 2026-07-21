create or replace function public.force_delete_inventory_item(
  p_inventory_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_item public.inventory%rowtype;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Sign in before deleting inventory items.';
  end if;

  if not public.is_admin() then
    raise exception 'Only system administrators can delete inventory items.';
  end if;

  select *
    into target_item
  from public.inventory
  where id = p_inventory_id
  for update;

  if target_item.id is null then
    raise exception 'Inventory item was not found.';
  end if;

  create temporary table if not exists force_delete_sales_orders (
    id uuid primary key
  ) on commit drop;

  truncate table force_delete_sales_orders;

  insert into force_delete_sales_orders (id)
  select distinct sales_order_id
  from public.sales_order_items
  where inventory_id = p_inventory_id;

  -- Remove full receipts that referenced the deleted item so receipt totals do not become inconsistent.
  delete from public.sales_order_items item
  using force_delete_sales_orders orders
  where item.sales_order_id = orders.id;

  delete from public.sales_orders sales_order
  using force_delete_sales_orders orders
  where sales_order.id = orders.id;

  -- Remove legacy market-distribution sales linked directly to the stock item.
  delete from public.sales_transactions
  where inventory_id = p_inventory_id;

  -- Remove crop harvest links before deleting the stock item.
  delete from public.crop_harvests
  where inventory_id = p_inventory_id;

  -- Remove movement records explicitly. Some schemas cascade this, but direct deletion is clearer.
  delete from public.inventory_transactions
  where inventory_id = p_inventory_id;

  delete from public.inventory
  where id = p_inventory_id;

  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values (
    current_user_id,
    'Inventory item force deleted',
    target_item.item_name || ' and related stock/sales references were removed from the inventory list.',
    'Stocks'
  );
end;
$$;

revoke all on function public.force_delete_inventory_item(uuid) from public;
grant execute on function public.force_delete_inventory_item(uuid) to authenticated;
