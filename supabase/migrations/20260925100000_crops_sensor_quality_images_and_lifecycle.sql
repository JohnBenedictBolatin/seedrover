-- Correct rover sensor semantics, retain unknown values as NULL, and support
-- repeat harvests, explicit crop completion, crop checks, and shared seed art.

alter table public.planting_logs
  add column if not exists soil_temperature_c numeric(5,2),
  add column if not exists air_temperature_c numeric(5,2),
  add column if not exists humidity_percent numeric(5,2);

alter table public.sensor_readings
  alter column soil_moisture drop not null,
  alter column soil_temperature drop not null,
  alter column environmental_temperature drop not null,
  alter column humidity drop not null,
  add column if not exists client_reading_id uuid;

create unique index if not exists sensor_readings_client_reading_id_idx
  on public.sensor_readings(client_reading_id) where client_reading_id is not null;

-- Older rover firmware put its DS18B20 soil reading in the environmental field
-- and wrote zero for disconnected temperature/humidity sensors. Retain the
-- measured soil temperature, but stop presenting it as an air measurement.
update public.sensor_readings sr
set soil_moisture = pl.soil_moisture_percent,
    calibrated_value = pl.soil_moisture_percent,
    soil_temperature = coalesce(
      (pl.sync_payload #>> '{status,soil_temperature_c}')::numeric,
      nullif(pl.environmental_temperature, 0)
    ),
    environmental_temperature = (pl.sync_payload #>> '{status,air_temperature_c}')::numeric,
    humidity = (pl.sync_payload #>> '{status,humidity_percent}')::numeric
from public.planting_logs pl
where sr.planting_log_id = pl.id;

create or replace function public.capture_rover_planting_sensor_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sensor_readings (
    soil_moisture, calibrated_value, soil_temperature,
    environmental_temperature, humidity, recorded_at, rover_id,
    crop_id, planting_log_id, soil_raw, source
  )
  select
    pl.soil_moisture_percent,
    pl.soil_moisture_percent,
    coalesce(
      (pl.sync_payload #>> '{status,soil_temperature_c}')::numeric,
      nullif(pl.environmental_temperature, 0)
    ),
    (pl.sync_payload #>> '{status,air_temperature_c}')::numeric,
    (pl.sync_payload #>> '{status,humidity_percent}')::numeric,
    coalesce(pl.completed_at, pl.started_at, now()), pl.rover_id,
    new.id, pl.id, pl.soil_raw, 'Hardware'
  from public.planting_logs pl
  where pl.id = new.planting_log_id
    and not exists (select 1 from public.sensor_readings sr where sr.planting_log_id = pl.id);
  return new;
end;
$$;

-- Keep the existing RPC signature for already-built mobile clients, but no
-- longer require seed-per-drop estimates or persist load-cell estimates.
create or replace function public.record_rover_planting_session(
  p_client_session_id uuid,
  p_rover_id text,
  p_crop_profile_key text,
  p_field_label text,
  p_target_drop_cycles integer,
  p_completed_drop_cycles integer,
  p_measured_distance_cm numeric,
  p_row_spacing_cm numeric,
  p_status text,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_soil_raw integer default null,
  p_soil_moisture_percent numeric default null,
  p_environmental_temperature numeric default null,
  p_seed_load_raw bigint default null,
  p_firmware_version text default null,
  p_failure_code text default null,
  p_sync_payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  profile_row public.crop_profiles%rowtype;
  planting_id uuid;
  crop_id uuid;
  area_m2 numeric(12,2);
  planting_day date;
begin
  if actor is null or not public.has_permission('rover.planting.control') then
    raise exception 'rover.planting.control permission required';
  end if;
  if p_target_drop_cycles <= 0 or p_completed_drop_cycles < 0
     or p_completed_drop_cycles > p_target_drop_cycles then
    raise exception 'Invalid planting drop counts';
  end if;
  if p_status not in ('Completed','Partial','Failed','Cancelled') then
    raise exception 'Invalid terminal planting status';
  end if;
  select * into profile_row from public.crop_profiles
    where profile_key = p_crop_profile_key and is_active;
  if profile_row.profile_key is null then raise exception 'Unknown crop profile'; end if;

  area_m2 := round(greatest(coalesce(p_measured_distance_cm, 0), 0) / 100.0
    * greatest(coalesce(p_row_spacing_cm, profile_row.row_spacing_cm, 0), 0) / 100.0, 2);
  planting_day := (coalesce(p_started_at, now()) at time zone 'Asia/Manila')::date;

  insert into public.planting_logs (
    operator_id, crop_name, planting_date, planting_time, planting_status, notes,
    client_session_id, rover_id, field_label, crop_profile_key, target_drop_cycles,
    completed_drop_cycles, measured_distance_cm, calculated_area_m2, row_spacing_cm,
    soil_raw, soil_moisture_percent, environmental_temperature,
    soil_temperature_c, air_temperature_c, humidity_percent,
    firmware_version, started_at, completed_at, failure_code, sync_payload
  ) values (
    actor, profile_row.display_name, planting_day,
    (coalesce(p_started_at, now()) at time zone 'Asia/Manila')::time,
    p_status,
    case when p_failure_code is null then 'Synchronized from SeedRover.'
      else 'SeedRover: ' || p_failure_code end,
    p_client_session_id, coalesce(nullif(btrim(p_rover_id), ''), 'seedrover-01'),
    nullif(btrim(p_field_label), ''), p_crop_profile_key, p_target_drop_cycles,
    p_completed_drop_cycles, p_measured_distance_cm, nullif(area_m2, 0),
    coalesce(p_row_spacing_cm, profile_row.row_spacing_cm), p_soil_raw,
    p_soil_moisture_percent, p_environmental_temperature,
    nullif(p_sync_payload #>> '{status,soil_temperature_c}', '')::numeric,
    nullif(p_sync_payload #>> '{status,air_temperature_c}', '')::numeric,
    nullif(p_sync_payload #>> '{status,humidity_percent}', '')::numeric,
    p_firmware_version, p_started_at, p_completed_at, p_failure_code,
    coalesce(p_sync_payload, '{}'::jsonb)
  ) on conflict (client_session_id) where client_session_id is not null do update set
    planting_status = excluded.planting_status,
    completed_drop_cycles = greatest(planting_logs.completed_drop_cycles, excluded.completed_drop_cycles),
    measured_distance_cm = excluded.measured_distance_cm,
    calculated_area_m2 = excluded.calculated_area_m2,
    soil_raw = excluded.soil_raw,
    soil_moisture_percent = excluded.soil_moisture_percent,
    environmental_temperature = excluded.environmental_temperature,
    soil_temperature_c = excluded.soil_temperature_c,
    air_temperature_c = excluded.air_temperature_c,
    humidity_percent = excluded.humidity_percent,
    completed_at = excluded.completed_at,
    failure_code = excluded.failure_code,
    sync_payload = excluded.sync_payload,
    updated_at = now()
  returning id into planting_id;

  if p_completed_drop_cycles = 0 then
    insert into public.activity_logs(user_id, activity, description, module)
    select actor, 'Rover planting failed',
      format('%s row created no completed drops. Session %s.', profile_row.display_name, p_client_session_id),
      'Planting'
    where not exists (select 1 from public.activity_logs
      where user_id = actor and activity = 'Rover planting failed'
        and description like '%' || p_client_session_id::text || '%');
    insert into public.notifications(recipient_id, title, message, notification_type, action_route)
    select distinct recipient_id, 'Rover planting failed',
      format('%s planting stopped before the first completed drop. Failure: %s', profile_row.display_name, coalesce(p_failure_code, 'Unknown')),
      'Crop Reminder', '/planting-logs/' || planting_id::text
    from (
      select actor as recipient_id
      union
      select p.id from public.profiles p join public.roles r on r.id = p.role_id
        where p.is_active and r.role_name = 'System Administrator'
    ) recipients
    where not exists (select 1 from public.notifications n
      where n.recipient_id = recipients.recipient_id
        and n.action_route = '/planting-logs/' || planting_id::text
        and n.title = 'Rover planting failed');
    return null;
  end if;

  select id into crop_id from public.crops where planting_log_id = planting_id;
  if crop_id is null then
    insert into public.crops (
      planting_log_id, crop_name, assigned_manager, planting_date, estimated_harvest,
      growth_stage, maintenance_notes, crop_status, crop_profile_key, profile_version,
      planting_source, propagation_method, field_label, field_area_m2,
      completed_drop_cycles,
      harvest_window_start, harvest_window_end, forecast_confidence, expected_stage,
      current_care_status
    ) values (
      planting_id, profile_row.display_name, actor, planting_day,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
      'Seeded', profile_row.advisory, 'Active', profile_row.profile_key, profile_row.version,
      'Rover', profile_row.propagation_method, nullif(btrim(p_field_label), ''), nullif(area_m2, 0),
      p_completed_drop_cycles,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_end_days end,
      case when p_status = 'Partial' or p_crop_profile_key = 'calamansi' then 'Low' else 'Medium' end,
      case when p_crop_profile_key = 'calamansi' then 'Germination and nursery review' else 'Germination' end,
      case when p_status = 'Partial' then 'Partial planting - inspect row' else 'Monitor establishment' end
    ) returning id into crop_id;
  else
    update public.crops set
      completed_drop_cycles = greatest(coalesce(completed_drop_cycles, 0), p_completed_drop_cycles),
      field_area_m2 = nullif(area_m2, 0),
      current_care_status = case when p_status = 'Partial'
        then 'Partial planting - inspect row' else current_care_status end
    where id = crop_id;
  end if;

  insert into public.crop_activities (
    crop_id, activity_type, performed_at, performed_by, quantity, unit, notes,
    observed_stage, source, idempotency_key, metadata
  ) values (
    crop_id, 'Planted', coalesce(p_completed_at, p_started_at, now()), actor,
    p_completed_drop_cycles, 'drop cycles',
    format('%s of %s planned planting drops completed.', p_completed_drop_cycles, p_target_drop_cycles),
    'Seeded', 'Rover', 'planting:' || p_client_session_id::text,
    jsonb_build_object('planting_log_id', planting_id)
  ) on conflict (idempotency_key) where idempotency_key is not null do nothing;

  insert into public.activity_logs(user_id, activity, description, module)
  select actor, 'Rover crop batch created',
    format('%s planted in %s: %s completed drops (%s). Session %s.', profile_row.display_name,
      coalesce(nullif(btrim(p_field_label), ''), 'unlabeled field'), p_completed_drop_cycles, p_status, p_client_session_id),
    'Planting'
  where not exists (select 1 from public.activity_logs
    where user_id = actor and activity = 'Rover crop batch created'
      and description like '%' || p_client_session_id::text || '%');
  return crop_id;
end;
$$;

-- Harvesting adds produce and history. Workers explicitly finish the crop
-- cycle when no more harvesting or care is expected.
alter table public.crop_activities drop constraint if exists crop_activities_type_allowed;
alter table public.crop_activities add constraint crop_activities_type_allowed check (
  activity_type in ('Planted','Watered','Fertilized','Inspected','Stage Observed','Transplanted','Harvested','Not Harvested','Planting Failed','Crop Cycle Finished')
);

drop trigger if exists crop_activities_finalize_harvest on public.crop_activities;
drop trigger if exists crop_activities_record_harvest_stock on public.crop_activities;

create or replace function public.record_harvest_as_inventory_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  crop_name_value text;
  inventory_row public.inventory%rowtype;
  actor uuid := coalesce(new.performed_by, auth.uid());
begin
  if new.activity_type <> 'Harvested' then return new; end if;
  -- The dedicated harvest RPC already records stock and links its harvest row.
  if new.metadata ? 'crop_harvest_id' then return new; end if;
  if new.quantity is null or new.quantity <= 0 then
    raise exception 'Enter the actual harvested weight in kg.';
  end if;
  select crop_name into crop_name_value from public.crops where id = new.crop_id;
  select * into inventory_row from public.inventory
    where lower(trim(item_name)) = lower(trim(crop_name_value))
    order by created_at limit 1 for update;
  if inventory_row.id is null then
    raise exception 'Create a matching % inventory item before recording harvest.', crop_name_value;
  end if;
  insert into public.inventory_transactions(inventory_id, transaction_type, quantity, remarks, performed_by)
  values (inventory_row.id, 'IN', new.quantity,
    format('Harvest recorded from crop %s.', new.crop_id), actor);
  return new;
end;
$$;
create trigger crop_activities_record_harvest_stock
  after insert on public.crop_activities
  for each row execute function public.record_harvest_as_inventory_stock();

create or replace function public.keep_crop_active_after_harvest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.activity_type = 'Harvested' then
    update public.crops set
      crop_status = 'Active',
      growth_stage = 'Harvest Ready',
      current_care_status = 'Harvest recorded. Finish the crop when its cycle is over.',
      updated_at = now()
    where id = new.crop_id;
  end if;
  return new;
end;
$$;
create trigger crop_activities_keep_harvest_active
  after insert on public.crop_activities
  for each row execute function public.keep_crop_active_after_harvest();

-- The older record_crop_activity RPC updates the crop row after inserting the
-- harvest activity. Keep that legacy write from closing a repeat-harvest crop;
-- an explicit Crop Cycle Finished activity remains the only close operation.
create or replace function public.prevent_implicit_crop_completion_after_harvest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.crop_status in ('Completed','Cancelled') and exists (
    select 1 from public.crop_activities ca
    where ca.crop_id = new.id
      and ca.activity_type = 'Harvested'
      and not exists (
        select 1 from public.crop_activities finished
        where finished.crop_id = ca.crop_id
          and finished.activity_type = 'Crop Cycle Finished'
          and (finished.performed_at, finished.created_at) > (ca.performed_at, ca.created_at)
      )
      and ca.id = (
        select latest.id from public.crop_activities latest
        where latest.crop_id = ca.crop_id
        order by latest.created_at desc, latest.id desc limit 1
      )
  ) then
    update public.crops set
      crop_status = 'Active',
      growth_stage = 'Harvest Ready',
      current_care_status = 'Harvest recorded. Finish the crop when its cycle is over.',
      updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;
drop trigger if exists crops_prevent_implicit_completion_after_harvest on public.crops;
create trigger crops_prevent_implicit_completion_after_harvest
  after update of crop_status, growth_stage on public.crops
  for each row execute function public.prevent_implicit_crop_completion_after_harvest();

create or replace function public.finish_crop_cycle(
  p_crop_id uuid,
  p_outcome text default 'Finished',
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  crop_row public.crops%rowtype;
  activity_id uuid;
  clean_outcome text := coalesce(nullif(btrim(p_outcome), ''), 'Finished');
begin
  if actor is null or not public.has_permission('crops.manage') then
    raise exception 'crops.manage permission required';
  end if;
  if clean_outcome not in ('Finished','Failed','Removed') then
    raise exception 'Choose a valid crop outcome.';
  end if;
  select * into crop_row from public.crops where id = p_crop_id for update;
  if not found then raise exception 'Crop not found'; end if;
  if crop_row.crop_status in ('Completed','Cancelled') then
    raise exception 'This crop is already closed.';
  end if;

  insert into public.crop_activities(
    crop_id, activity_type, performed_at, performed_by, notes,
    source, idempotency_key, metadata
  ) values (
    crop_row.id, 'Crop Cycle Finished', now(), actor,
    concat_ws(' — ', clean_outcome, nullif(btrim(p_notes), '')),
    'User', p_idempotency_key, jsonb_build_object('outcome', clean_outcome)
  ) on conflict (idempotency_key) where idempotency_key is not null do nothing
  returning id into activity_id;

  if activity_id is null and p_idempotency_key is not null then
    select id into activity_id from public.crop_activities where idempotency_key = p_idempotency_key;
    return activity_id;
  end if;

  update public.crops set
    crop_status = case when clean_outcome = 'Finished' then 'Completed' else 'Cancelled' end,
    growth_stage = case when clean_outcome = 'Finished' then 'Completed' else growth_stage end,
    current_care_status = case
      when clean_outcome = 'Finished' then 'Growing cycle finished'
      when clean_outcome = 'Failed' then 'Crop marked as failed'
      else 'Crop removed from growing list'
    end,
    updated_at = now()
  where id = crop_row.id;

  update public.crop_tasks set status = 'Dismissed', updated_at = now()
  where crop_id = crop_row.id and status <> 'Completed';
  return activity_id;
end;
$$;

create or replace function public.record_crop_sensor_check(
  p_crop_id uuid,
  p_client_reading_id uuid,
  p_soil_raw integer default null,
  p_soil_moisture numeric default null,
  p_soil_temperature numeric default null,
  p_air_temperature numeric default null,
  p_humidity numeric default null,
  p_rover_id text default 'SeedRover-01'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  reading_id uuid;
begin
  if actor is null or not public.has_permission('crops.manage') then
    raise exception 'crops.manage permission required';
  end if;
  if p_client_reading_id is null then raise exception 'Reading identifier is required.'; end if;
  if not exists (select 1 from public.crops where id = p_crop_id and crop_status not in ('Completed','Cancelled')) then
    raise exception 'Choose a crop that is still growing.';
  end if;
  if p_soil_raw is null and p_soil_moisture is null and p_soil_temperature is null
     and p_air_temperature is null and p_humidity is null then
    raise exception 'The rover did not return any readings.';
  end if;
  if p_soil_moisture is not null and p_soil_moisture not between 0 and 100 then raise exception 'Invalid soil moisture.'; end if;
  if p_humidity is not null and p_humidity not between 0 and 100 then raise exception 'Invalid humidity.'; end if;

  insert into public.sensor_readings(
    soil_moisture, calibrated_value, soil_raw, soil_temperature,
    environmental_temperature, humidity, recorded_at, rover_id,
    crop_id, source, client_reading_id
  ) values (
    p_soil_moisture, p_soil_moisture, p_soil_raw, p_soil_temperature,
    p_air_temperature, p_humidity, now(), coalesce(nullif(btrim(p_rover_id), ''), 'SeedRover-01'),
    p_crop_id, 'Hardware', p_client_reading_id
  ) on conflict (client_reading_id) where client_reading_id is not null do update
    set client_reading_id = excluded.client_reading_id
  returning id into reading_id;

  insert into public.crop_activities(crop_id, activity_type, performed_at, performed_by, notes, source, idempotency_key, metadata)
  values (p_crop_id, 'Inspected', now(), actor, 'Rover sensor check recorded.', 'User', 'sensor-check:' || p_client_reading_id::text,
    jsonb_build_object('sensor_reading_id', reading_id))
  on conflict (idempotency_key) where idempotency_key is not null do nothing;
  return reading_id;
end;
$$;

create table if not exists public.crop_profile_images (
  profile_key text primary key references public.crop_profiles(profile_key) on delete cascade,
  image_path text not null,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint crop_profile_images_allowed_seed check (profile_key in ('sitaw','peanut','calamansi'))
);
alter table public.crop_profile_images enable row level security;
drop policy if exists crop_profile_images_read_authenticated on public.crop_profile_images;
drop policy if exists crop_profile_images_manage_allowed on public.crop_profile_images;
create policy crop_profile_images_read_authenticated on public.crop_profile_images
  for select to authenticated using (true);
create policy crop_profile_images_manage_allowed on public.crop_profile_images
  for all to authenticated using (public.has_permission('crops.manage'))
  with check (public.has_permission('crops.manage'));

-- Remove historical estimate values and their obsolete schema fields. The
-- session RPC still accepts its old load-cell argument for older app builds,
-- but does not write it to the database.
drop trigger if exists planting_logs_clear_unavailable_seed_load on public.planting_logs;
drop function if exists public.clear_unavailable_seed_load();
alter table public.planting_logs drop column if exists seed_load_raw;

alter table public.crops drop constraint if exists crops_field_values_valid;
alter table public.crops add constraint crops_field_values_valid check (
  (field_area_m2 is null or field_area_m2 > 0)
  and (completed_drop_cycles is null or completed_drop_cycles >= 0)
  and (harvest_window_start is null or harvest_window_end is null or harvest_window_end >= harvest_window_start)
);
alter table public.crops drop column if exists estimated_seed_count_min;
alter table public.crops drop column if exists estimated_seed_count_max;

update public.crop_profile_versions
set profile_snapshot = profile_snapshot - 'estimated_seeds_per_drop_min' - 'estimated_seeds_per_drop_max'
where profile_snapshot ? 'estimated_seeds_per_drop_min'
   or profile_snapshot ? 'estimated_seeds_per_drop_max';
alter table public.crop_profiles drop constraint if exists crop_profiles_seed_range_valid;
alter table public.crop_profiles drop column if exists estimated_seeds_per_drop_min;
alter table public.crop_profiles drop column if exists estimated_seeds_per_drop_max;

create or replace function public.remove_rover_seed_count_estimates()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.activity_type = 'Planted' and new.source = 'Rover' then
    new.metadata := new.metadata - 'estimated_seed_count_min' - 'estimated_seed_count_max';
    new.notes := regexp_replace(coalesce(new.notes, ''), '\s*Seed count is estimated\.?', '', 'i');
  end if;
  return new;
end;
$$;
drop trigger if exists crop_activities_remove_rover_seed_count_estimates on public.crop_activities;
create trigger crop_activities_remove_rover_seed_count_estimates
  before insert on public.crop_activities
  for each row execute function public.remove_rover_seed_count_estimates();

revoke all on function public.finish_crop_cycle(uuid,text,text,text) from public;
revoke all on function public.record_crop_sensor_check(uuid,uuid,integer,numeric,numeric,numeric,numeric,text) from public;
grant execute on function public.finish_crop_cycle(uuid,text,text,text) to authenticated;
grant execute on function public.record_crop_sensor_check(uuid,uuid,integer,numeric,numeric,numeric,numeric,text) to authenticated;
