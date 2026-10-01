create or replace function public.record_crop_entry(p_entry jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_activity_id uuid;
  photo text;
  c_id uuid := (p_entry->>'crop_id')::uuid;
begin
  v_activity_id := public.record_crop_activity(
    c_id,
    p_entry->>'activity_type',
    (p_entry->>'performed_at')::timestamptz,
    (p_entry->>'quantity')::numeric,
    p_entry->>'unit',
    p_entry->>'material',
    p_entry->>'notes',
    p_entry->>'observed_stage',
    nullif(p_entry->>'task_id', '')::uuid,
    p_entry->>'submission_id'
  );

  for photo in
    select jsonb_array_elements_text(coalesce(p_entry->'photos', '[]'))
  loop
    if split_part(photo, '/', 1) <> auth.uid()::text
      or split_part(photo, '/', 2) <> c_id::text
      or not exists (
        select 1
        from storage.objects as stored_photo
        where stored_photo.bucket_id = 'crop-journal'
          and stored_photo.name = photo
      ) then
      raise exception 'Photo must be uploaded by you for this crop.';
    end if;

    if exists (
      select 1
      from public.crop_activity_photos as attached_photo
      where attached_photo.path = photo
        and attached_photo.activity_id <> v_activity_id
    ) then
      raise exception 'Photo is already attached to another observation.';
    end if;

    insert into public.crop_activity_photos(activity_id, crop_id, path, created_by)
    values (v_activity_id, c_id, photo, auth.uid())
    on conflict (path) do nothing;
  end loop;

  return v_activity_id;
end;
$$;
