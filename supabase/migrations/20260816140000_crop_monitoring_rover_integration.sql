-- Connected rover planting, crop-care profiles, weather intelligence, and reminders.

do $$
begin
  begin
    create extension if not exists pg_cron with schema pg_catalog;
  exception when others then
    raise notice 'pg_cron is unavailable in this environment; configure the hosted schedule after deployment.';
  end;
  begin
    create extension if not exists pg_net with schema extensions;
  exception when others then
    raise notice 'pg_net is unavailable in this environment; scheduled Edge Function calls require it in production.';
  end;
end;
$$;

alter table public.planting_logs
  add column if not exists client_session_id uuid,
  add column if not exists rover_id text not null default 'seedrover-01',
  add column if not exists field_label text,
  add column if not exists crop_profile_key text,
  add column if not exists target_drop_cycles integer,
  add column if not exists completed_drop_cycles integer not null default 0,
  add column if not exists measured_distance_cm numeric(12,2),
  add column if not exists calculated_area_m2 numeric(12,2),
  add column if not exists row_spacing_cm numeric(8,2),
  add column if not exists soil_raw integer,
  add column if not exists calibrated_value numeric(5,2),
  add column if not exists soil_moisture_percent numeric(5,2),
  add column if not exists environmental_temperature numeric(5,2),
  add column if not exists seed_load_raw bigint,
  add column if not exists firmware_version text,
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists failure_code text,
  add column if not exists sync_payload jsonb not null default '{}'::jsonb;

create unique index if not exists planting_logs_client_session_id_idx
  on public.planting_logs(client_session_id)
  where client_session_id is not null;

alter table public.planting_logs drop constraint if exists planting_logs_status_allowed;
alter table public.planting_logs add constraint planting_logs_status_allowed check (
  planting_status in ('Pending', 'In Progress', 'Completed', 'Partial', 'Failed', 'Cancelled')
);
alter table public.planting_logs drop constraint if exists planting_logs_drop_counts_valid;
alter table public.planting_logs add constraint planting_logs_drop_counts_valid check (
  completed_drop_cycles >= 0
  and (target_drop_cycles is null or target_drop_cycles > 0)
  and (target_drop_cycles is null or completed_drop_cycles <= target_drop_cycles)
);

create table if not exists public.crop_profiles (
  profile_key text primary key,
  display_name text not null,
  scientific_name text,
  version integer not null default 1,
  lifecycle_type text not null,
  propagation_method text not null,
  row_spacing_cm numeric(8,2),
  drop_spacing_cm numeric(8,2),
  estimated_seeds_per_drop_min numeric(8,2) not null default 1,
  estimated_seeds_per_drop_max numeric(8,2) not null default 1,
  harvest_start_days integer,
  harvest_end_days integer,
  water_plan jsonb not null default '{}'::jsonb,
  fertilizer_plan jsonb not null default '{}'::jsonb,
  stage_plan jsonb not null default '[]'::jsonb,
  source_title text not null,
  source_url text not null,
  source_published_on date,
  advisory text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crop_profiles_lifecycle_allowed check (lifecycle_type in ('Annual', 'Perennial Nursery')),
  constraint crop_profiles_seed_range_valid check (
    estimated_seeds_per_drop_min > 0
    and estimated_seeds_per_drop_max >= estimated_seeds_per_drop_min
  ),
  constraint crop_profiles_harvest_range_valid check (
    harvest_start_days is null
    or harvest_end_days is null
    or harvest_end_days >= harvest_start_days
  )
);

