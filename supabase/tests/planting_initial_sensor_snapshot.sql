-- Rollback-only integration check for the real planting sync RPC. The crop
-- creation trigger must link the initial reading in the receipt to history.
begin;

do $$
declare
  actor_id uuid;
  candidate_id uuid;
  measured_run uuid := gen_random_uuid();
  sample_run uuid := gen_random_uuid();
  measured_result jsonb;
  sample_result jsonb;
  measured_log_id uuid;
  sample_log_id uuid;
  retry_result jsonb;
  measured_crop uuid;
  sample_crop uuid;
  measured_record public.sensor_readings%rowtype;
  sample_record public.sensor_readings%rowtype;
  start_time timestamptz := now() - interval '1 minute';
begin
  -- Reuse an active local QA account where available. Otherwise create a
  -- synthetic planting manager inside this rollback-only test transaction.
  for candidate_id in
    select id from public.profiles where is_active order by id
  loop
    perform set_config('request.jwt.claim.sub', candidate_id::text, true);
    if public.has_permission('rover.planting.control') then
      actor_id := candidate_id;
      exit;
    end if;
  end loop;
  if actor_id is null then
    actor_id := '00000000-0000-4000-8000-00000000a630'::uuid;
    insert into public.roles (role_name)
    values ('Farm Staff'), ('Farm Planting Manager')
    on conflict (role_name) do nothing;
    insert into auth.users (
      id, aud, role, email, encrypted_password, raw_user_meta_data
    ) values (
      actor_id, 'authenticated', 'authenticated',
      'migration-qa@seedrover.invalid', '',
      jsonb_build_object('username', 'migration_qa', 'full_name', 'Migration QA')
    ) on conflict (id) do nothing;
    update public.profiles
    set role_id = (select id from public.roles where role_name = 'Farm Planting Manager'),
        is_active = true
    where id = actor_id;
    perform set_config('request.jwt.claim.sub', actor_id::text, true);
    if not public.has_permission('rover.planting.control') then
      raise exception 'Unable to create the synthetic local planting test account.';
    end if;
  end if;

  measured_result := public.sync_rover_planting_run(jsonb_build_object(
    'session_id', measured_run,
    'rover_id', 'SeedRover-QA',
    'crop_profile_key', 'sitaw',
    'field_label', 'QA measured row',
    'target_drop_cycles', 5,
    'completed_drop_cycles', 5,
    'measured_distance_cm', 200,
    'row_spacing_cm', 100,
    'planting_status', 'Completed',
    'started_at', start_time,
    'completed_at', now(),
    'soil_raw', null,
    'soil_moisture_percent', null,
    'air_temperature_c', null,
    'humidity_percent', null,
    'firmware_version', 'qa-firmware',
    'confirmation_outcome', 'row_planted',
    'sync_payload', jsonb_build_object(
      'initial_soil_check', jsonb_build_object(
        'reading_kind', 'measured', 'soil_raw', 1725,
        'soil_moisture_percent', 48.5, 'soil_moisture_calibrated', true,
        'calibration_version', 'qa-cal-v1', 'firmware_version', 'qa-firmware',
        'air_temperature_c', 29, 'humidity_percent', 67,
        'recorded_at', now()::text
      ),
      'status', '{}'::jsonb
    )
  ));
  measured_log_id := (measured_result->>'planting_log_id')::uuid;
  measured_crop := (measured_result->>'crop_id')::uuid;

  sample_result := public.sync_rover_planting_run(jsonb_build_object(
    'session_id', sample_run,
    'rover_id', 'SeedRover-QA',
    'crop_profile_key', 'peanut',
    'field_label', 'QA sample row',
    'target_drop_cycles', 5,
    'completed_drop_cycles', 5,
    'measured_distance_cm', 200,
    'row_spacing_cm', 40,
    'planting_status', 'Completed',
    'started_at', start_time,
    'completed_at', now(),
    'soil_raw', null,
    'soil_moisture_percent', null,
    'air_temperature_c', null,
    'humidity_percent', null,
    'firmware_version', 'qa-firmware',
    'confirmation_outcome', 'row_planted',
    'sync_payload', jsonb_build_object(
      'initial_soil_check', jsonb_build_object(
        'reading_kind', 'sample', 'soil_raw_estimate', 1785,
        'soil_moisture_percent', 85, 'soil_moisture_calibrated', false,
        'sample_condition', 'too_wet', 'air_temperature_c', 30,
        'humidity_percent', 70, 'recorded_at', now()::text
      ),
      'status', '{}'::jsonb
    )
  ));
  sample_log_id := (sample_result->>'planting_log_id')::uuid;
  sample_crop := (sample_result->>'crop_id')::uuid;

  -- A lost response can cause the phone to replay this same session. The
  -- existing planting and sensor snapshot must be returned, not duplicated.
  retry_result := public.sync_rover_planting_run(jsonb_build_object(
    'session_id', measured_run,
    'rover_id', 'SeedRover-QA',
    'crop_profile_key', 'sitaw',
    'field_label', 'QA measured row',
    'target_drop_cycles', 5,
    'completed_drop_cycles', 5,
    'measured_distance_cm', 200,
    'row_spacing_cm', 100,
    'planting_status', 'Completed',
    'started_at', start_time,
    'completed_at', now(),
    'soil_raw', null,
    'soil_moisture_percent', null,
    'air_temperature_c', null,
    'humidity_percent', null,
    'firmware_version', 'qa-firmware',
    'confirmation_outcome', 'row_planted',
    'sync_payload', jsonb_build_object(
      'initial_soil_check', jsonb_build_object(
        'reading_kind', 'measured', 'soil_raw', 1725,
        'soil_moisture_percent', 48.5, 'soil_moisture_calibrated', true,
        'calibration_version', 'qa-cal-v1', 'firmware_version', 'qa-firmware',
        'air_temperature_c', 29, 'humidity_percent', 67,
        'recorded_at', now()::text
      ),
      'status', '{}'::jsonb
    )
  ));

  select * into measured_record from public.sensor_readings
  where planting_log_id = measured_log_id;
  select * into sample_record from public.sensor_readings
  where planting_log_id = sample_log_id;

  if measured_log_id is null or measured_crop is null
     or (retry_result->>'planting_log_id')::uuid <> measured_log_id
     or (retry_result->>'crop_id')::uuid <> measured_crop
     or (select count(*) from public.sensor_readings
         where planting_log_id = measured_log_id) <> 1
     or measured_record.id is null
     or measured_record.crop_id <> measured_crop
     or measured_record.soil_raw <> 1725
     or measured_record.soil_moisture <> 48.5
     or measured_record.source <> 'Hardware'
     or measured_record.provenance_status <> 'verified_hardware'
     or measured_record.client_reading_id <> measured_run then
    raise exception 'Measured initial check did not persist with its planted crop.';
  end if;

  if sample_log_id is null or sample_crop is null
     or sample_record.id is null
     or sample_record.crop_id <> sample_crop
     or sample_record.soil_raw <> 1785
     or sample_record.soil_moisture <> 85
     or sample_record.source <> 'Estimated sample'
     or sample_record.provenance_status <> 'simulated'
     or sample_record.soil_moisture_calibrated is distinct from false
     or sample_record.client_reading_id <> sample_run then
    raise exception 'Selected sample did not persist as simulated crop history.';
  end if;
end;
$$;

select plan(1);
select pass('measured and simulated planting snapshots persist with crop history');
select * from finish();

rollback;
