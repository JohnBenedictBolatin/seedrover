-- Track dated inventory batches and show evidence-backed unrefrigerated
-- marketability estimates without making a food-safety guarantee.
create table public.inventory_spoilage_profiles (
  id text primary key,
  display_name text not null,
  aliases text[] not null default '{}',
  shelf_life_days integer not null check (shelf_life_days > 0),
  conditions text not null,
  cultivar_note text not null,
  reference_version integer not null default 1,
  source_title text not null,
  source_url text not null,
  enabled boolean not null default true
);

insert into public.inventory_spoilage_profiles
  (id, display_name, aliases, shelf_life_days, conditions, cultivar_note, source_title, source_url)
values
  ('pechay', 'Pechay (25-day crowns)', array['pechay','bok choy','pak choi'], 2, 'Ambient, 27–32°C; 64–88% RH', 'Study used 25-day-old pechay crowns; observed ambient marketability was 2.3 days.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('rambutan', 'Rambutan (ripe)', array['rambutan'], 3, 'Ambient, 27–32°C; 64–88% RH', 'Study used red-ripe Maharlika rambutan; observed ambient marketability was 3.2 days.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('tomato_mature_green', 'Tomato (mature-green)', array['tomato','kamatis'], 13, 'Ambient, 27–32°C; 64–88% RH', 'Study used mature-green Improved Pope tomatoes; observed ambient marketability was 13 days.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('sweet_pepper_green', 'Sweet pepper (green)', array['sweet pepper','bell pepper','green pepper'], 8, 'Ambient, 27–32°C; 64–88% RH', 'Study used Grossum peppers; observed ambient marketability was 8.1 days.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('mango_mature_green', 'Mango (mature-green)', array['mango','mangga'], 10, 'Ambient, 27–32°C; 64–88% RH', 'Study maturity was about 114 days from flower induction; observed ambient marketability was 10.3 days.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('saba_banana_mature_green', 'Saba banana (mature-green)', array['saba banana','saba'], 10, 'Ambient, 27–32°C; 64–88% RH', 'Study used full three-quarters bananas; ambient marketability was 10.3 days. Apply only to Saba bananas confirmed mature-green.', 'Improving Quality and Shelf Life of Vegetables and Fruits by Evaporative Cooling Storage', 'https://doi.org/10.57043/transnastphl.1997.5952'),
  ('pako', 'Pako (fiddlehead fern)', array['pako','fiddlehead fern'], 2, 'Philippine smallholder storage study', 'Observed shelf life was 2 days with banana-leaf wrapping and brick-walled evaporative cooling.', 'Shelf-life of four Philippine indigenous leafy vegetables influenced by banana leaf wrapping and evaporative cooling', 'https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db'),
  ('alugbati', 'Alugbati (green)', array['alugbati','malabar spinach'], 2, 'Philippine smallholder storage study', 'Observed shelf life was 2 days with banana-leaf wrapping and brick-walled evaporative cooling.', 'Shelf-life of four Philippine indigenous leafy vegetables influenced by banana leaf wrapping and evaporative cooling', 'https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db'),
  ('malunggay', 'Malunggay leaves', array['malunggay','moringa'], 2, 'Philippine smallholder storage study', 'Observed shelf life was 2 days with banana-leaf wrapping and brick-walled evaporative cooling.', 'Shelf-life of four Philippine indigenous leafy vegetables influenced by banana leaf wrapping and evaporative cooling', 'https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db'),
  ('kamote_tops', 'Kamote tops (green)', array['kamote tops','sweet potato tops','tinangkong'], 3, 'Philippine smallholder storage study', 'Observed shelf life was 3 days with banana-leaf wrapping and brick-walled evaporative cooling.', 'Shelf-life of four Philippine indigenous leafy vegetables influenced by banana leaf wrapping and evaporative cooling', 'https://agris.fao.org/search/en/providers/123818/records/6748c8567625988a3720c1db'),
  ('lemongrass', 'Lemongrass (fresh)', array['lemongrass','tanglad'], 3, 'Open storage at 10–32°C', 'Open-stored herbs reached their saleability limit after 3–4 days; default uses the conservative end.', 'The effect of modified atmosphere on the storage life of fresh culinary herbs', 'https://www.ukdr.uplb.edu.ph/journal-articles/5969/'),
  ('pandan', 'Pandan leaves (fresh)', array['pandan'], 3, 'Open storage at 10–32°C', 'Open-stored herbs reached their saleability limit after 3–4 days; default uses the conservative end.', 'The effect of modified atmosphere on the storage life of fresh culinary herbs', 'https://www.ukdr.uplb.edu.ph/journal-articles/5969/'),
  ('vietnamese_basil', 'Vietnamese basil (fresh)', array['vietnamese basil','rau ram'], 3, 'Open storage at 10–32°C', 'Open-stored herbs reached their saleability limit after 3–4 days; basil evidence is for Vietnamese basil, not other basil types.', 'The effect of modified atmosphere on the storage life of fresh culinary herbs', 'https://www.ukdr.uplb.edu.ph/journal-articles/5969/'),
  ('eggplant_mucho', 'Eggplant (Mucho, whole)', array['eggplant','talong'], 5, 'Ambient, 28.9±1.3°C; 86.0±3.6% RH', 'Recent ambient control for uncoated Mucho eggplant became unmarketable after 5 days.', 'iCEAT 2025 Book of Abstracts, p. 29', 'https://iceat.uplb.edu.ph/wp-content/uploads/2025/06/iCEAT-2025-Book-of-Abstracts.pdf')
on conflict (id) do update set
  display_name = excluded.display_name,
  aliases = excluded.aliases,
  shelf_life_days = excluded.shelf_life_days,
  conditions = excluded.conditions,
  cultivar_note = excluded.cultivar_note,
  source_title = excluded.source_title,
  source_url = excluded.source_url;

alter table public.inventory
  add column spoilage_profile_id text references public.inventory_spoilage_profiles(id) on delete set null,
  add column initial_received_on date,
  add column initial_harvest_on date;

alter table public.inventory_transactions
  add column batch_received_on date,
  add column batch_harvest_on date,
  add column batch_profile_id text references public.inventory_spoilage_profiles(id) on delete set null,
  add column request_id uuid unique;

-- A zero adjustment is meaningful: it sets the item's on-hand balance to zero.
alter table public.inventory_transactions
  drop constraint inventory_transactions_quantity_positive;
alter table public.inventory_transactions
  add constraint inventory_transactions_quantity_valid check (
    (transaction_type = 'ADJUSTMENT' and quantity >= 0) or
    (transaction_type in ('IN', 'OUT') and quantity > 0)
  );

create table public.inventory_stock_batches (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.inventory(id) on delete cascade,
  initial_quantity numeric not null check (initial_quantity > 0),
  remaining_quantity numeric not null check (remaining_quantity >= 0),
  received_on date not null,
  harvest_on date,
  age_known boolean not null default false,
  profile_id text references public.inventory_spoilage_profiles(id) on delete set null,
  reference_version integer,
  reference_days integer,
  reference_source_title text,
  reference_source_url text,
  reference_conditions text,
  reference_note text,
  created_at timestamptz not null default now(),
  check (harvest_on is null or harvest_on <= received_on)
);

-- Snapshot estimate inputs onto each batch so catalogue edits cannot silently
-- revise stock already received under an earlier reference.
create or replace function public.snapshot_inventory_batch_reference()
returns trigger language plpgsql security definer set search_path = public as $$
declare profile public.inventory_spoilage_profiles%rowtype;
begin
  if new.profile_id is not null and (tg_op = 'INSERT' or new.profile_id is distinct from old.profile_id or new.reference_days is null) then
    select * into profile from public.inventory_spoilage_profiles where id = new.profile_id;
    if found then
      new.reference_version := profile.reference_version;
      new.reference_days := profile.shelf_life_days;
      new.reference_source_title := profile.source_title;
      new.reference_source_url := profile.source_url;
      new.reference_conditions := profile.conditions;
      new.reference_note := profile.cultivar_note;
    end if;
  elsif new.profile_id is null then
    new.reference_version := null;
    new.reference_days := null;
    new.reference_source_title := null;
    new.reference_source_url := null;
    new.reference_conditions := null;
    new.reference_note := null;
  end if;
  return new;
end; $$;
create trigger inventory_batch_reference_snapshot
  before insert or update on public.inventory_stock_batches
  for each row execute function public.snapshot_inventory_batch_reference();
alter table public.inventory_transactions
  add column target_batch_id uuid references public.inventory_stock_batches(id) on delete set null;
create index inventory_stock_batches_fifo_idx
  on public.inventory_stock_batches(inventory_id, age_known, harvest_on, received_on, created_at, id)
  where remaining_quantity > 0;

create table public.inventory_transaction_batch_allocations (
  transaction_id uuid not null references public.inventory_transactions(id) on delete cascade,
  batch_id uuid not null references public.inventory_stock_batches(id) on delete restrict,
  quantity numeric not null check (quantity > 0),
  primary key (transaction_id, batch_id)
);

create table public.inventory_stock_batch_audit (
  id bigint generated always as identity primary key,
  batch_id uuid not null references public.inventory_stock_batches(id) on delete cascade,
  previous_received_on date,
  new_received_on date,
  previous_harvest_on date,
  new_harvest_on date,
  previous_profile_id text,
  new_profile_id text,
  action text not null default 'corrected',
  quantity numeric,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);

alter table public.inventory_spoilage_profiles enable row level security;
alter table public.inventory_stock_batches enable row level security;
alter table public.inventory_transaction_batch_allocations enable row level security;
alter table public.inventory_stock_batch_audit enable row level security;

create policy inventory_spoilage_profiles_read on public.inventory_spoilage_profiles
  for select to authenticated using (true);
create policy inventory_stock_batches_read on public.inventory_stock_batches
  for select to authenticated using (public.has_permission('stocks.view'));
create policy inventory_transaction_batch_allocations_read on public.inventory_transaction_batch_allocations
  for select to authenticated using (public.has_permission('stocks.view'));
create policy inventory_stock_batch_audit_read on public.inventory_stock_batch_audit
  for select to authenticated using (public.has_permission('stocks.manage'));
grant select on public.inventory_spoilage_profiles, public.inventory_stock_batches,
  public.inventory_transaction_batch_allocations, public.inventory_stock_batch_audit to authenticated;
grant all on public.inventory_spoilage_profiles, public.inventory_stock_batches,
  public.inventory_transaction_batch_allocations, public.inventory_stock_batch_audit to service_role;

-- Existing on-hand quantities have no defensible age. Keep those quantities as
-- unknown-age batches and require staff to date them explicitly.
insert into public.inventory_stock_batches
  (inventory_id, initial_quantity, remaining_quantity, received_on, age_known, profile_id, reference_version)
select i.id, i.quantity, i.quantity, (now() at time zone 'Asia/Manila')::date, false,
       i.spoilage_profile_id, p.reference_version
  from public.inventory i
  left join public.inventory_spoilage_profiles p on p.id = i.spoilage_profile_id
 where i.quantity > 0;

create or replace function public.initialize_inventory_spoilage_batch()
returns trigger language plpgsql security definer set search_path = public as $$
declare profile_version integer;
begin
  if new.quantity > 0 then
    if new.initial_received_on is not null and new.initial_received_on > (now() at time zone 'Asia/Manila')::date then raise exception 'Receipt date cannot be in the future.'; end if;
    if new.initial_harvest_on is not null and new.initial_harvest_on > coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date) then raise exception 'Harvest date cannot be after receipt date.'; end if;
    select reference_version into profile_version from public.inventory_spoilage_profiles where id = new.spoilage_profile_id;
    insert into public.inventory_stock_batches(inventory_id, initial_quantity, remaining_quantity, received_on, harvest_on, age_known, profile_id, reference_version)
    values(new.id, new.quantity, new.quantity, coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date), new.initial_harvest_on, new.initial_received_on is not null or new.initial_harvest_on is not null, new.spoilage_profile_id, profile_version);
  end if;
  return new;
end; $$;
create trigger inventory_initialize_spoilage_batch after insert on public.inventory
  for each row execute function public.initialize_inventory_spoilage_batch();

create or replace function public.sync_inventory_transaction_batches()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  item_profile text;
  profile_version integer;
  harvest_date date;
  batch record;
  remaining numeric := new.quantity;
  take_quantity numeric;
  sale_transaction uuid;
  allocation record;
  batch_total numeric;
  stock_total numeric;
begin
  select spoilage_profile_id into item_profile from public.inventory where id = new.inventory_id;
  select reference_version into profile_version from public.inventory_spoilage_profiles where id = item_profile;

  if new.source = 'void_sale' then
    select t.id into sale_transaction from public.inventory_transactions t
    where t.inventory_id = new.inventory_id and t.source = 'sale' and t.source_id = new.source_id limit 1;
    if sale_transaction is not null and exists(select 1 from public.inventory_transaction_batch_allocations where transaction_id = sale_transaction) then
      for allocation in
        select a.batch_id, sum(a.quantity) as quantity
          from public.inventory_transaction_batch_allocations a
          join public.inventory_transactions t on t.id = a.transaction_id
         where t.inventory_id = new.inventory_id and t.source = 'sale' and t.source_id = new.source_id
         group by a.batch_id
      loop
        update public.inventory_stock_batches set remaining_quantity = remaining_quantity + allocation.quantity where id = allocation.batch_id;
        insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity)
        values(new.id, allocation.batch_id, allocation.quantity)
        on conflict (transaction_id, batch_id) do update set quantity = excluded.quantity;
      end loop;
      return new;
    end if;
    insert into public.inventory_stock_batches(inventory_id, initial_quantity, remaining_quantity, received_on, age_known, profile_id, reference_version)
    values(new.inventory_id, new.quantity, new.quantity, (new.created_at at time zone 'Asia/Manila')::date, false, item_profile, profile_version);
    return new;
  end if;

  if new.transaction_type = 'IN' then
    if new.source = 'harvest' then
      select harvest_date into harvest_date from public.crop_activities where id = new.source_id and activity_type = 'Harvested';
    end if;
    harvest_date := coalesce(new.batch_harvest_on, harvest_date);
    item_profile := coalesce(new.batch_profile_id, item_profile);
    select reference_version into profile_version from public.inventory_spoilage_profiles where id = item_profile;
    if coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date) > (now() at time zone 'Asia/Manila')::date then raise exception 'Receipt date cannot be in the future.'; end if;
    if harvest_date is not null and harvest_date > coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date) then raise exception 'Harvest date cannot be after receipt date.'; end if;
    insert into public.inventory_stock_batches(inventory_id, initial_quantity, remaining_quantity, received_on, harvest_on, age_known, profile_id, reference_version)
    values(new.inventory_id, new.quantity, new.quantity, coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date), harvest_date,
      (new.source = 'harvest' and harvest_date is not null) or new.source <> 'harvest', item_profile, profile_version);
    return new;
  end if;

  if new.transaction_type = 'ADJUSTMENT' then
    select coalesce(sum(remaining_quantity),0) into batch_total from public.inventory_stock_batches where inventory_id = new.inventory_id;
    select quantity into stock_total from public.inventory where id = new.inventory_id;
    if stock_total > batch_total then
      insert into public.inventory_stock_batches(inventory_id, initial_quantity, remaining_quantity, received_on, age_known, profile_id, reference_version)
      values(new.inventory_id, stock_total - batch_total, stock_total - batch_total, (new.created_at at time zone 'Asia/Manila')::date, false, item_profile, profile_version);
    elsif stock_total < batch_total then
      remaining := batch_total - stock_total;
      for batch in select * from public.inventory_stock_batches where inventory_id = new.inventory_id and remaining_quantity > 0 order by age_known asc, coalesce(harvest_on, received_on), received_on, created_at, id for update loop
        exit when remaining <= 0;
        take_quantity := least(batch.remaining_quantity, remaining);
        update public.inventory_stock_batches set remaining_quantity = remaining_quantity - take_quantity where id = batch.id;
        remaining := remaining - take_quantity;
      end loop;
    end if;
    return new;
  end if;

  if new.transaction_type = 'OUT' then
    if new.target_batch_id is not null then
      select * into batch from public.inventory_stock_batches
       where id = new.target_batch_id and inventory_id = new.inventory_id
       for update;
      if not found or batch.remaining_quantity < remaining then raise exception 'The selected stock batch does not contain enough quantity.'; end if;
      update public.inventory_stock_batches set remaining_quantity = remaining_quantity - remaining where id = batch.id;
      insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity) values(new.id, batch.id, remaining);
      remaining := 0;
    else
      for batch in select * from public.inventory_stock_batches where inventory_id = new.inventory_id and remaining_quantity > 0 order by age_known asc, coalesce(harvest_on, received_on), received_on, created_at, id for update loop
        exit when remaining <= 0;
        take_quantity := least(batch.remaining_quantity, remaining);
        update public.inventory_stock_batches set remaining_quantity = remaining_quantity - take_quantity where id = batch.id;
        insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity) values(new.id, batch.id, take_quantity);
        remaining := remaining - take_quantity;
      end loop;
    end if;
    if remaining > 0 then raise exception 'Inventory batch balance is insufficient for this stock issue.'; end if;
  end if;
  return new;