insert into public.crop_profiles (
  profile_key, display_name, scientific_name, lifecycle_type, propagation_method,
  row_spacing_cm, drop_spacing_cm, estimated_seeds_per_drop_min,
  estimated_seeds_per_drop_max, harvest_start_days, harvest_end_days,
  water_plan, fertilizer_plan, stage_plan, source_title, source_url,
  source_published_on, advisory
) values
(
  'calamansi', 'Calamansi', 'Citrofortunella microcarpa', 'Perennial Nursery', 'Direct seed to nursery',
  30, 10, 1, 3, 1095, 1460,
  '{"strategy":"Keep the seedbed evenly moist and inspect daily; avoid standing water.","initial_check_interval_hours":24,"bearing_tree_seasonal_need_mm_min":900,"bearing_tree_seasonal_need_mm_max":1200,"critical_stages":["Germinating","Nursery Seedling","Establishing","Flowering","Fruit Set"]}'::jsonb,
  '{"soil_test_first":true,"events":[{"stage":"Established Seedling","offset_days":30,"amount_min":50,"amount_max":100,"unit":"g/tree","material":"ammonium sulfate or urea","repeat_days":120},{"stage":"Second Year","amount_min":200,"amount_max":300,"unit":"g/tree","material":"ammonium sulfate or urea","repeat_days":120}],"warning":"Apply only after field confirmation and keep fertilizer away from the stem."}'::jsonb,
  '[{"stage":"Seedbed","start_day":0},{"stage":"Germinating","start_day":7},{"stage":"Nursery Seedling","start_day":30},{"stage":"Transplant Review","start_day":60},{"stage":"Establishing","requires_activity":"Transplanted"},{"stage":"Juvenile","start_day":365},{"stage":"First Bearing","start_day":1095}]'::jsonb,
  'ATI Calamansi Production and Processing',
  'https://ati2.da.gov.ph/ati-4b/content/sites/default/files/2022-12/calamansi_final.pdf',
  '2022-12-01',
  'Seed-grown calamansi has a long and variable juvenile period. Show a first-bearing window only after transplanting and confirm care with a local agriculturist.'
),
(
  'sitaw', 'Sitaw', 'Vigna unguiculata subsp. sesquipedalis', 'Annual', 'Direct seed',
  100, 50, 2, 3, 60, 70,
  '{"strategy":"Maintain regular moisture without waterlogging.","seasonal_need_mm_min":300,"seasonal_need_mm_max":500,"critical_stages":["Seeded","Flowering","Pod Formation"],"crop_coefficients":{"initial":0.4,"development":0.7,"mid":1.0,"late":0.9}}'::jsonb,
  '{"soil_test_first":true,"fallbacks":[{"material":"14-14-14 complete fertilizer","amount":3,"unit":"50 kg bags/ha","timing":"Basal, dry season"},{"material":"organic fertilizer","amount":20,"unit":"bags/ha","timing":"Basal"},{"material":"foliar fertilizer","timing":"Flowering"}],"warning":"Use fallback rates only when no soil analysis is available."}'::jsonb,
  '[{"stage":"Seeded","start_day":0},{"stage":"Germinating","start_day":5},{"stage":"Vegetative","start_day":10},{"stage":"Trellising","start_day":20},{"stage":"Flowering","start_day":35},{"stage":"Pod Formation","start_day":45},{"stage":"First Harvest","start_day":60},{"stage":"Repeated Harvest","repeat_days":4}]'::jsonb,
  'DA-ATI Sitaw Production Guides',
  'https://ati2.da.gov.ph/ati-4b/content/sites/default/files/2024-06/Sitaw%20IEC%20a.pdf',
  '2024-06-01',
  'Amounts are field estimates. Verify soil condition, drainage, variety, and product label before applying water or fertilizer.'
),
(
  'peanut', 'Peanut', 'Arachis hypogaea', 'Annual', 'Direct seed',
  40, 10, 1, 2, 95, 100,
  '{"strategy":"Use light, frequent irrigation when needed and maintain drainage.","seasonal_need_mm_min":500,"seasonal_need_mm_max":600,"critical_stages":["Seeded","Vegetative","Pegging","Pod Development"],"crop_coefficients":{"initial":0.4,"development":0.7,"mid":1.0,"late":0.6}}'::jsonb,
  '{"soil_test_first":true,"fallbacks":[{"material":"14-14-14 or 16-20-0","amount":2,"unit":"50 kg bags/ha","timing":"Basal"},{"material":"calcium sulfate","amount_dry":200,"amount_wet":300,"unit":"kg/ha","timing":"Peak flowering, 20-35 days after emergence"},{"material":"boron foliar fertilizer","amount_min":200,"amount_max":300,"unit":"g/ha","timing":"25-30 days after planting"}],"warning":"Calcium, boron, and complete fertilizer must follow soil analysis and product-label guidance."}'::jsonb,
  '[{"stage":"Seeded","start_day":0},{"stage":"Germinating","start_day":7},{"stage":"Vegetative","start_day":14},{"stage":"Flowering","start_day":25},{"stage":"Pegging","start_day":35},{"stage":"Pod Development","start_day":50},{"stage":"Maturity Check","start_day":95}]'::jsonb,
  'DA-ATI Peanut Production and Processing',
  'https://ati2.da.gov.ph/ati-2/content/publications/admin/peanut-production-and-processing',
  '2025-06-27',
  'Maturity depends on variety and observed pod condition. The date range is an inspection window, not an automatic harvest instruction.'
)
on conflict (profile_key) do nothing;

create table if not exists public.crop_profile_versions (
  profile_key text not null,
  version integer not null,
  profile_snapshot jsonb not null,
  source_title text not null,
  source_url text not null,
  source_published_on date,
  created_at timestamptz not null default now(),
  primary key (profile_key, version)
);

insert into public.crop_profile_versions(profile_key, version, profile_snapshot, source_title, source_url, source_published_on)
select profile_key, version, to_jsonb(profile), source_title, source_url, source_published_on
from public.crop_profiles profile
on conflict (profile_key, version) do nothing;

create or replace function public.snapshot_crop_profile_version()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.crop_profile_versions(profile_key, version, profile_snapshot, source_title, source_url, source_published_on)
  values (new.profile_key, new.version, to_jsonb(new), new.source_title, new.source_url, new.source_published_on)
  on conflict (profile_key, version) do update set profile_snapshot = excluded.profile_snapshot;
  return new;
