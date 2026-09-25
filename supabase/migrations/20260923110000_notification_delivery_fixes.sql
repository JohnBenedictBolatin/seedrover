-- Deliver stock-status notifications to the relevant inventory audience rather
-- than only to the user who performed the stock movement.
create or replace function public.inventory_stock_status(
  p_quantity numeric,
  p_minimum_quantity numeric
)
returns text
language sql
immutable
as $$
  select case
    when p_quantity <= 0 then 'Out of Stock'
    when p_minimum_quantity > 0 and p_quantity <= p_minimum_quantity * 0.5 then 'Critical Stock'
    when p_minimum_quantity > 0 and p_quantity <= p_minimum_quantity then 'Low Stock'
    else 'In Stock'
  end;
$$;

create or replace function public.notify_inventory_stock_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  previous_status text;
  current_status text;
  notification_title text;
  minimum_text text;
begin
  previous_status := public.inventory_stock_status(old.quantity, old.minimum_quantity);
  current_status := public.inventory_stock_status(new.quantity, new.minimum_quantity);
  minimum_text := case
    when new.minimum_quantity > 0 then format(' Minimum level is %s %s.', new.minimum_quantity, new.unit)
    else ''
  end;

  if current_status not in ('Low Stock', 'Critical Stock', 'Out of Stock')
    or current_status is not distinct from previous_status then
    return new;
  end if;

  notification_title := current_status || ': ' || new.item_name;

  insert into public.notifications (
    recipient_id,
    actor_id,
    title,
    message,
    notification_type,
    action_route
  )
  select
    profile.id,
    auth.uid(),
    notification_title,
    new.item_name || ' needs replenishment. Current stock is '
      || new.quantity || ' ' || new.unit || '.' || minimum_text,
    'Inventory',
    '/inventory'
  from public.profiles profile
  join public.roles role on role.id = profile.role_id
  where profile.is_active
    and role.role_name in (
      'System Administrator',
      'Farm Inventory Manager',
      'Inventory Staff'
    )
    and profile.id is distinct from auth.uid();

  return new;
end;
$$;

drop trigger if exists inventory_notify_stock_status_change on public.inventory;
create trigger inventory_notify_stock_status_change
  after update of quantity, minimum_quantity on public.inventory
  for each row execute function public.notify_inventory_stock_status_change();
