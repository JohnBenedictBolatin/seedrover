-- Keep rover sensor samples distinguishable from demo and legacy values.
alter table public.sensor_readings
  add column if not exists provenance_status text not null default 'unverified',
  add column if not exists soil_moisture_calibrated boolean,
  add column if not exists calibration_version text,
  add column if not exists firmware_version text;

alter table public.sensor_readings
  drop constraint if exists sensor_readings_provenance_status_allowed;
alter table public.sensor_readings
  add constraint sensor_readings_provenance_status_allowed
  check (provenance_status in ('verified_hardware', 'unverified', 'simulated', 'demo'));

-- Planting snapshots inherit the firmware version from their originating run.
update public.sensor_readings sr
set firmware_version = pl.firmware_version
from public.planting_logs pl
where sr.planting_log_id = pl.id
  and sr.firmware_version is null
  and pl.firmware_version is not null;

-- Only readings written by the known rover capture paths have enough linkage
-- to be trusted. Rows with Cloud/default or missing source retain their values
-- and history but are not considered current hardware readings.
update public.sensor_readings
set provenance_status = 'verified_hardware'
where source = 'Hardware'
  and (client_reading_id is not null or (planting_log_id is not null and firmware_version is not null));

alter table public.sensor_readings
  drop constraint if exists sensor_readings_verified_origin_check,
  add constraint sensor_readings_verified_origin_check
    check (provenance_status <> 'verified_hardware' or (
      source = 'Hardware' and (firmware_version is not null or client_reading_id is not null)
    )),
  drop constraint if exists sensor_readings_calibrated_moisture_metadata_check,
  add constraint sensor_readings_calibrated_moisture_metadata_check
    check (soil_moisture_calibrated is not true or (
      calibration_version is not null and calibrated_value is not null
    ));

create index if not exists sensor_readings_verified_recent_idx
  on public.sensor_readings(recorded_at desc)
  where provenance_status = 'verified_hardware';

