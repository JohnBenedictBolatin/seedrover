alter table public.rover_calibrations
  add column if not exists seconds_per_meter numeric(8,3);

alter table public.rover_calibrations
  drop constraint if exists rover_calibrations_seconds_per_meter_valid;

alter table public.rover_calibrations
  add constraint rover_calibrations_seconds_per_meter_valid
  check (seconds_per_meter is null or seconds_per_meter > 0 and seconds_per_meter <= 120);

alter table public.planting_logs
  add column if not exists distance_is_estimated boolean not null default false,
  add column if not exists movement_tracking text not null default 'unknown';

alter table public.planting_logs
  drop constraint if exists planting_logs_movement_tracking_allowed;

alter table public.planting_logs
  add constraint planting_logs_movement_tracking_allowed
  check (movement_tracking in ('unknown', 'encoder', 'timed_estimate'));

alter table public.crops
  add column if not exists field_area_is_estimated boolean not null default false;

create or replace function public.set_rover_distance_metadata()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  estimated_text text;
  tracking_text text;
begin
  estimated_text := new.sync_payload #>> '{status,distance_is_estimated}';
  tracking_text := new.sync_payload #>> '{status,movement_tracking}';

  if estimated_text in ('true', 'false') then
    new.distance_is_estimated := estimated_text::boolean;
  end if;
  if tracking_text in ('unknown', 'encoder', 'timed_estimate') then
    new.movement_tracking := tracking_text;
  end if;
  return new;
end;
$$;

drop trigger if exists planting_logs_set_distance_metadata on public.planting_logs;
create trigger planting_logs_set_distance_metadata
before insert or update of sync_payload on public.planting_logs
for each row execute function public.set_rover_distance_metadata();

create or replace function public.set_crop_area_estimate_metadata()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.planting_log_id is not null then
    select distance_is_estimated
      into new.field_area_is_estimated
    from public.planting_logs
    where id = new.planting_log_id;
  end if;
  return new;
end;
$$;

drop trigger if exists crops_set_area_estimate_metadata on public.crops;
create trigger crops_set_area_estimate_metadata
before insert or update on public.crops
for each row execute function public.set_crop_area_estimate_metadata();

update public.planting_logs
set sync_payload = sync_payload
where sync_payload #>> '{status,movement_tracking}' = 'timed_estimate';

update public.crops
set field_area_m2 = field_area_m2
where planting_log_id is not null;

comment on column public.rover_calibrations.seconds_per_meter is
  'Observed travel time for a supervised one-meter forward calibration run.';
comment on column public.planting_logs.distance_is_estimated is
  'True when distance is inferred from calibrated motor-on time rather than a movement sensor.';
comment on column public.crops.field_area_is_estimated is
  'True when field area uses a time-estimated rover distance.';
