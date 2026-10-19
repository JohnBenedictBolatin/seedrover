-- Allow farmers to keep an unverified rover response in crop sensor history
-- for testing, while ensuring it remains explicitly simulated and cannot be
-- mistaken for a calibrated hardware reading.
create or replace function public.record_crop_sensor_estimate(
  p_crop_id uuid,
  p_client_reading_id uuid,
  p_soil_raw integer default null,
  p_soil_moisture numeric default null,
  p_air_temperature numeric default null,
  p_humidity numeric default null,
  p_recorded_at timestamptz default null,
  p_rover_id text default 'SeedRover-01'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  existing public.sensor_readings%rowtype;
  reading_id uuid;
begin
  if actor is null or not public.has_permission('crops.manage') then
    raise exception 'crops.manage permission required';
  end if;
  if p_client_reading_id is null then
    raise exception 'Reading identifier is required.';
  end if;
  if p_soil_raw is null and p_soil_moisture is null
     and p_air_temperature is null and p_humidity is null then
    raise exception 'The rover did not return any readings.';
  end if;
  if p_soil_raw is not null and p_soil_raw not between 1 and 4094 then
    raise exception 'Invalid raw soil probe reading.';
  end if;
  if p_soil_moisture is not null and p_soil_moisture not between 0 and 100 then
    raise exception 'Invalid soil moisture.';
  end if;
  if p_air_temperature is not null and p_air_temperature not between -40 and 80 then
    raise exception 'Invalid air temperature.';
  end if;
  if p_humidity is not null and p_humidity not between 0 and 100 then
    raise exception 'Invalid humidity.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_client_reading_id::text, 0));
  select * into existing from public.sensor_readings
  where client_reading_id = p_client_reading_id
  for update;
  if found then
    if existing.crop_id = p_crop_id
      and existing.soil_raw is not distinct from p_soil_raw
      and existing.soil_moisture is not distinct from p_soil_moisture
      and existing.calibrated_value is null
      and existing.soil_temperature is null
      and existing.environmental_temperature is not distinct from p_air_temperature
      and existing.humidity is not distinct from p_humidity
      and existing.soil_moisture_calibrated is false
      and (p_recorded_at is null or existing.recorded_at = p_recorded_at)
      and existing.rover_id = coalesce(nullif(btrim(p_rover_id), ''), 'SeedRover-01')
      and existing.firmware_version is null
      and existing.source = 'Estimated sensor response'
      and existing.provenance_status = 'simulated'
      and existing.calibration_version = 'sensor-response-estimate-v1'
    then
      return existing.id;
    end if;
    raise exception 'Reading submission ID was already used for different values.';
  end if;

  perform 1 from public.crops
  where id = p_crop_id and crop_status not in ('Completed', 'Cancelled')
  for update;
  if not found then
    raise exception 'Choose a crop that is still growing.';
  end if;

  insert into public.sensor_readings (
    soil_moisture, calibrated_value, soil_raw, soil_temperature,
    environmental_temperature, humidity, recorded_at, rover_id, crop_id,
    source, provenance_status, soil_moisture_calibrated, calibration_version,
    firmware_version, client_reading_id
  ) values (
    p_soil_moisture, null, p_soil_raw, null, p_air_temperature, p_humidity,
    coalesce(p_recorded_at, now()), coalesce(nullif(btrim(p_rover_id), ''), 'SeedRover-01'),
    p_crop_id, 'Estimated sensor response', 'simulated', false,
    'sensor-response-estimate-v1', null, p_client_reading_id
  ) returning id into reading_id;

  insert into public.crop_activities (
    crop_id, activity_type, performed_at, performed_by, notes, source,
    idempotency_key, metadata
  ) values (
    p_crop_id, 'Inspected', coalesce(p_recorded_at, now()), actor,
    'Estimated sensor response saved for testing.', 'User',
    'sensor-estimate:' || p_client_reading_id::text,
    jsonb_build_object('sensor_reading_id', reading_id, 'estimated', true)
  ) on conflict (idempotency_key) where idempotency_key is not null do nothing;

  return reading_id;
end;
$$;

revoke all on function public.record_crop_sensor_estimate(uuid, uuid, integer, numeric, numeric, numeric, timestamptz, text) from public;
grant execute on function public.record_crop_sensor_estimate(uuid, uuid, integer, numeric, numeric, numeric, timestamptz, text) to authenticated;
