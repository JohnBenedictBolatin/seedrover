-- Guided rover rows are first saved as operation logs. Only explicit worker
-- confirmation can create a crop; retries are keyed by the rover run UUID.

-- Keep the established crop lifecycle routine as an internal helper. The
-- public RPC name below becomes a compatibility logger and must not be called
-- recursively by the new confirmation workflow.
do $$
begin
  if to_regprocedure('public.record_rover_planting_session_confirmed_internal(uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,integer,numeric,numeric,bigint,text,text,jsonb)') is null then
    alter function public.record_rover_planting_session(
      uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,
      integer,numeric,numeric,bigint,text,text,jsonb
    ) rename to record_rover_planting_session_confirmed_internal;
  end if;
end;
$$;
revoke all on function public.record_rover_planting_session_confirmed_internal(
  uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,
  integer,numeric,numeric,bigint,text,text,jsonb
) from public, anon, authenticated;

alter table public.planting_logs
  add column if not exists confirmation_outcome text not null default 'Legacy',
  add column if not exists confirmed_by uuid references public.profiles(id) on delete set null,
  add column if not exists confirmed_at timestamptz,
  add column if not exists crop_id uuid references public.crops(id) on delete set null,
  add column if not exists soil_captured_at timestamptz;

alter table public.planting_logs
  drop constraint if exists planting_logs_confirmation_outcome_allowed;
alter table public.planting_logs
  add constraint planting_logs_confirmation_outcome_allowed check (
    confirmation_outcome in ('Legacy', 'Pending', 'Row Planted', 'Some Planted', 'None Planted')
  );

update public.planting_logs pl
set crop_id = c.id
from public.crops c
where c.planting_log_id = pl.id and pl.crop_id is null;

