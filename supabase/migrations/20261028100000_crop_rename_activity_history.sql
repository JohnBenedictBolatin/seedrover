begin;

alter table public.crop_activities
  drop constraint if exists crop_activities_type_allowed;

alter table public.crop_activities
  add constraint crop_activities_type_allowed check (
    activity_type in (
      'Planted', 'Watered', 'Fertilized', 'Inspected', 'Stage Observed',
      'Transplanted', 'Harvested', 'Not Harvested', 'Planting Failed',
      'Crop Cycle Finished', 'Planting Name Changed'
    )
  );

-- Preserve the rename history that was already captured by the dedicated
-- planting-name table, and make it visible in each crop's Activity tab.
insert into public.crop_activities (
  crop_id, activity_type, performed_at, performed_by, notes, source,
  idempotency_key, metadata
)
select
  changes.crop_id,
  'Planting Name Changed',
  changes.created_at,
  changes.changed_by,
  format('Planting name changed from "%s" to "%s".', changes.previous_name, changes.new_name),
  'User',
  'planting-name:' || changes.submission_id,
  jsonb_build_object(
    'previous_name', changes.previous_name,
    'new_name', changes.new_name,
    'submission_id', changes.submission_id
  )
from public.crop_planting_name_changes changes
where changes.previous_name is distinct from changes.new_name
on conflict (idempotency_key) where idempotency_key is not null do nothing;

create or replace function public.rename_crop_planting(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  crop_row public.crops;
  submission text;
  version_value integer;
  use_assigned boolean;
  requested text;
  normalized text;
  old_name text;
  next_name text;
  saved_payload jsonb;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;

  submission := nullif(btrim(p_entry->>'submission_id'), '');
  if submission is null then
    raise exception 'A name submission ID is required.';
  end if;

  use_assigned := coalesce((p_entry->>'use_assigned')::boolean, false);
  requested := p_entry->>'planting_name';
  if use_assigned then
    normalized := null;
  else
    if requested is null or requested ~ '[[:cntrl:]]' then
      raise exception 'Enter a one-line planting name.';
    end if;
    normalized := regexp_replace(btrim(requested), '[[:space:]]+', ' ', 'g');
    if char_length(normalized) < 1 or char_length(normalized) > 60 then
      raise exception 'Planting names must be between 1 and 60 characters.';
    end if;
  end if;

  version_value := coalesce(nullif(p_entry->>'expected_version', '')::integer, 0);
  saved_payload := jsonb_build_object(
    'crop_id', p_entry->>'crop_id',
    'planting_name', normalized,
    'use_assigned', use_assigned,
    'expected_version', version_value
  );

  perform pg_advisory_xact_lock(hashtext('crop-name:' || submission));
  select * into crop_row
  from public.crops
  where id = (p_entry->>'crop_id')::uuid
  for update;
  if not found then
    raise exception 'Crop not found.';
  end if;

  if exists (
    select 1 from public.crop_planting_name_changes
    where submission_id = submission
  ) then
    if not exists (
      select 1 from public.crop_planting_name_changes
      where submission_id = submission
        and crop_id = crop_row.id
        and changed_by = auth.uid()
        and payload = saved_payload
    ) then
      raise exception 'This submission ID belongs to a different name change.';
    end if;

    select new_name, result_version
    into next_name, version_value
    from public.crop_planting_name_changes
    where submission_id = submission;
    return jsonb_build_object(
      'crop_id', crop_row.id,
      'planting_name', next_name,
      'assigned_planting_name', crop_row.assigned_planting_name,
      'planting_name_version', version_value
    );
  end if;

  if crop_row.planting_name_version <> version_value then
    raise exception 'This planting name changed on another device. Refresh and review before saving.';
  end if;

  old_name := coalesce(crop_row.custom_planting_name, crop_row.assigned_planting_name);
  next_name := case
    when normalized is null or normalized = crop_row.assigned_planting_name
      then crop_row.assigned_planting_name
    else normalized
  end;

  perform set_config('app.crop_planting_name_rpc', 'on', true);
  update public.crops
  set custom_planting_name = case
        when next_name = assigned_planting_name then null
        else next_name
      end,
      planting_name_version = planting_name_version
        + case when old_name is distinct from next_name then 1 else 0 end,
      updated_at = now()
  where id = crop_row.id
  returning * into crop_row;

  insert into public.crop_planting_name_changes (
    crop_id, changed_by, submission_id, payload, previous_name, new_name, result_version
  ) values (
    crop_row.id, auth.uid(), submission, saved_payload, old_name, next_name,
    crop_row.planting_name_version
  );

  if old_name is distinct from next_name then
    insert into public.crop_activities (
      crop_id, activity_type, performed_at, performed_by, notes, source,
      idempotency_key, metadata
    ) values (
      crop_row.id,
      'Planting Name Changed',
      now(),
      auth.uid(),
      format('Planting name changed from "%s" to "%s".', old_name, next_name),
      'User',
      'planting-name:' || submission,
      jsonb_build_object(
        'previous_name', old_name,
        'new_name', next_name,
        'submission_id', submission
      )
    ) on conflict (idempotency_key) where idempotency_key is not null do nothing;
  end if;

  return jsonb_build_object(
    'crop_id', crop_row.id,
    'planting_name', next_name,
    'assigned_planting_name', crop_row.assigned_planting_name,
    'planting_name_version', crop_row.planting_name_version
  );
end
$$;

revoke all on function public.rename_crop_planting(jsonb) from public;
grant execute on function public.rename_crop_planting(jsonb) to authenticated;

commit;
