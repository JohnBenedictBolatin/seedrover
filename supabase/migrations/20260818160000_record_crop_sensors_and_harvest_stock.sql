-- Preserve the rover's planting-time readings as crop-linked sensor history.
create or replace function public.capture_rover_planting_sensor_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sensor_readings (
    soil_moisture,
    soil_temperature,
    environmental_temperature,
    humidity,
    recorded_at,
    rover_id,
    crop_id,
    planting_log_id,
    soil_raw,
    calibrated_value,
    source
  )
  select
    greatest(0, least(100, coalesce(pl.soil_moisture_percent, 0))),
    coalesce(pl.environmental_temperature, 0),
    coalesce(pl.environmental_temperature, 0),
    0,
    coalesce(pl.completed_at, pl.started_at, now()),
    pl.rover_id,
    new.id,
    pl.id,
    pl.soil_raw,
    greatest(0, least(100, coalesce(pl.soil_moisture_percent, 0))),
    'Hardware'
  from public.planting_logs pl
  where pl.id = new.planting_log_id
    and not exists (
      select 1 from public.sensor_readings sr
      where sr.planting_log_id = pl.id
    );
  return new;
end;
$$;

drop trigger if exists crops_capture_rover_sensor_snapshot on public.crops;
create trigger crops_capture_rover_sensor_snapshot
  after insert on public.crops
  for each row execute function public.capture_rover_planting_sensor_snapshot();

insert into public.sensor_readings (
  soil_moisture, soil_temperature, environmental_temperature, humidity,
  recorded_at, rover_id, crop_id, planting_log_id, soil_raw, calibrated_value, source
)
select
  greatest(0, least(100, coalesce(pl.soil_moisture_percent, 0))),
  coalesce(pl.environmental_temperature, 0),
  coalesce(pl.environmental_temperature, 0),
  0,
  coalesce(pl.completed_at, pl.started_at, now()), pl.rover_id, c.id, pl.id,
  pl.soil_raw,
  greatest(0, least(100, coalesce(pl.soil_moisture_percent, 0))), 'Hardware'
from public.crops c
join public.planting_logs pl on pl.id = c.planting_log_id
where not exists (
  select 1 from public.sensor_readings sr where sr.planting_log_id = pl.id
);

-- A harvest activity is also an inventory receipt for that vegetable.
-- The activity quantity is used when supplied; rover crop drop cycles provide
-- a safe fallback for mobile harvest actions that do not ask for a quantity.
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

  if inventory_row.id is not null and stock_quantity > 0 and actor is not null then
    insert into public.inventory_transactions (
      inventory_id, transaction_type, quantity, remarks, performed_by
    ) values (
      inventory_row.id, 'IN', stock_quantity,
      format('Harvest recorded from crop %s.', crop_row.batch_code), actor
    );
  end if;
  return new;
end;
$$;

drop trigger if exists crop_activities_record_harvest_stock on public.crop_activities;
create trigger crop_activities_record_harvest_stock
  after insert on public.crop_activities
  for each row execute function public.record_harvest_as_inventory_stock();