end; $$;
create trigger inventory_transactions_sync_batches after insert on public.inventory_transactions
  for each row execute function public.sync_inventory_transaction_batches();

-- Keep legacy direct quantity writes in sync with batches. Do not infer the age
-- of a difference from updated_at; any unpaired increase is explicitly unknown.
create or replace function public.sync_inventory_direct_quantity_batch()
returns trigger language plpgsql security definer set search_path = public as $$
declare total_batches numeric;
begin
  if coalesce(current_setting('seedrover.inventory_transaction', true), 'off') = 'on' then return new; end if;
  if new.quantity is not distinct from old.quantity then return new; end if;
  select coalesce(sum(remaining_quantity),0) into total_batches from public.inventory_stock_batches where inventory_id = new.id;
  if new.quantity > total_batches then
    insert into public.inventory_stock_batches(inventory_id, initial_quantity, remaining_quantity, received_on, age_known, profile_id, reference_version)
    select new.id, new.quantity-total_batches, new.quantity-total_batches, (now() at time zone 'Asia/Manila')::date, false, new.spoilage_profile_id, p.reference_version
      from (select reference_version from public.inventory_spoilage_profiles where id = new.spoilage_profile_id) p
    union all
    select new.id, new.quantity-total_batches, new.quantity-total_batches, (now() at time zone 'Asia/Manila')::date, false, new.spoilage_profile_id, null
     where new.spoilage_profile_id is null;
  elsif new.quantity < total_batches then
    -- Rebuild retained quantity in FIFO order while preserving each surviving
    -- batch's dates and profile metadata.
    with ordered as (
      select id, remaining_quantity as old_quantity, sum(remaining_quantity) over(order by age_known asc, coalesce(harvest_on,received_on), received_on, created_at, id) as running
      from public.inventory_stock_batches where inventory_id = new.id
    ), keep as (
      select id, greatest(0, least(old_quantity, new.quantity - (running-old_quantity))) as retained from ordered
    ) update public.inventory_stock_batches b set remaining_quantity = keep.retained from keep where b.id = keep.id;
  end if;
  return new;
