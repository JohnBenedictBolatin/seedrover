-- Make harvest receipts visible in the inventory transaction ledger and repair
-- harvests recorded before the automatic stock workflow was installed.
create or replace function public.record_harvest_as_inventory_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  crop_row public.crops;
  inventory_row public.inventory;
  stock_quantity numeric;
  actor uuid;
begin
  if new.activity_type <> 'Harvested' then return new; end if;

  select * into crop_row from public.crops where id = new.crop_id;
  actor := coalesce(new.performed_by, crop_row.assigned_manager);
  stock_quantity := coalesce(nullif(new.quantity, 0), crop_row.completed_drop_cycles, 1);

  select * into inventory_row
  from public.inventory
  where lower(trim(item_name)) = lower(trim(crop_row.crop_name))
  order by created_at
  limit 1;

  if inventory_row.id is null then
    raise exception 'Create a % inventory item before completing this crop.', crop_row.crop_name;
  end if;
  if actor is null then
    raise exception 'The harvest must have a responsible user.';
  end if;
  if stock_quantity <= 0 then
    raise exception 'Harvest stock quantity must be greater than zero.';
  end if;

  if not exists (
       select 1 from public.inventory_transactions t
       where t.source = 'harvest' and t.source_id = new.id
     ) then
    insert into public.inventory_transactions (
      inventory_id, transaction_type, quantity, remarks, performed_by,
      source, source_id
    ) values (
      inventory_row.id, 'IN', stock_quantity,
      format('Harvest recorded from crop %s.', crop_row.batch_code), actor,
      'harvest', new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists crop_activities_record_harvest_stock on public.crop_activities;
create trigger crop_activities_record_harvest_stock
  after insert on public.crop_activities
  for each row execute function public.record_harvest_as_inventory_stock();

insert into public.inventory_transactions (
  inventory_id, transaction_type, quantity, remarks, performed_by, source, source_id
)
select
  i.id,
  'IN',
  coalesce(nullif(a.quantity, 0), c.completed_drop_cycles, 1),
  format('Harvest recorded from crop %s.', c.batch_code),
  coalesce(a.performed_by, c.assigned_manager),
  'harvest',
  a.id
from public.crop_activities a
join public.crops c on c.id = a.crop_id
join lateral (
  select inv.* from public.inventory inv
  where lower(trim(inv.item_name)) = lower(trim(c.crop_name))
  order by inv.created_at
  limit 1
) i on true
where a.activity_type = 'Harvested'
  and coalesce(nullif(a.quantity, 0), c.completed_drop_cycles, 1) > 0
  and coalesce(a.performed_by, c.assigned_manager) is not null
  and not exists (
    select 1 from public.inventory_transactions t
    where t.source = 'harvest' and t.source_id = a.id
  );
