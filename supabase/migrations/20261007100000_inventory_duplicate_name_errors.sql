-- Keep inventory duplicate-name feedback short and consistent across clients.
-- On updates, validate the name only when it changes so unrelated edits do not
-- fail for legacy rows that predate current validation rules.
create or replace function public.validate_inventory_item_on_insert()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if btrim(coalesce(new.item_name, '')) = '' then
      raise exception 'Item name is required.';
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
  elsif new.item_name is distinct from old.item_name
      and btrim(coalesce(new.item_name, '')) = '' then
    raise exception 'Item name is required.';
  end if;

  if tg_op = 'INSERT' or new.item_name is distinct from old.item_name then
    perform pg_advisory_xact_lock(
      hashtext('inventory_item_name:' || lower(btrim(new.item_name)))
    );

    if exists (
      select 1
      from public.inventory existing
      where lower(btrim(existing.item_name)) = lower(btrim(new.item_name))
        and (tg_op = 'INSERT' or existing.id <> new.id)
    ) then
      raise exception 'Item already exists.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists inventory_validate_item_on_insert on public.inventory;
create trigger inventory_validate_item_on_insert
  before insert or update on public.inventory
  for each row execute function public.validate_inventory_item_on_insert();