end;
$$;
drop trigger if exists crop_profiles_snapshot_version on public.crop_profiles;
create trigger crop_profiles_snapshot_version after insert or update on public.crop_profiles
  for each row execute function public.snapshot_crop_profile_version();

alter table public.crops
  add column if not exists crop_profile_key text references public.crop_profiles(profile_key),
  add column if not exists profile_version integer,
  add column if not exists planting_source text not null default 'Legacy',
  add column if not exists propagation_method text,
  add column if not exists field_label text,
  add column if not exists field_area_m2 numeric(12,2),
  add column if not exists completed_drop_cycles integer,
  add column if not exists estimated_seed_count_min numeric(12,2),
  add column if not exists estimated_seed_count_max numeric(12,2),
  add column if not exists harvest_window_start date,
  add column if not exists harvest_window_end date,
  add column if not exists forecast_confidence text not null default 'Low',
  add column if not exists expected_stage text,
  add column if not exists current_care_status text not null default 'Monitoring',
  add column if not exists last_watered_at timestamptz,
  add column if not exists last_fertilized_at timestamptz,
  add column if not exists manual_creation_reason text,
  add column if not exists transplanted_at timestamptz;

update public.crops
set planting_source = 'Legacy',
    harvest_window_start = coalesce(harvest_window_start, estimated_harvest),
    harvest_window_end = coalesce(harvest_window_end, estimated_harvest),
    crop_profile_key = case
      when lower(crop_name) like '%calamansi%' then 'calamansi'
      when lower(crop_name) like '%sitaw%' then 'sitaw'
      when lower(crop_name) like '%peanut%' then 'peanut'
      else crop_profile_key
    end
where planting_source = 'Legacy';

alter table public.crops drop constraint if exists crops_planting_source_allowed;
alter table public.crops add constraint crops_planting_source_allowed check (
  planting_source in ('Rover', 'Manual', 'Legacy')
);
alter table public.crops drop constraint if exists crops_forecast_confidence_allowed;
alter table public.crops add constraint crops_forecast_confidence_allowed check (
  forecast_confidence in ('High', 'Medium', 'Low', 'Unavailable')
);
alter table public.crops drop constraint if exists crops_growth_stage_allowed;
alter table public.crops add constraint crops_growth_stage_allowed check (
  growth_stage in (
    'Seeded','Seedbed','Germinating','Nursery Seedling','Transplant Review','Establishing','Juvenile',
    'Vegetative','Trellising','Flowering','Pod Formation','Pegging','Pod Development','Maturity Check',
    'First Bearing','Fruiting','Harvest Ready','Repeated Harvest','Completed'
  )
);
alter table public.crops drop constraint if exists crops_field_values_valid;
alter table public.crops add constraint crops_field_values_valid check (
  (field_area_m2 is null or field_area_m2 > 0)
  and (completed_drop_cycles is null or completed_drop_cycles >= 0)
  and (estimated_seed_count_min is null or estimated_seed_count_min >= 0)
  and (estimated_seed_count_max is null or estimated_seed_count_max >= coalesce(estimated_seed_count_min, 0))
  and (harvest_window_start is null or harvest_window_end is null or harvest_window_end >= harvest_window_start)
);

create table if not exists public.crop_activities (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null references public.crops(id) on delete cascade,
  activity_type text not null,
  performed_at timestamptz not null default now(),
  performed_by uuid references public.profiles(id) on delete set null,
  quantity numeric(12,2),
  unit text,
  material text,
  notes text,
  observed_stage text,
  task_id uuid,
  source text not null default 'User',
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint crop_activities_type_allowed check (
    activity_type in ('Planted','Watered','Fertilized','Inspected','Stage Observed','Transplanted','Harvested','Not Harvested','Planting Failed')
  ),
  constraint crop_activities_source_allowed check (source in ('Rover','User','System','Legacy')),
  constraint crop_activities_quantity_valid check (quantity is null or quantity >= 0)
);
create unique index if not exists crop_activities_idempotency_idx
  on public.crop_activities(idempotency_key) where idempotency_key is not null;
create index if not exists crop_activities_crop_time_idx
  on public.crop_activities(crop_id, performed_at desc);