end; $$;
create trigger inventory_direct_quantity_batch after update of quantity on public.inventory
  for each row execute function public.sync_inventory_direct_quantity_batch();

-- The existing quantity trigger updates inventory before the transaction row is
-- inserted. Mark that update so the direct-edit bridge does not account for the
-- same movement twice; the transaction's AFTER trigger performs the allocation.
create or replace function public.apply_inventory_transaction()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform set_config('seedrover.inventory_transaction', 'on', true);
  if new.transaction_type = 'IN' then
    update public.inventory set quantity = quantity + new.quantity, updated_by = new.performed_by where id = new.inventory_id;
  elsif new.transaction_type = 'OUT' then
    update public.inventory set quantity = quantity - new.quantity, updated_by = new.performed_by
     where id = new.inventory_id and quantity >= new.quantity;
    if not found then raise exception 'Insufficient stock for inventory transaction.'; end if;
  elsif new.transaction_type = 'ADJUSTMENT' then
    update public.inventory set quantity = new.quantity, updated_by = new.performed_by where id = new.inventory_id;
  end if;
  return new;
end; $$;

create or replace function public.set_inventory_item_spoilage_profile(p_inventory_id uuid, p_profile_id text)
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.has_permission('stocks.manage') then raise exception 'Not allowed to update inventory spoilage guidance.'; end if;
  if p_profile_id is not null and not exists(select 1 from public.inventory_spoilage_profiles where id = p_profile_id and enabled) then raise exception 'Choose a supported produce profile.'; end if;
  update public.inventory set spoilage_profile_id = p_profile_id where id = p_inventory_id;
  if not found then raise exception 'Inventory item was not found.'; end if;
