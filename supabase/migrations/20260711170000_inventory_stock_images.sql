alter table public.inventory
  add column if not exists stock_code text;

with numbered_inventory as (
  select
    id,
    'STK-' || lpad(row_number() over (order by created_at, id)::text, 3, '0') as generated_stock_code
  from public.inventory
  where stock_code is null
)
update public.inventory inventory
set stock_code = numbered_inventory.generated_stock_code
from numbered_inventory
where inventory.id = numbered_inventory.id;

create unique index if not exists inventory_stock_code_unique
  on public.inventory(stock_code)
  where stock_code is not null;

alter table public.inventory
  add column if not exists image_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stock-images',
  'stock-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy stock_images_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'stock-images');

create policy stock_images_insert_allowed
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'stock-images'
    and public.has_permission('stocks.manage')
  );

create policy stock_images_update_allowed
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'stock-images'
    and public.has_permission('stocks.manage')
  )
  with check (
    bucket_id = 'stock-images'
    and public.has_permission('stocks.manage')
  );

create policy stock_images_delete_allowed
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'stock-images'
    and (
      public.has_permission('stocks.manage')
      or public.is_admin()
    )
  );