create table if not exists public.crop_tasks (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null references public.crops(id) on delete cascade,
  task_type text not null,
  title text not null,
  recommendation text not null,
  due_at timestamptz not null,
  due_window_end timestamptz,
  status text not null default 'Due',
  priority text not null default 'Routine',
  recommendation_data jsonb not null default '{}'::jsonb,
  forecast_basis jsonb not null default '{}'::jsonb,
  deduplication_key text not null,
  completed_at timestamptz,
  completed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crop_tasks_type_allowed check (task_type in ('Water','Fertilize','Inspect','Transplant','Harvest Check','Weather Risk')),
  constraint crop_tasks_status_allowed check (status in ('Upcoming','Due','Overdue','Postponed','Completed','Dismissed')),
  constraint crop_tasks_priority_allowed check (priority in ('Routine','Important','Critical')),
  constraint crop_tasks_due_window_valid check (due_window_end is null or due_window_end >= due_at),
  unique (deduplication_key)
);
create index if not exists crop_tasks_due_idx on public.crop_tasks(status, due_at);
alter table public.crop_activities
  drop constraint if exists crop_activities_task_id_fkey;
alter table public.crop_activities
  add constraint crop_activities_task_id_fkey foreign key (task_id) references public.crop_tasks(id) on delete set null;

create table if not exists public.farm_weather_settings (
  id boolean primary key default true check (id),
  latitude numeric(9,6),
  longitude numeric(9,6),
  pagasa_region text,
  pagasa_province text,
  pagasa_municipality text,
  pagasa_psgc text,
  timezone text not null default 'Asia/Manila',
  soil_type text not null default 'Unknown',
  irrigation_method text not null default 'Manual hose or watering can',
  irrigation_efficiency numeric(4,3) not null default 0.80,
  routine_digest_hour integer not null default 6,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint farm_weather_coordinates_pair check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  ),
  constraint farm_weather_efficiency_valid check (irrigation_efficiency > 0 and irrigation_efficiency <= 1),
  constraint farm_weather_digest_hour_valid check (routine_digest_hour between 0 and 23)
);
insert into public.farm_weather_settings(id) values (true) on conflict (id) do nothing;

create table if not exists public.weather_forecasts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  forecast_for timestamptz not null,
  issued_at timestamptz,
  precipitation_probability numeric(5,2),
  precipitation_mm numeric(10,3),
  et0_mm numeric(10,3),
  temperature_c numeric(5,2),
  humidity_percent numeric(5,2),
  condition text,
  location_label text,
  raw_payload jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null default now(),
  constraint weather_forecasts_provider_allowed check (provider in ('PAGASA','Open-Meteo')),
  unique(provider, forecast_for)
);
create index if not exists weather_forecasts_time_idx on public.weather_forecasts(forecast_for desc);

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint push_device_tokens_platform_allowed check (platform in ('android','ios','web'))
);
create index if not exists push_device_tokens_profile_idx on public.push_device_tokens(profile_id, is_active);

create table if not exists public.rover_calibrations (
  rover_id text primary key,
  left_encoder_ticks_per_meter numeric(12,3),
  right_encoder_ticks_per_meter numeric(12,3),
  soil_dry_raw integer,
  soil_wet_raw integer,
  rake_to_gate_offset_cm numeric(8,2) not null default 18,
  seed_gate_profiles jsonb not null default '{"calamansi":{"gate_open_ms":120,"estimated_min":1,"estimated_max":3},"sitaw":{"gate_open_ms":120,"estimated_min":2,"estimated_max":3},"peanut":{"gate_open_ms":120,"estimated_min":1,"estimated_max":2}}'::jsonb,
  calibrated_by uuid references public.profiles(id) on delete set null,
  calibrated_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint rover_calibration_ticks_valid check (
    (left_encoder_ticks_per_meter is null or left_encoder_ticks_per_meter > 0)
    and (right_encoder_ticks_per_meter is null or right_encoder_ticks_per_meter > 0)
  )
);

alter table public.sensor_readings
  add column if not exists rover_id text not null default 'seedrover-01',
  add column if not exists crop_id uuid references public.crops(id) on delete set null,
  add column if not exists planting_log_id uuid references public.planting_logs(id) on delete set null,
  add column if not exists soil_raw integer,
  add column if not exists calibrated_value numeric(5,2),
  add column if not exists calibration_version text,
  add column if not exists source text not null default 'Cloud';

update public.sensor_readings set calibrated_value = soil_moisture where calibrated_value is null;
alter table public.sensor_readings drop constraint if exists sensor_readings_calibrated_value_range;
alter table public.sensor_readings add constraint sensor_readings_calibrated_value_range check (
  calibrated_value is null or calibrated_value between 0 and 100
);

alter table public.crop_profiles enable row level security;
alter table public.crop_profile_versions enable row level security;
alter table public.crop_activities enable row level security;
alter table public.crop_tasks enable row level security;
alter table public.farm_weather_settings enable row level security;
alter table public.weather_forecasts enable row level security;
alter table public.push_device_tokens enable row level security;
alter table public.rover_calibrations enable row level security;

