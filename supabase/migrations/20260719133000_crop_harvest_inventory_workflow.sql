alter table public.inventory_transactions
  drop constraint if exists inventory_transactions_source_allowed,
  add constraint inventory_transactions_source_allowed check (
    source in ('manual', 'sale', 'void_sale', 'harvest')
  );

create table if not exists public.crop_harvests (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null references public.crops(id) on delete restrict,
  inventory_id uuid not null references public.inventory(id) on delete restrict,
  quantity numeric(12, 2) not null,
  unit text not null,
  harvest_date date not null default current_date,
  harvested_by uuid not null references public.profiles(id) on delete restrict,
  remarks text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crop_harvests_quantity_positive check (quantity > 0)
);

create index if not exists crop_harvests_crop_id_idx
  on public.crop_harvests(crop_id);

create index if not exists crop_harvests_inventory_id_idx
  on public.crop_harvests(inventory_id);

create index if not exists crop_harvests_harvest_date_idx
  on public.crop_harvests(harvest_date);

drop trigger if exists crop_harvests_set_updated_at on public.crop_harvests;

create trigger crop_harvests_set_updated_at
  before update on public.crop_harvests
  for each row execute function public.set_updated_at();

alter table public.crop_harvests enable row level security;

drop policy if exists crop_harvests_select_allowed on public.crop_harvests;
drop policy if exists crop_harvests_insert_allowed on public.crop_harvests;
drop policy if exists crop_harvests_update_admin on public.crop_harvests;
drop policy if exists crop_harvests_delete_admin on public.crop_harvests;

create policy crop_harvests_select_allowed
  on public.crop_harvests
  for select
  to authenticated
  using (
    public.has_permission('crops.view')
    or public.has_permission('stocks.view')
  );

create policy crop_harvests_insert_allowed
  on public.crop_harvests
  for insert
  to authenticated
  with check (
    public.has_permission('crops.manage')
    and harvested_by = auth.uid()
  );

create policy crop_harvests_update_admin
  on public.crop_harvests
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy crop_harvests_delete_admin
  on public.crop_harvests
  for delete
  to authenticated
  using (public.is_admin());

grant select, insert on public.crop_harvests to authenticated;
grant all on public.crop_harvests to service_role;
