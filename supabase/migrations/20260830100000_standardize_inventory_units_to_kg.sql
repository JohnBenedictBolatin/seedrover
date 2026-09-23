-- Inventory quantities are measured exclusively in kilograms.

update public.inventory
set unit = 'kg'
where unit is distinct from 'kg';

update public.sales_order_items
set unit_snapshot = 'kg'
where unit_snapshot is distinct from 'kg';

update public.crop_activities
set unit = 'kg'
where activity_type = 'Harvested'
  and unit is distinct from 'kg';

update public.crop_harvests harvest
set unit = 'kg'
from public.inventory item
where harvest.inventory_id = item.id
  and harvest.unit is distinct from 'kg';

alter table public.inventory
  drop constraint if exists inventory_unit_allowed;

alter table public.inventory
  add constraint inventory_unit_allowed check (unit = 'kg');

alter table public.sales_order_items
  drop constraint if exists sales_order_items_unit_snapshot_allowed;

alter table public.sales_order_items
  add constraint sales_order_items_unit_snapshot_allowed
  check (unit_snapshot = 'kg');