drop policy if exists crop_profiles_select_allowed on public.crop_profiles;
drop policy if exists crop_profiles_manage_allowed on public.crop_profiles;
drop policy if exists crop_profile_versions_select_allowed on public.crop_profile_versions;
drop policy if exists crop_activities_select_allowed on public.crop_activities;
drop policy if exists crop_activities_insert_allowed on public.crop_activities;
drop policy if exists crop_tasks_select_allowed on public.crop_tasks;
drop policy if exists crop_tasks_update_allowed on public.crop_tasks;
drop policy if exists farm_weather_settings_select_allowed on public.farm_weather_settings;
drop policy if exists farm_weather_settings_manage_allowed on public.farm_weather_settings;
drop policy if exists weather_forecasts_select_allowed on public.weather_forecasts;
drop policy if exists push_device_tokens_own_access on public.push_device_tokens;
drop policy if exists rover_calibrations_select_allowed on public.rover_calibrations;
drop policy if exists rover_calibrations_manage_allowed on public.rover_calibrations;

create policy crop_profiles_select_allowed on public.crop_profiles for select to authenticated
  using (public.has_permission('crops.view'));
create policy crop_profiles_manage_allowed on public.crop_profiles for all to authenticated
  using (public.is_admin() or public.has_permission('crops.manage'))
  with check (public.is_admin() or public.has_permission('crops.manage'));
create policy crop_profile_versions_select_allowed on public.crop_profile_versions for select to authenticated
  using (public.has_permission('crops.view'));
create policy crop_activities_select_allowed on public.crop_activities for select to authenticated
  using (public.has_permission('crops.view'));
create policy crop_activities_insert_allowed on public.crop_activities for insert to authenticated
  with check (public.has_permission('crops.manage') and (performed_by is null or performed_by = auth.uid()));
create policy crop_tasks_select_allowed on public.crop_tasks for select to authenticated
  using (public.has_permission('crops.view'));
create policy crop_tasks_update_allowed on public.crop_tasks for update to authenticated
  using (public.has_permission('crops.manage')) with check (public.has_permission('crops.manage'));
create policy farm_weather_settings_select_allowed on public.farm_weather_settings for select to authenticated
  using (public.has_permission('crops.view'));
create policy farm_weather_settings_manage_allowed on public.farm_weather_settings for all to authenticated
  using (public.is_admin() or public.has_permission('crops.manage'))
  with check (public.is_admin() or public.has_permission('crops.manage'));
create policy weather_forecasts_select_allowed on public.weather_forecasts for select to authenticated
  using (public.has_permission('crops.view'));
create policy push_device_tokens_own_access on public.push_device_tokens for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy rover_calibrations_select_allowed on public.rover_calibrations for select to authenticated
  using (public.has_permission('rover.view') or public.has_permission('rover.planting.control'));
create policy rover_calibrations_manage_allowed on public.rover_calibrations for all to authenticated
  using (public.has_permission('rover.planting.control')) with check (public.has_permission('rover.planting.control'));

