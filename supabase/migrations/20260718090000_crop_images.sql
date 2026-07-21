alter table public.crops
  add column if not exists image_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'crop-images',
  'crop-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy crop_images_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'crop-images');

create policy crop_images_insert_allowed
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'crop-images'
    and (
      public.has_permission('crops.manage')
      or public.is_admin()
    )
  );

create policy crop_images_update_allowed
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'crop-images'
    and (
      public.has_permission('crops.manage')
      or public.is_admin()
    )
  )
  with check (
    bucket_id = 'crop-images'
    and (
      public.has_permission('crops.manage')
      or public.is_admin()
    )
  );

create policy crop_images_delete_allowed
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'crop-images'
    and (
      public.has_permission('crops.manage')
      or public.is_admin()
    )
  );
