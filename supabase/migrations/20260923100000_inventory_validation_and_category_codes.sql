-- Keep inventory item names unique and assign stock codes within their category.
-- Existing stock codes use these category prefixes:
-- LFY, FVG, LGM, RTC, FRT, HRB, PRP, and OTH.

create index if not exists inventory_item_name_normalized_idx
  on public.inventory (lower(btrim(item_name)));

create or replace function public.inventory_category_prefix(p_category text)
returns text
language plpgsql
immutable
as $$
begin
  return case btrim(p_category)
    when 'Leafy Vegetables' then 'LFY'
    when 'Fruit Vegetables' then 'FVG'
    when 'Legumes' then 'LGM'
    when 'Root Crops' then 'RTC'
    when 'Fruits' then 'FRT'
    when 'Herbs' then 'HRB'
    when 'Prepared Produce' then 'PRP'
    when 'Others' then 'OTH'
    else 'OTH'
  end;
end;
$$;

drop function if exists public.next_inventory_stock_code();

create or replace function public.next_inventory_stock_code(p_category text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  category_prefix text;
  code_pattern text;
  next_number integer;
begin
  category_prefix := public.inventory_category_prefix(p_category);
  code_pattern := '^STK-' || category_prefix || '-(\d+)$';

  perform pg_advisory_xact_lock(
    hashtext('inventory_stock_code:' || category_prefix)
  );

  select coalesce(max(substring(stock_code from code_pattern)::integer), 0) + 1
    into next_number
    from public.inventory
   where stock_code ~ code_pattern;

  return 'STK-' || category_prefix || '-' || lpad(next_number::text, 3, '0');
end;
$$;

revoke all on function public.next_inventory_stock_code(text) from public;
grant execute on function public.next_inventory_stock_code(text) to authenticated;

create or replace function public.assign_inventory_stock_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.stock_code is null or btrim(new.stock_code) = '' then
    new.stock_code := public.next_inventory_stock_code(new.category);
  end if;
  return new;
end;
$$;

drop trigger if exists inventory_assign_stock_code on public.inventory;
create trigger inventory_assign_stock_code
  before insert on public.inventory
  for each row execute function public.assign_inventory_stock_code();

-- Form validation is duplicated here so direct clients cannot create incomplete
-- inventory records. Legacy rows are left intact; this applies to new rows.
create or replace function public.validate_inventory_item_on_insert()
returns trigger
language plpgsql
as $$
begin
  if btrim(coalesce(new.item_name, '')) = '' then
    raise exception 'Item name is required.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('inventory_item_name:' || lower(btrim(new.item_name)))
  );

  if exists (
    select 1
    from public.inventory existing
    where lower(btrim(existing.item_name)) = lower(btrim(new.item_name))
  ) then
    raise exception 'An inventory item with this name already exists.';
  end if;

  if new.quantity is null or new.quantity < 0 then
    raise exception 'Quantity is required and must be non-negative.';
  end if;

  if btrim(coalesce(new.unit, '')) = '' then
    raise exception 'Unit is required.';
  end if;

  if new.minimum_quantity is null or new.minimum_quantity < 0 then
    raise exception 'Minimum stock level is required and must be non-negative.';
  end if;

  if btrim(coalesce(new.storage_location, '')) = '' then
    raise exception 'Storage location is required.';
  end if;

  if new.unit_cost is null or new.unit_cost < 0 then
    raise exception 'Unit cost is required and must be non-negative.';
  end if;

  if new.selling_price is null or new.selling_price < 0 then
    raise exception 'Selling price is required and must be non-negative.';
  end if;

  return new;
end;
$$;

drop trigger if exists inventory_validate_item_on_insert on public.inventory;
create trigger inventory_validate_item_on_insert
  before insert on public.inventory
  for each row execute function public.validate_inventory_item_on_insert();