create or replace function public.capture_rover_planting_sensor_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.sensor_readings (
    soil_moisture, calibrated_value, soil_raw, soil_temperature,
    environmental_temperature, humidity, recorded_at, rover_id,
    crop_id, planting_log_id, source, provenance_status,
    soil_moisture_calibrated, calibration_version, firmware_version
  )
  select
    case when coalesce((pl.sync_payload #>> '{status,soil_moisture_calibrated}')::boolean, false)
      and nullif(pl.sync_payload #>> '{status,calibration_version}', '') is not null
      then pl.soil_moisture_percent else null end,
    case when coalesce((pl.sync_payload #>> '{status,soil_moisture_calibrated}')::boolean, false)
      and nullif(pl.sync_payload #>> '{status,calibration_version}', '') is not null
      then pl.soil_moisture_percent else null end,
    pl.soil_raw,
    coalesce(
      (pl.sync_payload #>> '{status,soil_temperature_c}')::numeric,
      pl.environmental_temperature
    ),
    (pl.sync_payload #>> '{status,air_temperature_c}')::numeric,
    (pl.sync_payload #>> '{status,humidity_percent}')::numeric,
    coalesce(pl.soil_captured_at, pl.completed_at, pl.started_at, now()),
    pl.rover_id,
    new.id,
    pl.id,
    case when pl.firmware_version is not null then 'Hardware' else 'Unverified' end,
    case when pl.firmware_version is not null then 'verified_hardware' else 'unverified' end,
    case
      when pl.sync_payload #>> '{status,soil_moisture_calibrated}' is null then null
      when (pl.sync_payload #>> '{status,soil_moisture_calibrated}')::boolean is true
        and nullif(pl.sync_payload #>> '{status,calibration_version}', '') is not null then true
      else false
    end,
    nullif(pl.sync_payload #>> '{status,calibration_version}', ''),
    pl.firmware_version
  from public.planting_logs pl
  where pl.id = new.planting_log_id
    and (pl.soil_raw is not null
      or pl.soil_moisture_percent is not null
      or (pl.sync_payload #>> '{status,soil_temperature_c}') is not null
      or (pl.sync_payload #>> '{status,air_temperature_c}') is not null
      or (pl.sync_payload #>> '{status,humidity_percent}') is not null)
    and not exists (
      select 1 from public.sensor_readings sr where sr.planting_log_id = pl.id
    );
  return new;
end;
$$;

-- Replace the prior RPC so older clients can still call it using defaults,
-- while missing calibration/firmware metadata cannot create a trusted
-- calibrated percentage.
drop function if exists public.record_crop_sensor_check(
  uuid, uuid, integer, numeric, numeric, numeric, numeric, text
);

create function public.record_crop_sensor_check(
  p_crop_id uuid,
  p_client_reading_id uuid,
  p_soil_raw integer default null,
  p_soil_moisture numeric default null,
  p_soil_temperature numeric default null,
  p_air_temperature numeric default null,
  p_humidity numeric default null,
  p_rover_id text default 'SeedRover-01',
  p_recorded_at timestamptz default null,
  p_soil_moisture_calibrated boolean default null,
  p_calibration_version text default null,
  p_firmware_version text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  reading_id uuid;
  verified_hardware boolean := nullif(btrim(p_firmware_version), '') is not null;
  calibrated boolean := p_soil_moisture_calibrated
    and nullif(btrim(p_calibration_version), '') is not null
    and p_soil_moisture is not null;
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
  if p_soil_raw is not null and p_soil_raw not between 1 and 4094 then raise exception 'Invalid raw soil probe reading.'; end if;
  if p_soil_temperature is not null and p_soil_temperature not between -55 and 125 then raise exception 'Invalid soil temperature.'; end if;
  if p_air_temperature is not null and p_air_temperature not between -40 and 80 then raise exception 'Invalid air temperature.'; end if;

  insert into public.sensor_readings(
    soil_moisture, calibrated_value, soil_raw, soil_temperature,
    environmental_temperature, humidity, recorded_at, rover_id,
    crop_id, source, provenance_status, soil_moisture_calibrated,
    calibration_version, firmware_version, client_reading_id
  ) values (
    case when calibrated then p_soil_moisture else null end,
    case when calibrated then p_soil_moisture else null end,
    p_soil_raw, p_soil_temperature, p_air_temperature, p_humidity,
    coalesce(p_recorded_at, now()), coalesce(nullif(btrim(p_rover_id), ''), 'SeedRover-01'),
    p_crop_id,
    case when verified_hardware then 'Hardware' else 'Unverified' end,
    case when verified_hardware then 'verified_hardware' else 'unverified' end,
    case when p_soil_moisture_calibrated is null then null else calibrated end,
    nullif(btrim(p_calibration_version), ''),
    nullif(btrim(p_firmware_version), ''), p_client_reading_id
  ) on conflict (client_reading_id) where client_reading_id is not null do update
    set client_reading_id = excluded.client_reading_id
  returning id into reading_id;

  insert into public.crop_activities(crop_id, activity_type, performed_at, performed_by, notes, source, idempotency_key, metadata)
  values (p_crop_id, 'Inspected', coalesce(p_recorded_at, now()), actor, 'Rover sensor check recorded.', 'User', 'sensor-check:' || p_client_reading_id::text,
    jsonb_build_object('sensor_reading_id', reading_id))
  on conflict (idempotency_key) where idempotency_key is not null do nothing;
  return reading_id;
end;
$$;

revoke all on function public.record_crop_sensor_check(uuid, uuid, integer, numeric, numeric, numeric, numeric, text, timestamptz, boolean, text, text) from public;
grant execute on function public.record_crop_sensor_check(uuid, uuid, integer, numeric, numeric, numeric, numeric, text, timestamptz, boolean, text, text) to authenticated;
