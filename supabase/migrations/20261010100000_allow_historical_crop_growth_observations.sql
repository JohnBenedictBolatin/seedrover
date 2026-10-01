begin;

-- Keep historical observations in the activity log without moving the crop's
-- current growth stage backwards. The trigger still protects current state.
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
  c public.crops;
  existing public.crop_activities;
  result_id uuid;
  task public.crop_tasks;
  matching_type text;
  observed_stage_order integer;
  current_stage_order integer;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;
  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception 'Submission ID required.';
  end if;

  perform pg_advisory_xact_lock(hashtext('crop-submit:' || p_idempotency_key));
  select * into existing
  from public.crop_activities
  where idempotency_key = p_idempotency_key;
  if found then
    if existing.crop_id <> p_crop_id
      or existing.performed_by <> auth.uid()
      or existing.activity_type <> p_activity_type
      or existing.quantity is distinct from p_quantity then
      raise exception 'Submission ID already used for another activity.';
    end if;
    return existing.id;
  end if;

  if p_activity_type = 'Harvested' then
    if lower(coalesce(p_unit, 'kg')) <> 'kg' then
      raise exception 'Harvest weight must be in kg.';
    end if;
    perform public.harvest_crop_batch(
      p_crop_id, p_quantity, p_performed_at, p_notes, p_idempotency_key
    );
    select id into result_id
    from public.crop_activities
    where idempotency_key = p_idempotency_key;
    return result_id;
  end if;

  select * into c from public.crops where id = p_crop_id for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.crop_status in ('Completed', 'Cancelled') then
    raise exception 'This batch is already closed.';
  end if;
  if p_performed_at is null
    or p_performed_at > now() + interval '1 minute'
    or (p_performed_at at time zone 'Asia/Manila')::date < c.planting_date then
    raise exception 'Activity time must be between planting and now.';
  end if;
  if p_activity_type not in (
    'Watered', 'Fertilized', 'Inspected', 'Stage Observed',
    'Transplanted', 'Not Harvested'
  ) then
    raise exception 'Choose a supported crop activity.';
  end if;
  if p_activity_type in ('Watered', 'Fertilized') and (
    p_quantity is null or p_quantity <= 0
    or p_quantity::text in ('NaN', 'Infinity', '-Infinity')
    or nullif(btrim(p_unit), '') is null
  ) then
    raise exception 'Enter a positive quantity and its unit.';
  end if;
  if p_activity_type = 'Fertilized' and nullif(btrim(p_material), '') is null then
    raise exception 'Enter the fertilizer used.';
  end if;
  if p_activity_type = 'Not Harvested' and nullif(btrim(p_notes), '') is null then
    raise exception 'Explain why this batch is closing without harvest.';
  end if;
  if p_activity_type = 'Stage Observed' and nullif(btrim(p_observed_stage), '') is null then
    raise exception 'Select the observed stage.';
  end if;
  if nullif(btrim(p_observed_stage), '') is not null and (
    p_observed_stage in ('Completed', 'Repeated Harvest')
    or not exists (
      select 1
      from public.crop_profiles p, jsonb_array_elements(p.stage_plan) s
      where p.profile_key = c.crop_profile_key
        and s->>'stage' = p_observed_stage
      union all
      select 1 where p_observed_stage = 'Harvest Ready'
    )
  ) then
    raise exception 'Choose an observed stage from this crop profile.';
  end if;

  matching_type := case p_activity_type
    when 'Watered' then 'Water'
    when 'Fertilized' then 'Fertilize'
    when 'Inspected' then 'Inspect'
    when 'Stage Observed' then 'Harvest Check'
    when 'Transplanted' then 'Transplant'
  end;
  if p_task_id is not null then
    select * into task
    from public.crop_tasks
    where id = p_task_id and crop_id = c.id
    for update;
    if not found then raise exception 'This task does not belong to the selected crop.'; end if;
    if task.status in ('Completed', 'Dismissed') then
      raise exception 'This task has already been resolved.';
    end if;
    if task.task_type <> matching_type
      and not (p_activity_type = 'Inspected'
        and task.task_type in ('Harvest Check', 'Weather Risk')) then
      raise exception 'Record the activity requested by this task.';
    end if;
  end if;

  insert into public.crop_activities (
    crop_id, activity_type, performed_at, performed_by, quantity, unit,
    material, notes, observed_stage, task_id, source, idempotency_key
  ) values (
    c.id, p_activity_type, p_performed_at, auth.uid(), p_quantity,
    nullif(btrim(p_unit), ''), nullif(btrim(p_material), ''), p_notes,
    nullif(btrim(p_observed_stage), ''), p_task_id, 'User', p_idempotency_key
  ) returning id into result_id;

  update public.crop_tasks
  set status = 'Completed', completed_at = now(), completed_by = auth.uid(), updated_at = now()
  where crop_id = c.id
    and status not in ('Completed', 'Dismissed')
    and (id = p_task_id or (
      p_task_id is null and task_type = matching_type and due_at <= p_performed_at
    ));

  if p_activity_type = 'Stage Observed' then
    observed_stage_order := public.crop_growth_stage_order(c.id, p_observed_stage);
    current_stage_order := public.crop_growth_stage_order(c.id, c.growth_stage);
  end if;

  update public.crops set
    last_watered_at = case when p_activity_type = 'Watered'
      then greatest(last_watered_at, p_performed_at) else last_watered_at end,
    last_fertilized_at = case when p_activity_type = 'Fertilized'
      then greatest(last_fertilized_at, p_performed_at) else last_fertilized_at end,
    transplanted_at = case when p_activity_type = 'Transplanted'
      then p_performed_at else transplanted_at end,
    growth_stage = case
      when p_activity_type = 'Stage Observed'
        and observed_stage_order is not null
        and current_stage_order is not null
        and observed_stage_order < current_stage_order then c.growth_stage
      else coalesce(nullif(btrim(p_observed_stage), ''), c.growth_stage)
    end,
    crop_status = case when p_activity_type = 'Not Harvested' then 'Cancelled' else c.crop_status end,
    maintenance_notes = case when p_activity_type = 'Not Harvested' then p_notes else c.maintenance_notes end,
    updated_at = now()
  where id = c.id;

  if p_activity_type = 'Not Harvested' then
    update public.crop_tasks
    set status = 'Dismissed', updated_at = now()
    where crop_id = c.id and status not in ('Completed', 'Dismissed');
  else
    perform public.refresh_crop_attention(c.id);
  end if;
  perform public.safe_activity_log(
    auth.uid(), 'Crop activity recorded', c.crop_name || ': ' || p_activity_type, 'Crops'
  );
  return result_id;
end;
$$;

commit;