create or replace function public.register_push_device_token(p_token text, p_platform text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  actor uuid := auth.uid();
  token_id uuid;
begin
  if actor is null then raise exception 'Sign in before registering push notifications'; end if;
  if nullif(btrim(p_token), '') is null or p_platform not in ('android','ios','web') then
    raise exception 'Invalid push token or platform';
  end if;
  insert into public.push_device_tokens(profile_id, token, platform, is_active, last_seen_at)
  values (actor, p_token, p_platform, true, now())
  on conflict (token) do update set
    profile_id = actor,
    platform = excluded.platform,
    is_active = true,
    last_seen_at = now()
  returning id into token_id;
  return token_id;
end;
$$;
revoke all on function public.register_push_device_token(text,text) from public;
grant execute on function public.register_push_device_token(text,text) to authenticated;

drop policy if exists crops_insert_allowed on public.crops;
drop policy if exists crops_insert_manager_manual_only on public.crops;
create policy crops_insert_manager_manual_only on public.crops for insert to authenticated
  with check (
    planting_source = 'Manual'
    and nullif(btrim(manual_creation_reason), '') is not null
    and assigned_manager = auth.uid()
    and exists (
      select 1 from public.profiles p join public.roles r on r.id = p.role_id
      where p.id = auth.uid() and p.is_active and r.role_name = 'Farm Planting Manager'
    )
  );

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
  profile_row public.crop_profiles;
  planting_id uuid;
  crop_id uuid;
  area_m2 numeric(12,2);
  planting_day date;
  db_status text;
  seeds_per_drop_min numeric;
  seeds_per_drop_max numeric;
begin
  if actor is null or not public.has_permission('rover.planting.control') then
    raise exception 'rover.planting.control permission required';
  end if;
  if p_target_drop_cycles <= 0 or p_completed_drop_cycles < 0 or p_completed_drop_cycles > p_target_drop_cycles then
    raise exception 'Invalid planting drop counts';
  end if;
  if p_status not in ('Completed','Partial','Failed','Cancelled') then
    raise exception 'Invalid terminal planting status';
  end if;
  select * into profile_row from public.crop_profiles
  where profile_key = p_crop_profile_key and is_active;
  if profile_row.profile_key is null then raise exception 'Unknown crop profile'; end if;
  seeds_per_drop_min := coalesce(nullif(p_sync_payload->>'estimated_seeds_min', '')::numeric, profile_row.estimated_seeds_per_drop_min);
  seeds_per_drop_max := coalesce(nullif(p_sync_payload->>'estimated_seeds_max', '')::numeric, profile_row.estimated_seeds_per_drop_max);
  if seeds_per_drop_min <= 0 or seeds_per_drop_max < seeds_per_drop_min then
    raise exception 'Invalid estimated seeds-per-drop calibration';
  end if;

  area_m2 := round(greatest(coalesce(p_measured_distance_cm, 0), 0) / 100.0 * greatest(coalesce(p_row_spacing_cm, profile_row.row_spacing_cm, 0), 0) / 100.0, 2);
  planting_day := (coalesce(p_started_at, now()) at time zone 'Asia/Manila')::date;
  db_status := p_status;

  insert into public.planting_logs (
    operator_id, crop_name, planting_date, planting_time, planting_status, notes,
    client_session_id, rover_id, field_label, crop_profile_key, target_drop_cycles,
    completed_drop_cycles, measured_distance_cm, calculated_area_m2, row_spacing_cm,
    soil_raw, soil_moisture_percent, environmental_temperature, seed_load_raw,
    firmware_version, started_at, completed_at, failure_code, sync_payload
  ) values (
    actor, profile_row.display_name, planting_day,
    (coalesce(p_started_at, now()) at time zone 'Asia/Manila')::time,
    db_status, case when p_failure_code is null then 'Synchronized from SeedRover.' else 'SeedRover: ' || p_failure_code end,
    p_client_session_id, coalesce(nullif(btrim(p_rover_id), ''), 'seedrover-01'),
    nullif(btrim(p_field_label), ''), p_crop_profile_key, p_target_drop_cycles,
    p_completed_drop_cycles, p_measured_distance_cm, nullif(area_m2, 0),
    coalesce(p_row_spacing_cm, profile_row.row_spacing_cm), p_soil_raw,
    p_soil_moisture_percent, p_environmental_temperature, p_seed_load_raw,
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
    seed_load_raw = excluded.seed_load_raw,
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
    where not exists (
      select 1 from public.activity_logs
      where user_id = actor and activity = 'Rover planting failed'
        and description like '%' || p_client_session_id::text || '%'
    );
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
    where not exists (
      select 1 from public.notifications n
      where n.recipient_id = recipients.recipient_id and n.action_route = '/planting-logs/' || planting_id::text
        and n.title = 'Rover planting failed'
    );
    return null;
  end if;

  select id into crop_id from public.crops where planting_log_id = planting_id;
  if crop_id is null then
    insert into public.crops (
      planting_log_id, crop_name, assigned_manager, planting_date, estimated_harvest,
      growth_stage, maintenance_notes, crop_status, crop_profile_key, profile_version,
      planting_source, propagation_method, field_label, field_area_m2,
      completed_drop_cycles, estimated_seed_count_min, estimated_seed_count_max,
      harvest_window_start, harvest_window_end, forecast_confidence, expected_stage,
      current_care_status
    ) values (
      planting_id, profile_row.display_name, actor, planting_day,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
      'Seeded', profile_row.advisory, 'Active', profile_row.profile_key, profile_row.version,
      'Rover', profile_row.propagation_method, nullif(btrim(p_field_label), ''), nullif(area_m2, 0),
      p_completed_drop_cycles,
      p_completed_drop_cycles * seeds_per_drop_min,
      p_completed_drop_cycles * seeds_per_drop_max,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_start_days end,
      case when p_crop_profile_key = 'calamansi' then null else planting_day + profile_row.harvest_end_days end,
      case when p_status = 'Partial' or p_crop_profile_key = 'calamansi' then 'Low' else 'Medium' end,
      case when p_crop_profile_key = 'calamansi' then 'Germination and nursery review' else 'Germination' end,
      case when p_status = 'Partial' then 'Partial planting - inspect row' else 'Monitor establishment' end
    ) returning id into crop_id;
  else
    update public.crops set
      completed_drop_cycles = greatest(coalesce(completed_drop_cycles, 0), p_completed_drop_cycles),
      estimated_seed_count_min = p_completed_drop_cycles * seeds_per_drop_min,
      estimated_seed_count_max = p_completed_drop_cycles * seeds_per_drop_max,
      field_area_m2 = nullif(area_m2, 0),
      current_care_status = case when p_status = 'Partial' then 'Partial planting - inspect row' else current_care_status end
    where id = crop_id;
  end if;

  insert into public.crop_activities (
    crop_id, activity_type, performed_at, performed_by, quantity, unit, notes,
    observed_stage, source, idempotency_key, metadata
  ) values (
    crop_id, 'Planted', coalesce(p_completed_at, p_started_at, now()), actor,
    p_completed_drop_cycles, 'drop cycles',
    format('%s of %s planned gate pulses completed. Seed count is estimated.', p_completed_drop_cycles, p_target_drop_cycles),
    'Seeded', 'Rover', 'planting:' || p_client_session_id::text,
    jsonb_build_object('planting_log_id', planting_id, 'estimated_seed_count_min', p_completed_drop_cycles * seeds_per_drop_min, 'estimated_seed_count_max', p_completed_drop_cycles * seeds_per_drop_max)
  ) on conflict (idempotency_key) where idempotency_key is not null do nothing;

  insert into public.activity_logs(user_id, activity, description, module)
  select actor, 'Rover crop batch created',
    format('%s planted in %s: %s completed drop cycles (%s). Session %s.', profile_row.display_name, coalesce(nullif(btrim(p_field_label), ''), 'unlabeled field'), p_completed_drop_cycles, p_status, p_client_session_id),
    'Planting'
  where not exists (
    select 1 from public.activity_logs
    where user_id = actor and activity = 'Rover crop batch created'
      and description like '%' || p_client_session_id::text || '%'
  );

  return crop_id;
end;
$$;

create or replace function public.record_crop_activity(
  p_crop_id uuid,
  p_activity_type text,
  p_performed_at timestamptz,
  p_quantity numeric default null,
  p_unit text default null,
  p_material text default null,
  p_notes text default null,
  p_observed_stage text default null,
  p_task_id uuid default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  result_id uuid;
  crop_row public.crops;
  profile_row public.crop_profiles;
begin
  if actor is null or not public.has_permission('crops.manage') then
    raise exception 'crops.manage permission required';
  end if;
  select * into crop_row from public.crops where id = p_crop_id;
  if crop_row.id is null then raise exception 'Crop not found'; end if;
  select * into profile_row from public.crop_profiles where profile_key = crop_row.crop_profile_key;
  if p_activity_type not in ('Watered','Fertilized','Inspected','Stage Observed','Transplanted','Harvested','Not Harvested') then
    raise exception 'Unsupported crop activity';
  end if;

  insert into public.crop_activities(
    crop_id, activity_type, performed_at, performed_by, quantity, unit, material,
    notes, observed_stage, task_id, source, idempotency_key
  ) values (
    p_crop_id, p_activity_type, coalesce(p_performed_at, now()), actor,
    p_quantity, nullif(btrim(p_unit), ''), nullif(btrim(p_material), ''),
    nullif(btrim(p_notes), ''), nullif(btrim(p_observed_stage), ''), p_task_id,
    'User', p_idempotency_key
  ) on conflict (idempotency_key) where idempotency_key is not null do update set
    notes = excluded.notes
  returning id into result_id;

  update public.crop_tasks set status = 'Completed', completed_at = now(), completed_by = actor, updated_at = now()
  where id = p_task_id and crop_id = p_crop_id;

  update public.crops set
    last_watered_at = case when p_activity_type = 'Watered' then coalesce(p_performed_at, now()) else last_watered_at end,
    last_fertilized_at = case when p_activity_type = 'Fertilized' then coalesce(p_performed_at, now()) else last_fertilized_at end,
    transplanted_at = case when p_activity_type = 'Transplanted' then coalesce(p_performed_at, now()) else transplanted_at end,
    growth_stage = case
      when p_activity_type = 'Harvested' and crop_profile_key = 'sitaw' then 'Repeated Harvest'
      when p_activity_type = 'Harvested' then 'Completed'
      when p_observed_stage in (
        'Seeded','Seedbed','Germinating','Nursery Seedling','Transplant Review','Establishing','Juvenile',
        'Vegetative','Trellising','Flowering','Pod Formation','Pegging','Pod Development','Maturity Check',
        'First Bearing','Fruiting','Harvest Ready','Repeated Harvest','Completed'
      ) then p_observed_stage
      else growth_stage
    end,
    crop_status = case
      when p_activity_type = 'Harvested' and crop_profile_key = 'sitaw' then 'Active'
      when p_activity_type = 'Harvested' then 'Completed'
      when p_activity_type = 'Not Harvested' then 'Cancelled'
      else crop_status
    end,
    current_care_status = case
      when p_activity_type = 'Watered' then 'Watering recorded'
      when p_activity_type = 'Fertilized' then 'Fertilizer recorded'
      when p_activity_type = 'Inspected' then 'Inspection recorded'
      when p_activity_type = 'Transplanted' then 'Establishing after transplant'
      when p_activity_type = 'Harvested' and crop_profile_key = 'sitaw' then 'Next pod harvest check due in 3-4 days'
      when p_activity_type = 'Harvested' then 'Crop cycle completed'
      when p_activity_type = 'Not Harvested' then 'Not harvested'
      else current_care_status
    end,
    harvest_window_start = case
      when p_activity_type = 'Transplanted' and crop_profile_key = 'calamansi' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 1095
      when p_activity_type = 'Stage Observed' and lower(coalesce(p_observed_stage, '')) like '%germinat%' and profile_row.harvest_start_days is not null then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + profile_row.harvest_start_days
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'sitaw' and lower(coalesce(p_observed_stage, '')) like '%flower%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 25
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'sitaw' and lower(coalesce(p_observed_stage, '')) like '%pod%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 15
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'peanut' and lower(coalesce(p_observed_stage, '')) like '%pegg%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 60
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'peanut' and lower(coalesce(p_observed_stage, '')) like '%pod%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 45
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'calamansi' and lower(coalesce(p_observed_stage, '')) like '%fruit%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date
      else harvest_window_start
    end,
    harvest_window_end = case
      when p_activity_type = 'Transplanted' and crop_profile_key = 'calamansi' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 1460
      when p_activity_type = 'Stage Observed' and lower(coalesce(p_observed_stage, '')) like '%germinat%' and profile_row.harvest_end_days is not null then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + profile_row.harvest_end_days
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'sitaw' and lower(coalesce(p_observed_stage, '')) like '%flower%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 35
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'sitaw' and lower(coalesce(p_observed_stage, '')) like '%pod%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 25
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'peanut' and lower(coalesce(p_observed_stage, '')) like '%pegg%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 65
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'peanut' and lower(coalesce(p_observed_stage, '')) like '%pod%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 50
      when p_activity_type = 'Stage Observed' and crop_profile_key = 'calamansi' and lower(coalesce(p_observed_stage, '')) like '%fruit%' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 120
      else harvest_window_end
    end,
    estimated_harvest = case
      when p_activity_type = 'Transplanted' and crop_profile_key = 'calamansi' then (coalesce(p_performed_at, now()) at time zone 'Asia/Manila')::date + 1095
      else estimated_harvest
    end,
    forecast_confidence = case
      when p_activity_type = 'Stage Observed' and lower(coalesce(p_observed_stage, '')) like '%fruit%' then 'High'
      when p_activity_type in ('Stage Observed','Transplanted') then 'Medium'
      else forecast_confidence
    end,
    updated_at = now()
  where id = p_crop_id;

  if p_activity_type = 'Harvested' and crop_row.crop_profile_key = 'sitaw' then
    insert into public.crop_tasks(crop_id, task_type, title, recommendation, due_at, due_window_end, status, priority, deduplication_key)
    values (
      p_crop_id, 'Harvest Check', 'Check sitaw pods for the next harvest',
      'Inspect pod size and tenderness before picking. The 3-4 day interval is guidance, not an automatic harvest decision.',
      coalesce(p_performed_at, now()) + interval '3 days', coalesce(p_performed_at, now()) + interval '4 days',
      'Upcoming', 'Routine', 'crop:' || p_crop_id::text || ':repeat-harvest:' || (coalesce(p_performed_at, now())::date)::text
    ) on conflict (deduplication_key) do nothing;
  end if;

  insert into public.activity_logs(user_id, activity, description, module)
  values (actor, 'Crop activity recorded', crop_row.crop_name || ': ' || p_activity_type || coalesce(' - ' || nullif(btrim(p_notes), ''), ''), 'Crops');
  return result_id;
end;
$$;

revoke all on function public.record_rover_planting_session(uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,integer,numeric,numeric,bigint,text,text,jsonb) from public;
revoke all on function public.record_crop_activity(uuid,text,timestamptz,numeric,text,text,text,text,uuid,text) from public;
grant execute on function public.record_rover_planting_session(uuid,text,text,text,integer,integer,numeric,numeric,text,timestamptz,timestamptz,integer,numeric,numeric,bigint,text,text,jsonb) to authenticated;
grant execute on function public.record_crop_activity(uuid,text,timestamptz,numeric,text,text,text,text,uuid,text) to authenticated;

create or replace function public.audit_manual_crop_creation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.planting_source = 'Manual' then
    insert into public.activity_logs(user_id, activity, description, module)
    values (new.assigned_manager, 'Manual crop created', new.crop_name || ': ' || new.manual_creation_reason, 'Crops');
  end if;
  return new;
end;
$$;
drop trigger if exists crops_audit_manual_creation on public.crops;
create trigger crops_audit_manual_creation after insert on public.crops
  for each row execute function public.audit_manual_crop_creation();

drop trigger if exists crop_profiles_set_updated_at on public.crop_profiles;
create trigger crop_profiles_set_updated_at before update on public.crop_profiles
  for each row execute function public.set_updated_at();
drop trigger if exists crop_tasks_set_updated_at on public.crop_tasks;
create trigger crop_tasks_set_updated_at before update on public.crop_tasks
  for each row execute function public.set_updated_at();

do $$
begin
  begin
    alter publication supabase_realtime add table public.crop_activities;
  exception when duplicate_object then null; when undefined_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.crop_tasks;
  exception when duplicate_object then null; when undefined_object then null;
  end;
end;
$$;
