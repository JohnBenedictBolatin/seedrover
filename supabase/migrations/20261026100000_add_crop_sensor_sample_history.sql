-- Save intentional soil preview samples in sensor history without presenting
-- them as measured rover readings or logging them as a crop inspection.
create or replace function public.record_crop_sensor_sample(
  p_crop_id uuid,
  p_client_reading_id uuid,
  p_soil_raw integer,
  p_soil_moisture numeric,
  p_condition text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  existing public.sensor_readings%rowtype;
  reading_id uuid;
  allowed_pair boolean := false;
begin
  if actor is null or not public.has_permission('crops.manage') then
    raise exception 'crops.manage permission required';
  end if;
  if p_client_reading_id is null then
    raise exception 'Sample submission ID is required.';
  end if;
  allowed_pair := case p_condition
    when 'good' then (p_soil_raw, p_soil_moisture) in
      ((2100,45::numeric),(2080,50::numeric),(2060,55::numeric),(2040,60::numeric),(2020,65::numeric))
    when 'too_wet' then (p_soil_raw, p_soil_moisture) in
      ((1994,70::numeric),(1953,75::numeric),(1890,80::numeric),(1785,85::numeric),(1680,90::numeric))
    when 'too_dry' then (p_soil_raw, p_soil_moisture) in
      ((2226,10::numeric),(2247,15::numeric),(2268,20::numeric),(2289,25::numeric),(2310,30::numeric))
    else false
  end;
  if not allowed_pair then
    raise exception 'Choose one of the available estimated samples.';
  end if;

  select * into existing from public.sensor_readings
  where client_reading_id = p_client_reading_id
  for update;
  if found then
    if existing.crop_id = p_crop_id
      and existing.soil_raw = p_soil_raw
      and existing.calibrated_value = p_soil_moisture
      and existing.source = 'Estimated sample'
      and existing.provenance_status = 'simulated'
      and existing.calibration_version = 'display-sample-v1'
    then
      return existing.id;
    end if;
    raise exception 'Sample submission ID was already used for different values.';
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
    p_soil_moisture, p_soil_moisture, p_soil_raw, null, null, null, now(),
    'SeedRover-01', p_crop_id, 'Estimated sample', 'simulated', false,
    'display-sample-v1', null, p_client_reading_id
  ) returning id into reading_id;

  return reading_id;
end;
$$;

revoke all on function public.record_crop_sensor_sample(uuid,uuid,integer,numeric,text) from public;
grant execute on function public.record_crop_sensor_sample(uuid,uuid,integer,numeric,text) to authenticated;