end; $$;
revoke all on function public.set_inventory_item_spoilage_profile(uuid,text) from public;
grant execute on function public.set_inventory_item_spoilage_profile(uuid,text) to authenticated;

create or replace function public.correct_inventory_stock_batch(
  p_batch_id uuid, p_received_on date, p_harvest_on date, p_age_known boolean, p_profile_id text
) returns void language plpgsql security definer set search_path = public, auth as $$
declare batch public.inventory_stock_batches%rowtype;
begin
  if not public.has_permission('stocks.manage') then raise exception 'Not allowed to update stock batch dates.'; end if;
  if p_received_on > (now() at time zone 'Asia/Manila')::date or p_harvest_on > (now() at time zone 'Asia/Manila')::date then raise exception 'Batch dates cannot be in the future.'; end if;
  if p_harvest_on is not null and p_harvest_on > p_received_on then raise exception 'Harvest date cannot be after receipt date.'; end if;
  select * into batch from public.inventory_stock_batches where id = p_batch_id for update;
  if not found then raise exception 'Stock batch was not found.'; end if;
  insert into public.inventory_stock_batch_audit(batch_id, previous_received_on, new_received_on, previous_harvest_on, new_harvest_on, previous_profile_id, new_profile_id, changed_by)
  values(batch.id, batch.received_on, p_received_on, batch.harvest_on, p_harvest_on, batch.profile_id, p_profile_id, auth.uid());
  update public.inventory_stock_batches set received_on=p_received_on, harvest_on=p_harvest_on, age_known=p_age_known,
    profile_id=p_profile_id where id=p_batch_id;
