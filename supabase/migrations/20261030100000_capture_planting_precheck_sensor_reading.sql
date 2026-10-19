-- Preserve the reviewed automated-planting soil check with the planting receipt.
-- On crop creation, prefer that initial check for the crop sensor snapshot;
-- older clients continue to use the existing run-status snapshot behavior.
create or replace function public.capture_rover_planting_sensor_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  planting public.planting_logs%rowtype;
  initial_check jsonb;
  reading_kind text;
  raw_value integer;
  moisture_value numeric;
  is_calibrated boolean;
  reading_source text;
  provenance text;
begin
  select * into planting
  from public.planting_logs
  where id = new.planting_log_id;

  initial_check := planting.sync_payload->'initial_soil_check';
  reading_kind := initial_check->>'reading_kind';

  if initial_check is not null
     and (initial_check->>'soil_raw' is not null
       or initial_check->>'soil_raw_estimate' is not null
       or initial_check->>'soil_moisture_percent' is not null
       or initial_check->>'air_temperature_c' is not null
       or initial_check->>'humidity_percent' is not null) then
    raw_value := case
      when reading_kind in ('sample', 'fallback')
        then nullif(initial_check->>'soil_raw_estimate', '')::integer
      else nullif(initial_check->>'soil_raw', '')::integer
    end;
    moisture_value := nullif(initial_check->>'soil_moisture_percent', '')::numeric;
    is_calibrated := reading_kind = 'measured'
      and coalesce((initial_check->>'soil_moisture_calibrated')::boolean, false)
      and nullif(initial_check->>'calibration_version', '') is not null
      and moisture_value is not null;
    reading_source := case reading_kind
      when 'sample' then 'Estimated sample'
      when 'fallback' then 'Estimated sensor response'
      when 'measured' then 'Hardware'
      else 'Unverified'
    end;
    provenance := case
      when reading_kind in ('sample', 'fallback') then 'simulated'
      when reading_kind = 'measured'
        and nullif(initial_check->>'firmware_version', '') is not null
        then 'verified_hardware'
      else 'unverified'
    end;

    insert into public.sensor_readings (
      soil_moisture, calibrated_value, soil_raw, soil_temperature,
      environmental_temperature, humidity, recorded_at, rover_id,
      crop_id, planting_log_id, source, provenance_status,
      soil_moisture_calibrated, calibration_version, firmware_version,
      client_reading_id
    ) values (
      case when is_calibrated or reading_kind in ('sample', 'fallback')
        then moisture_value else null end,
      case when is_calibrated or reading_kind = 'sample'
        then moisture_value else null end,
      raw_value, null,
      nullif(initial_check->>'air_temperature_c', '')::numeric,
      nullif(initial_check->>'humidity_percent', '')::numeric,
      coalesce(nullif(initial_check->>'recorded_at', '')::timestamptz,
        planting.soil_captured_at, planting.completed_at, planting.started_at, now()),
      planting.rover_id, new.id, planting.id, reading_source, provenance,
      case when reading_kind in ('sample', 'fallback') then false
        when initial_check->>'soil_moisture_calibrated' is null then null
        else is_calibrated end,
      case when is_calibrated then nullif(initial_check->>'calibration_version', '')
        else case when reading_kind in ('sample', 'fallback')
          then case reading_kind when 'sample' then 'display-sample-v1'
            else 'sensor-response-estimate-v1' end
          else null end end,
      case when provenance = 'verified_hardware'
        then nullif(initial_check->>'firmware_version', '') else null end,
      planting.client_session_id
    ) on conflict (client_reading_id) where client_reading_id is not null do nothing;
  else
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
      pl.soil_raw, null,
      (pl.sync_payload #>> '{status,air_temperature_c}')::numeric,
      (pl.sync_payload #>> '{status,humidity_percent}')::numeric,
      coalesce(pl.soil_captured_at, pl.completed_at, pl.started_at, now()),
      pl.rover_id, new.id, pl.id,
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
        or (pl.sync_payload #>> '{status,air_temperature_c}') is not null
        or (pl.sync_payload #>> '{status,humidity_percent}') is not null)
      and not exists (
        select 1 from public.sensor_readings sr where sr.planting_log_id = pl.id
      );
  end if;

  return new;
end;
$$;
