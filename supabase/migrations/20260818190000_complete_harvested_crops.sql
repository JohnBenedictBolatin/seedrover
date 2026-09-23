-- A crop explicitly marked harvested/completed must leave the active crop list.
-- This deferred trigger runs after record_crop_activity() finishes, overriding
-- the former Sitaw repeated-harvest exception while preserving the activity,
-- stock receipt, stock history, and crop outcome created in the transaction.
create or replace function public.require_harvest_inventory_target()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  crop_name_value text;
begin
  if new.activity_type <> 'Harvested' then return new; end if;

  select crop_name into crop_name_value from public.crops where id = new.crop_id;
  if not exists (
    select 1 from public.inventory i
    where lower(trim(i.item_name)) = lower(trim(crop_name_value))
  ) then
    raise exception 'Create a % inventory item before completing this crop.', crop_name_value;
  end if;
  return new;
end;
$$;

drop trigger if exists crop_activities_require_harvest_inventory on public.crop_activities;
create trigger crop_activities_require_harvest_inventory
  before insert on public.crop_activities
  for each row execute function public.require_harvest_inventory_target();

create or replace function public.finalize_harvested_crop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.crops
  set
    growth_stage = 'Completed',
    crop_status = 'Completed',
    current_care_status = 'Crop cycle completed',
    updated_at = now()
  where id = new.crop_id
    and new.activity_type = 'Harvested'
    and crop_status <> 'Completed';
  return new;
end;
$$;

drop trigger if exists crop_activities_finalize_harvest on public.crop_activities;
create constraint trigger crop_activities_finalize_harvest
  after insert on public.crop_activities
  deferrable initially deferred
  for each row execute function public.finalize_harvested_crop();

-- Repair harvested activities whose crops were left active by the old Sitaw
-- repeated-harvest behavior. The crop status trigger then adds Crop History.
update public.crops c
set
  growth_stage = 'Completed',
  crop_status = 'Completed',
  current_care_status = 'Crop cycle completed',
  updated_at = now()
where c.crop_status <> 'Completed'
  and exists (
    select 1
    from public.crop_activities a
    where a.crop_id = c.id and a.activity_type = 'Harvested'
  );