end; $$;
revoke all on function public.correct_inventory_stock_batch(uuid,date,date,boolean,text) from public;
grant execute on function public.correct_inventory_stock_batch(uuid,date,date,boolean,text) to authenticated;

create or replace function public.split_inventory_stock_batch(
  p_batch_id uuid, p_split_quantity numeric, p_received_on date,
  p_harvest_on date, p_profile_id text
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare batch public.inventory_stock_batches%rowtype; new_batch_id uuid;
begin
  if auth.uid() is null or not public.has_permission('stocks.manage') then raise exception 'Not allowed to split stock batches.'; end if;
  if p_split_quantity is null or p_split_quantity <= 0 then raise exception 'Split quantity must be greater than zero.'; end if;
  if p_received_on is null or p_received_on > (now() at time zone 'Asia/Manila')::date then raise exception 'Enter a valid receipt date that is not in the future.'; end if;
  if p_harvest_on is not null and p_harvest_on > p_received_on then raise exception 'Harvest date cannot be after receipt date.'; end if;
  if p_profile_id is not null and not exists(select 1 from public.inventory_spoilage_profiles where id=p_profile_id and enabled) then raise exception 'Choose a supported produce profile.'; end if;
  select * into batch from public.inventory_stock_batches where id=p_batch_id for update;
  if not found then raise exception 'Stock batch was not found.'; end if;
  if p_split_quantity >= batch.remaining_quantity then raise exception 'Split quantity must be less than this batch’s remaining quantity.'; end if;
  update public.inventory_stock_batches
     set initial_quantity=initial_quantity-p_split_quantity,
         remaining_quantity=remaining_quantity-p_split_quantity
   where id=batch.id;
  insert into public.inventory_stock_batches(
    inventory_id, initial_quantity, remaining_quantity, received_on, harvest_on,
    age_known, profile_id
  ) values (
    batch.inventory_id, p_split_quantity, p_split_quantity, p_received_on,
    p_harvest_on, true, p_profile_id
  ) returning id into new_batch_id;
  insert into public.inventory_stock_batch_audit(
    batch_id, previous_received_on, new_received_on, previous_harvest_on,
    new_harvest_on, previous_profile_id, new_profile_id, action, quantity, changed_by
  ) values
    (batch.id, batch.received_on, batch.received_on, batch.harvest_on, batch.harvest_on, batch.profile_id, batch.profile_id, 'split_source', p_split_quantity, auth.uid()),
    (new_batch_id, null, p_received_on, null, p_harvest_on, null, p_profile_id, 'split_created', p_split_quantity, auth.uid());
  return new_batch_id;
end; $$;
revoke all on function public.split_inventory_stock_batch(uuid,numeric,date,date,text) from public;
grant execute on function public.split_inventory_stock_batch(uuid,numeric,date,date,text) to authenticated;

create or replace function public.record_inventory_movement_with_batch(
  p_inventory_id uuid, p_transaction_type text, p_quantity numeric,
  p_reason text default null, p_remarks text default null,
  p_received_on date default null, p_harvest_on date default null,
  p_profile_id text default null, p_request_id uuid default null,
  p_target_batch_id uuid default null
) returns public.inventory_transactions
language plpgsql security definer set search_path = public, auth as $$
declare movement public.inventory_transactions%rowtype; item public.inventory%rowtype; batch_date date;
begin
  if auth.uid() is null or not public.has_permission('stocks.manage') then raise exception 'Not allowed to change inventory stock.'; end if;
  if p_transaction_type not in ('IN','OUT','ADJUSTMENT') then raise exception 'Choose a valid inventory movement type.'; end if;
  if p_quantity is null or p_quantity < 0 or (p_transaction_type <> 'ADJUSTMENT' and p_quantity = 0) then raise exception 'Quantity must be greater than zero except when adjusting stock to zero.'; end if;
  if p_target_batch_id is not null and p_transaction_type <> 'OUT' then raise exception 'A target batch can only be selected for a stock issue.'; end if;
  if p_request_id is not null then
    select * into movement from public.inventory_transactions where request_id=p_request_id;
    if found then return movement; end if;
  end if;
  select * into item from public.inventory where id=p_inventory_id for update;
  if not found then raise exception 'Inventory item was not found.'; end if;
  if item.unit <> 'kg' then raise exception 'Inventory quantities must use kg as the unit.'; end if;
  if p_profile_id is not null and not exists(select 1 from public.inventory_spoilage_profiles where id=p_profile_id and enabled) then raise exception 'Choose a supported produce profile.'; end if;
  batch_date := coalesce(p_received_on, (now() at time zone 'Asia/Manila')::date);
  if batch_date > (now() at time zone 'Asia/Manila')::date then raise exception 'Receipt date cannot be in the future.'; end if;
  if p_harvest_on is not null and p_harvest_on > batch_date then raise exception 'Harvest date cannot be after receipt date.'; end if;
  insert into public.inventory_transactions(inventory_id, transaction_type, quantity, remarks, source, source_id, performed_by,
      batch_received_on, batch_harvest_on, batch_profile_id, request_id, target_batch_id)
  values(p_inventory_id, p_transaction_type, p_quantity,
      concat_ws(E'\n', nullif(trim(p_reason), ''), coalesce(nullif(trim(p_remarks), ''), 'Inventory updated.')),
      'manual', null, auth.uid(), case when p_transaction_type='IN' then batch_date end,
      case when p_transaction_type='IN' then p_harvest_on end,
      case when p_transaction_type='IN' then p_profile_id end, p_request_id,
      case when p_transaction_type='OUT' then p_target_batch_id end)
  on conflict (request_id) do nothing
  returning * into movement;
  if not found and p_request_id is not null then
    select * into movement from public.inventory_transactions where request_id = p_request_id;
  end if;
  return movement;
end; $$;
revoke all on function public.record_inventory_movement_with_batch(uuid,text,numeric,text,text,date,date,text,uuid,uuid) from public;
grant execute on function public.record_inventory_movement_with_batch(uuid,text,numeric,text,text,date,date,text,uuid,uuid) to authenticated;

notify pgrst, 'reload schema';
