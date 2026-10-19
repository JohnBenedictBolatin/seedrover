begin;

create or replace function public.get_crop_activity_summaries(
  p_crop_ids uuid[],
  p_week_start timestamptz,
  p_as_of timestamptz
)
returns table(
  crop_id uuid,
  last_observed_at timestamptz,
  weekly_activity_count bigint,
  latest_drop_cycles bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null
    or not (public.has_permission('crops.view') or public.has_permission('crops.manage')) then
    raise exception 'Crop viewing permission required.';
  end if;

  if p_week_start is null or p_as_of is null or p_week_start > p_as_of then
    raise exception 'A valid crop activity reporting period is required.';
  end if;

  return query
  select c.id,
    activity.last_observed_at,
    activity.weekly_activity_count,
    drop_cycles.quantity::bigint
  from public.crops c
  cross join lateral (
    select
      max(a.performed_at) filter (
        where a.activity_type in ('Inspected', 'Stage Observed')
      ) as last_observed_at,
      count(*) filter (
        where a.performed_at >= p_week_start
          and a.performed_at <= p_as_of
      )::bigint as weekly_activity_count
    from public.crop_activities a
    where a.crop_id = c.id
      and a.performed_at <= p_as_of
  ) activity
  left join lateral (
    select a.quantity
    from public.crop_activities a
    where a.crop_id = c.id
      and lower(btrim(a.unit)) = 'drop cycles'
      and a.quantity is not null
      and a.performed_at <= p_as_of
    order by a.performed_at desc, a.id desc
    limit 1
  ) drop_cycles on true
  where c.id = any(coalesce(p_crop_ids, '{}'::uuid[]));
end;
$$;

revoke all on function public.get_crop_activity_summaries(uuid[], timestamptz, timestamptz) from public, anon;
grant execute on function public.get_crop_activity_summaries(uuid[], timestamptz, timestamptz) to authenticated;

create or replace function public.get_crop_monitor_inputs(
  p_crop_ids uuid[],
  p_water_since timestamptz,
  p_as_of timestamptz
)
returns table(
  crop_id uuid,
  recent_water_liters numeric,
  latest_soil_percent numeric,
  latest_sensor_recorded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role'
    or p_water_since is null or p_as_of is null then
    raise exception 'Crop monitoring service access is required.';
  end if;

  return query
  select c.id,
    coalesce(w.recent_water_liters, 0),
    s.soil_percent,
    s.recorded_at
  from public.crops c
  left join lateral (
    select sum(case
      when lower(coalesce(a.unit, '')) = 'ml' then a.quantity / 1000
      when lower(coalesce(a.unit, '')) like 'l%' then a.quantity
      else 0
    end) as recent_water_liters
    from public.crop_activities a
    where a.crop_id = c.id
      and a.activity_type = 'Watered'
      and a.performed_at >= p_water_since
  ) w on true
  left join lateral (
    select coalesce(sr.calibrated_value, sr.soil_moisture) as soil_percent,
      sr.recorded_at
    from public.sensor_readings sr
    where sr.crop_id = c.id
      and sr.provenance_status = 'verified_hardware'
      and sr.soil_moisture_calibrated = true
      and sr.calibration_version is not null
      and sr.recorded_at >= p_as_of - interval '60 seconds'
      and sr.recorded_at <= p_as_of
    order by sr.recorded_at desc, sr.id desc
    limit 1
  ) s on true
  where c.id = any(coalesce(p_crop_ids, '{}'::uuid[]));
end;
$$;

revoke all on function public.get_crop_monitor_inputs(uuid[], timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.get_crop_monitor_inputs(uuid[], timestamptz, timestamptz) to service_role;

commit;
