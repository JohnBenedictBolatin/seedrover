alter table public.profiles
  add column if not exists contact_number text;

grant update (
  full_name,
  role_id,
  is_active,
  contact_number,
  profile_image_path,
  updated_at
) on public.profiles to authenticated;

create unique index if not exists inventory_stock_code_unique
  on public.inventory (stock_code)
  where stock_code is not null;

create or replace function public.next_inventory_stock_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  next_number integer;
begin
  perform pg_advisory_xact_lock(hashtext('inventory_stock_code'));
  select coalesce(max(substring(stock_code from '^STK-(\d+)$')::integer), 0) + 1
    into next_number
    from public.inventory
   where stock_code ~ '^STK-\d+$';
  return 'STK-' || lpad(next_number::text, 3, '0');
end;
$$;

revoke all on function public.next_inventory_stock_code() from public;
grant execute on function public.next_inventory_stock_code() to authenticated;

create or replace function public.assign_inventory_stock_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.stock_code is null or btrim(new.stock_code) = '' then
    new.stock_code := public.next_inventory_stock_code();
  end if;
  return new;
end;
$$;

drop trigger if exists inventory_assign_stock_code on public.inventory;
create trigger inventory_assign_stock_code
  before insert on public.inventory
  for each row execute function public.assign_inventory_stock_code();