create index if not exists planting_logs_confirmation_date_idx
  on public.planting_logs(confirmation_outcome, started_at desc);

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
  select pl.soil_moisture_percent, pl.soil_moisture_percent,
    coalesce((pl.sync_payload #>> '{status,soil_temperature_c}')::numeric,
      nullif(pl.environmental_temperature, 0)),
    (pl.sync_payload #>> '{status,air_temperature_c}')::numeric,
    (pl.sync_payload #>> '{status,humidity_percent}')::numeric,
    coalesce(pl.soil_captured_at, pl.completed_at, pl.started_at, now()),
    pl.rover_id, new.id, pl.id, pl.soil_raw, 'Hardware'
  from public.planting_logs pl
  where pl.id = new.planting_log_id
    and not exists (select 1 from public.sensor_readings sr where sr.planting_log_id = pl.id);
  return new;
end;
$$;

create or replace function public.sync_rover_planting_run(p_run jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  run_id uuid := nullif(p_run->>'session_id', '')::uuid;
  seed_key text := p_run->>'crop_profile_key';
  field_value text := nullif(btrim(p_run->>'field_label'), '');
  target_cycles integer := (p_run->>'target_drop_cycles')::integer;
  completed_cycles integer := (p_run->>'completed_drop_cycles')::integer;
  operation_status text := p_run->>'planting_status';
  outcome_key text := coalesce(nullif(p_run->>'confirmation_outcome', ''), 'pending');
  expected_confirmation text;
  profile_row public.crop_profiles%rowtype;
  prior_row public.planting_logs%rowtype;
  planting_id uuid;
  crop_id_value uuid;
  planting_day date;
  area_value numeric(12,2);
  created_crop_id uuid;
begin
  if actor is null or not public.has_permission('rover.planting.control') then
    raise exception 'rover.planting.control permission required';
  end if;
  if run_id is null or target_cycles is null or target_cycles not between 1 and 20
     or completed_cycles is null or completed_cycles < 0 or completed_cycles > target_cycles then
    raise exception 'Invalid planting run identity or cycle counts';
  end if;
  if operation_status not in ('Completed', 'Partial', 'Failed', 'Cancelled') then
    raise exception 'Invalid planting run outcome';
  end if;
  if outcome_key not in ('pending', 'row_planted', 'some_planted', 'none_planted') then
    raise exception 'Invalid operator confirmation';
  end if;
  if outcome_key = 'row_planted' and completed_cycles <> target_cycles then
    raise exception 'A full row can only be confirmed after all requested cycles complete';
  end if;
  select * into profile_row from public.crop_profiles
    where profile_key = seed_key and is_active;
  if profile_row.profile_key is null then raise exception 'Unknown crop profile'; end if;

  select * into prior_row from public.planting_logs
    where client_session_id = run_id for update;
  if prior_row.id is not null and prior_row.operator_id <> actor
     and not public.is_admin() then
    raise exception 'This planting run belongs to another operator';
  end if;
  expected_confirmation := case outcome_key
    when 'row_planted' then 'Row Planted'
    when 'some_planted' then 'Some Planted'
    else 'None Planted'
  end;
  if prior_row.id is not null and prior_row.confirmation_outcome not in ('Pending', 'Legacy')
     and outcome_key <> 'pending'
     and prior_row.confirmation_outcome <> expected_confirmation then
    raise exception 'The planting result was already confirmed differently';
  end if;

  planting_day := (coalesce(nullif(p_run->>'started_at', '')::timestamptz, now()) at time zone 'Asia/Manila')::date;
  area_value := round(greatest(coalesce(nullif(p_run->>'measured_distance_cm', '')::numeric, 0), 0) / 100.0
    * greatest(coalesce(nullif(p_run->>'row_spacing_cm', '')::numeric, profile_row.row_spacing_cm, 0), 0) / 100.0, 2);

  if prior_row.id is null then
    insert into public.planting_logs (
      operator_id, crop_name, planting_date, planting_time, planting_status, notes,
      client_session_id, rover_id, field_label, crop_profile_key, target_drop_cycles,
      completed_drop_cycles, measured_distance_cm, calculated_area_m2, row_spacing_cm,
      soil_raw, soil_moisture_percent, environmental_temperature, soil_temperature_c,
      air_temperature_c, humidity_percent, firmware_version, started_at, completed_at,
      failure_code, sync_payload, confirmation_outcome, soil_captured_at
    ) values (
      actor, profile_row.display_name, planting_day,
      (coalesce(nullif(p_run->>'started_at', '')::timestamptz, now()) at time zone 'Asia/Manila')::time,
      operation_status, 'Rover row operation saved; crop creation awaits worker confirmation.',
      run_id, coalesce(nullif(btrim(p_run->>'rover_id'), ''), 'SeedRover-01'), field_value,
      seed_key, target_cycles, completed_cycles,
      nullif(p_run->>'measured_distance_cm', '')::numeric, nullif(area_value, 0),
      coalesce(nullif(p_run->>'row_spacing_cm', '')::numeric, profile_row.row_spacing_cm),
      nullif(p_run->>'soil_raw', '')::integer,
      nullif(p_run->>'soil_moisture_percent', '')::numeric,
      nullif(p_run->>'soil_temperature_c', '')::numeric,
      nullif(p_run->>'soil_temperature_c', '')::numeric,
      nullif(p_run->>'air_temperature_c', '')::numeric,
      nullif(p_run->>'humidity_percent', '')::numeric,
      nullif(p_run->>'firmware_version', ''),
      nullif(p_run->>'started_at', '')::timestamptz,
      nullif(p_run->>'completed_at', '')::timestamptz,
      nullif(p_run->>'failure_code', ''), coalesce(p_run->'sync_payload', '{}'::jsonb),
      'Pending', nullif(p_run->>'soil_captured_at', '')::timestamptz
    ) on conflict (client_session_id) where client_session_id is not null do nothing
      returning id into planting_id;
    if planting_id is null then
      select * into prior_row from public.planting_logs
        where client_session_id = run_id for update;
      if prior_row.id is null or (prior_row.operator_id <> actor and not public.is_admin()) then
        raise exception 'This planting run belongs to another operator';
      end if;
      planting_id := prior_row.id;
    end if;
  else
    planting_id := prior_row.id;
    if prior_row.operator_id <> actor and public.is_admin() then
      raise exception 'Administrators may not reassign a planting run to themselves';
    end if;
    update public.planting_logs set
      planting_status = operation_status,
      completed_drop_cycles = greatest(completed_drop_cycles, completed_cycles),
      measured_distance_cm = nullif(p_run->>'measured_distance_cm', '')::numeric,
      calculated_area_m2 = nullif(area_value, 0),
      soil_raw = coalesce(nullif(p_run->>'soil_raw', '')::integer, soil_raw),
      soil_moisture_percent = coalesce(nullif(p_run->>'soil_moisture_percent', '')::numeric, soil_moisture_percent),
      soil_temperature_c = coalesce(nullif(p_run->>'soil_temperature_c', '')::numeric, soil_temperature_c),
      air_temperature_c = coalesce(nullif(p_run->>'air_temperature_c', '')::numeric, air_temperature_c),
      humidity_percent = coalesce(nullif(p_run->>'humidity_percent', '')::numeric, humidity_percent),
      completed_at = coalesce(nullif(p_run->>'completed_at', '')::timestamptz, completed_at),
      failure_code = nullif(p_run->>'failure_code', ''),
      soil_captured_at = coalesce(nullif(p_run->>'soil_captured_at', '')::timestamptz, soil_captured_at),
      sync_payload = coalesce(p_run->'sync_payload', sync_payload),
      updated_at = now()
    where id = planting_id;
  end if;

  if outcome_key <> 'pending' then
    if outcome_key in ('row_planted', 'some_planted') then
      if completed_cycles > 0 then
        created_crop_id := public.record_rover_planting_session_confirmed_internal(
        run_id, coalesce(nullif(btrim(p_run->>'rover_id'), ''), 'SeedRover-01'),
        seed_key, field_value, target_cycles, completed_cycles,
        nullif(p_run->>'measured_distance_cm', '')::numeric,
        coalesce(nullif(p_run->>'row_spacing_cm', '')::numeric, profile_row.row_spacing_cm),
        case when outcome_key = 'row_planted' then 'Completed' else 'Partial' end,
        nullif(p_run->>'started_at', '')::timestamptz,
        nullif(p_run->>'completed_at', '')::timestamptz,
        nullif(p_run->>'soil_raw', '')::integer,
        nullif(p_run->>'soil_moisture_percent', '')::numeric,
        nullif(p_run->>'soil_temperature_c', '')::numeric,
        null, nullif(p_run->>'firmware_version', ''), nullif(p_run->>'failure_code', ''),
        coalesce(p_run->'sync_payload', '{}'::jsonb)
      );
        -- Gate cycles are the only quantity the rover can actually confirm.
        -- Strip seed-estimate metadata if present on a pre-existing activity.
        update public.crop_activities set
          notes = format('%s of %s planned planting gate cycles completed.', completed_cycles, target_cycles),
          metadata = coalesce(metadata, '{}'::jsonb)
            - 'estimated_seed_count_min' - 'estimated_seed_count_max'
        where crop_id = created_crop_id
          and idempotency_key = 'planting:' || run_id::text;
      else
        select id into created_crop_id from public.crops where planting_log_id = planting_id;
        if created_crop_id is null then
          insert into public.crops (
            planting_log_id, crop_name, assigned_manager, planting_date, estimated_harvest,
            growth_stage, maintenance_notes, crop_status, crop_profile_key, profile_version,
            planting_source, propagation_method, field_label, completed_drop_cycles,
            harvest_window_start, harvest_window_end, forecast_confidence,
            expected_stage, current_care_status
          ) values (
            planting_id, profile_row.display_name, actor, planting_day,
            case when seed_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
            'Seeded', profile_row.advisory, 'Active', profile_row.profile_key, profile_row.version,
            'Rover', profile_row.propagation_method, field_value, 0,
            case when seed_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
            case when seed_key = 'calamansi' then null else planting_day + profile_row.harvest_end_days end,
            'Low',
            case when seed_key = 'calamansi' then 'Germination and nursery review' else 'Germination' end,
            'Worker confirmed planting; no completed rover gate cycles were acknowledged.'
          ) returning id into created_crop_id;
        end if;
      end if;
      crop_id_value := created_crop_id;
    end if;
    update public.planting_logs set
      confirmation_outcome = case outcome_key
        when 'row_planted' then 'Row Planted'
        when 'some_planted' then 'Some Planted'
        else 'None Planted' end,
      confirmed_by = actor,
      confirmed_at = coalesce(confirmed_at, now()),
      crop_id = coalesce(crop_id_value, crop_id),
      updated_at = now()
    where id = planting_id returning crop_id into crop_id_value;
  else
    select crop_id into crop_id_value from public.planting_logs where id = planting_id;
  end if;

  return jsonb_build_object('planting_log_id', planting_id, 'crop_id', crop_id_value,
    'confirmation_outcome', (select confirmation_outcome from public.planting_logs where id = planting_id));
end;
$$;

revoke all on function public.sync_rover_planting_run(jsonb) from public;
grant execute on function public.sync_rover_planting_run(jsonb) to authenticated;

-- Compatibility for already-installed apps: record the operation, but never
-- infer that a crop exists merely because the rover opened its gate.
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
  result jsonb;
begin
  result := public.sync_rover_planting_run(jsonb_build_object(
    'session_id', p_client_session_id, 'rover_id', p_rover_id,
    'crop_profile_key', p_crop_profile_key, 'field_label', p_field_label,
    'target_drop_cycles', p_target_drop_cycles,
    'completed_drop_cycles', p_completed_drop_cycles,
    'measured_distance_cm', p_measured_distance_cm, 'row_spacing_cm', p_row_spacing_cm,
    'planting_status', p_status, 'started_at', p_started_at, 'completed_at', p_completed_at,
    'soil_raw', p_soil_raw, 'soil_moisture_percent', p_soil_moisture_percent,
    'soil_temperature_c', p_sync_payload #>> '{status,soil_temperature_c}',
    'air_temperature_c', p_sync_payload #>> '{status,air_temperature_c}',
    'humidity_percent', p_sync_payload #>> '{status,humidity_percent}',
    'firmware_version', p_firmware_version, 'failure_code', p_failure_code,
    'sync_payload', p_sync_payload, 'confirmation_outcome', 'pending'
  ));
  return null;
end;
$$;

revoke all on function public.record_rover_planting_session(uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,integer,numeric,numeric,bigint,text,text,jsonb) from public;
grant execute on function public.record_rover_planting_session(uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,integer,numeric,numeric,bigint,text,text,jsonb) to authenticated;
