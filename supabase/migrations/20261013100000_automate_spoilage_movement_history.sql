-- Generate produce profiles from item names and expose each batch beside the
-- inventory movement that created it. Existing stock keeps its recorded dates.

alter table public.inventory_stock_batches
  add column source_transaction_id uuid references public.inventory_transactions(id) on delete set null
    deferrable initially deferred,
  add column origin_type text not null default 'historical'
    check (origin_type in ('opening', 'receipt', 'harvest', 'adjustment', 'reversal', 'historical')),
  add column origin_recorded_at timestamptz,
  add column reference_profile_name text;

create unique index inventory_stock_batches_source_transaction_uidx
  on public.inventory_stock_batches(source_transaction_id)
  where source_transaction_id is not null;

create or replace function public.normalize_spoilage_product_name(p_name text)
returns text
language sql immutable parallel safe
as $$
  select regexp_replace(lower(coalesce(p_name, '')), '[^[:alnum:]]+', '', 'g');
$$;

create or replace function public.resolve_spoilage_profile(p_name text)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare normalized_name text := public.normalize_spoilage_product_name(p_name);
begin
  -- Do not apply the mature-green tomato reference to explicitly ripe stock.
  if normalized_name ~ '(ripe|red|cherry).*tomato|tomato.*(ripe|red|cherry)' then
    return null;
  end if;

  return (
    select profile.id
      from public.inventory_spoilage_profiles profile
      cross join lateral unnest(array_prepend(profile.display_name, profile.aliases)) alias_name
     where public.normalize_spoilage_product_name(alias_name) = normalized_name
       and profile.enabled
     order by profile.id
     limit 1
  );
end;
$$;

-- The bare tomato alias uses the catalogue's mature-green default. Its full
-- profile name and limitation remain visible with every generated estimate.
update public.inventory_spoilage_profiles
   set aliases = array['tomato', 'tomatoes', 'kamatis', 'mature green tomato', 'mature green tomatoes', 'green tomato', 'green tomatoes']
 where id = 'tomato_mature_green';
update public.inventory_spoilage_profiles
   set aliases = array['rambutan', 'ripe rambutan', 'red ripe rambutan']
 where id = 'rambutan';
update public.inventory_spoilage_profiles
   set aliases = array['green sweet pepper', 'green sweet peppers', 'green bell pepper', 'green bell peppers', 'green pepper']
 where id = 'sweet_pepper_green';
update public.inventory_spoilage_profiles
   set aliases = array['mature green mango', 'mature green mangos', 'green mango', 'green mangos']
 where id = 'mango_mature_green';
update public.inventory_spoilage_profiles
   set aliases = array['mature green saba banana', 'green saba banana', 'green saba bananas', 'saging saba na luntian']
 where id = 'saba_banana_mature_green';

create or replace function public.assign_inventory_spoilage_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.item_name is distinct from old.item_name then
    new.spoilage_profile_id := public.resolve_spoilage_profile(new.item_name);
  end if;
  return new;
end;
$$;
create trigger inventory_assign_spoilage_profile
  before insert or update on public.inventory
  for each row execute function public.assign_inventory_spoilage_profile();

-- Keep the profile label alongside the other immutable reference details.
create or replace function public.snapshot_inventory_batch_reference()
returns trigger language plpgsql security definer set search_path = public as $$
declare profile public.inventory_spoilage_profiles%rowtype;
begin
  if new.profile_id is not null and (tg_op = 'INSERT' or new.profile_id is distinct from old.profile_id or new.reference_days is null) then
    select * into profile from public.inventory_spoilage_profiles where id = new.profile_id;
    if found then
      new.reference_version := profile.reference_version;
      new.reference_days := profile.shelf_life_days;
      new.reference_profile_name := profile.display_name;
      new.reference_source_title := profile.source_title;
      new.reference_source_url := profile.source_url;
      new.reference_conditions := profile.conditions;
      new.reference_note := profile.cultivar_note;
    end if;
  elsif new.profile_id is null then
    new.reference_version := null;
    new.reference_days := null;
    new.reference_profile_name := null;
    new.reference_source_title := null;
    new.reference_source_url := null;
    new.reference_conditions := null;
    new.reference_note := null;
  end if;
  return new;
end;
$$;

-- Record audited automatic profile assignment for existing stock without
-- changing batch quantity or guessing its age.
update public.inventory item
   set spoilage_profile_id = public.resolve_spoilage_profile(item.item_name)
 where item.spoilage_profile_id is distinct from public.resolve_spoilage_profile(item.item_name);

insert into public.inventory_stock_batch_audit(
  batch_id, previous_received_on, new_received_on, previous_harvest_on,
  new_harvest_on, previous_profile_id, new_profile_id, action, changed_by
)
select batch.id, batch.received_on, batch.received_on, batch.harvest_on,
       batch.harvest_on, batch.profile_id, item.spoilage_profile_id,
       'automatic_profile', null
  from public.inventory_stock_batches batch
  join public.inventory item on item.id = batch.inventory_id
 where batch.profile_id is null
   and item.spoilage_profile_id is not null;

update public.inventory_stock_batches batch
   set profile_id = item.spoilage_profile_id
  from public.inventory item
 where item.id = batch.inventory_id
   and batch.profile_id is null
   and item.spoilage_profile_id is not null;

-- Older batches may already have a frozen duration and source but no display
-- label because that column was introduced later. Fill only the label so the
-- existing estimate snapshot remains unchanged.
update public.inventory_stock_batches batch
   set reference_profile_name = profile.display_name
  from public.inventory_spoilage_profiles profile
 where profile.id = batch.profile_id
   and batch.reference_profile_name is null;

-- New batches inherit the transaction id while the existing transaction
-- trigger creates them. Opening balances have no transaction and are marked
-- separately. Harvest records can come from crop_harvests or legacy activities.
create or replace function public.prepare_inventory_spoilage_batch()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  transaction_id uuid;
  movement public.inventory_transactions%rowtype;
  item_profile text;
  recorded_harvest_date date;
begin
  transaction_id := nullif(current_setting('seedrover.inventory_transaction_id', true), '')::uuid;
  if transaction_id is null then
    return new;
  end if;

  -- Quantity adjustments create their unknown-age batch in the inventory
  -- quantity trigger, which runs before the transaction row itself is inserted.
  new.source_transaction_id := transaction_id;
  new.origin_recorded_at := coalesce(new.origin_recorded_at, now());
  if current_setting('seedrover.inventory_transaction_type', true) = 'ADJUSTMENT' then
    new.origin_type := 'adjustment';
    new.age_known := false;
    select spoilage_profile_id into item_profile
      from public.inventory where id = new.inventory_id;
    new.profile_id := coalesce(new.profile_id, item_profile);
    return new;
  end if;

  select * into movement
    from public.inventory_transactions
   where id = transaction_id and inventory_id = new.inventory_id;
  if not found then return new; end if;

  new.source_transaction_id := movement.id;
  new.origin_recorded_at := movement.created_at;
  select spoilage_profile_id into item_profile
    from public.inventory where id = movement.inventory_id;
  new.profile_id := coalesce(movement.batch_profile_id, new.profile_id, item_profile);

  if movement.source = 'harvest' then
    new.origin_type := 'harvest';
    select harvest_date into recorded_harvest_date
      from public.crop_harvests where id = movement.source_id;
    if recorded_harvest_date is null then
      select (activity.performed_at at time zone 'Asia/Manila')::date
        into recorded_harvest_date
        from public.crop_activities activity
       where activity.activity_type = 'Harvested'
         and (activity.id = movement.source_id
           or activity.metadata ->> 'crop_harvest_id' = movement.source_id::text)
       order by activity.performed_at desc
       limit 1;
    end if;
    new.harvest_on := coalesce(new.harvest_on, recorded_harvest_date);
    new.received_on := coalesce(new.received_on,
      movement.batch_received_on,
      (movement.created_at at time zone 'Asia/Manila')::date);
    new.age_known := new.harvest_on is not null;
  elsif movement.source = 'void_sale' then
    new.origin_type := 'reversal';
    new.age_known := false;
  elsif movement.transaction_type = 'IN' then
    new.origin_type := 'receipt';
    new.received_on := coalesce(movement.batch_received_on, new.received_on,
      (movement.created_at at time zone 'Asia/Manila')::date);
    new.harvest_on := coalesce(movement.batch_harvest_on, new.harvest_on);
    new.age_known := true;
  elsif movement.transaction_type = 'ADJUSTMENT' then
    new.origin_type := 'adjustment';
    new.age_known := false;
  end if;
  return new;
end;
$$;
create trigger inventory_batch_prepare_automatic_metadata
  before insert on public.inventory_stock_batches
  for each row execute function public.prepare_inventory_spoilage_batch();

-- Harvest dates are attached by prepare_inventory_spoilage_batch(), which
-- resolves both crop_harvests and legacy crop_activities records. The older
-- implementation selected a nonexistent crop_activities.harvest_date column.
create or replace function public.sync_inventory_transaction_batches()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  item_profile text;
  profile_version integer;
  batch record;
  remaining numeric := new.quantity;
  take_quantity numeric;
  sale_transaction uuid;
  allocation record;
  batch_total numeric;
  stock_total numeric;
begin
  select spoilage_profile_id into item_profile
    from public.inventory where id = new.inventory_id;
  select reference_version into profile_version
    from public.inventory_spoilage_profiles where id = item_profile;

  if new.source = 'void_sale' then
    select t.id into sale_transaction from public.inventory_transactions t
     where t.inventory_id = new.inventory_id and t.source = 'sale'
       and t.source_id = new.source_id limit 1;
    if sale_transaction is not null and exists (
      select 1 from public.inventory_transaction_batch_allocations
       where transaction_id = sale_transaction
    ) then
      for allocation in
        select a.batch_id, sum(a.quantity) as quantity
          from public.inventory_transaction_batch_allocations a
          join public.inventory_transactions t on t.id = a.transaction_id
         where t.inventory_id = new.inventory_id and t.source = 'sale'
           and t.source_id = new.source_id
         group by a.batch_id
      loop
        update public.inventory_stock_batches
           set remaining_quantity = remaining_quantity + allocation.quantity
         where id = allocation.batch_id;
        insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity)
        values(new.id, allocation.batch_id, allocation.quantity)
        on conflict (transaction_id, batch_id) do update set quantity = excluded.quantity;
      end loop;
      return new;
    end if;
    insert into public.inventory_stock_batches(
      inventory_id, initial_quantity, remaining_quantity, received_on,
      age_known, profile_id, reference_version
    ) values (
      new.inventory_id, new.quantity, new.quantity,
      (new.created_at at time zone 'Asia/Manila')::date,
      false, item_profile, profile_version
    );
    return new;
  end if;

  if new.transaction_type = 'IN' then
    if coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date)
       > (now() at time zone 'Asia/Manila')::date then
      raise exception 'Receipt date cannot be in the future.';
    end if;
    if new.batch_harvest_on is not null and new.batch_harvest_on >
       coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date) then
      raise exception 'Harvest date cannot be after receipt date.';
    end if;
    insert into public.inventory_stock_batches(
      inventory_id, initial_quantity, remaining_quantity, received_on,
      harvest_on, age_known, profile_id, reference_version
    ) values (
      new.inventory_id, new.quantity, new.quantity,
      coalesce(new.batch_received_on, (new.created_at at time zone 'Asia/Manila')::date),
      new.batch_harvest_on,
      new.source <> 'harvest' or new.batch_harvest_on is not null,
      coalesce(new.batch_profile_id, item_profile), profile_version
    );
    return new;
  end if;

  if new.transaction_type = 'ADJUSTMENT' then
    select coalesce(sum(remaining_quantity), 0) into batch_total
      from public.inventory_stock_batches where inventory_id = new.inventory_id;
    select quantity into stock_total from public.inventory where id = new.inventory_id;
    if stock_total > batch_total then
      insert into public.inventory_stock_batches(
        inventory_id, initial_quantity, remaining_quantity, received_on,
        age_known, profile_id, reference_version
      ) values (
        new.inventory_id, stock_total - batch_total, stock_total - batch_total,
        (new.created_at at time zone 'Asia/Manila')::date,
        false, item_profile, profile_version
      );
    elsif stock_total < batch_total then
      remaining := batch_total - stock_total;
      for batch in
        select * from public.inventory_stock_batches
         where inventory_id = new.inventory_id and remaining_quantity > 0
         order by age_known asc, coalesce(harvest_on, received_on), received_on, created_at, id
         for update
      loop
        exit when remaining <= 0;
        take_quantity := least(batch.remaining_quantity, remaining);
        update public.inventory_stock_batches
           set remaining_quantity = remaining_quantity - take_quantity where id = batch.id;
        remaining := remaining - take_quantity;
      end loop;
    end if;
    return new;
  end if;

  if new.transaction_type = 'OUT' then
    if new.target_batch_id is not null then
      select * into batch from public.inventory_stock_batches
       where id = new.target_batch_id and inventory_id = new.inventory_id for update;
      if not found or batch.remaining_quantity < remaining then
        raise exception 'The selected stock batch does not contain enough quantity.';
      end if;
      update public.inventory_stock_batches
         set remaining_quantity = remaining_quantity - remaining where id = batch.id;
      insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity)
      values(new.id, batch.id, remaining);
      remaining := 0;
    else
      for batch in
        select * from public.inventory_stock_batches
         where inventory_id = new.inventory_id and remaining_quantity > 0
         order by age_known asc, coalesce(harvest_on, received_on), received_on, created_at, id
         for update
      loop
        exit when remaining <= 0;
        take_quantity := least(batch.remaining_quantity, remaining);
        update public.inventory_stock_batches
           set remaining_quantity = remaining_quantity - take_quantity where id = batch.id;
        insert into public.inventory_transaction_batch_allocations(transaction_id, batch_id, quantity)
        values(new.id, batch.id, take_quantity);
        remaining := remaining - take_quantity;
      end loop;
    end if;
    if remaining > 0 then
      raise exception 'Inventory batch balance is insufficient for this stock issue.';
    end if;
  end if;
  return new;
end;
$$;

-- The inventory quantity trigger fires before the movement row is inserted;
-- carry that row id through to the later batch-allocation trigger.
create or replace function public.apply_inventory_transaction()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform set_config('seedrover.inventory_transaction_id', new.id::text, true);
  perform set_config('seedrover.inventory_transaction_type', new.transaction_type, true);
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
end;
$$;

create or replace function public.clear_inventory_transaction_batch_context()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform set_config('seedrover.inventory_transaction_id', '', true);
  perform set_config('seedrover.inventory_transaction_type', '', true);
  perform set_config('seedrover.inventory_transaction', 'off', true);
  return null;
end;
$$;
create trigger zz_inventory_transactions_clear_batch_context
  after insert on public.inventory_transactions
  for each row execute function public.clear_inventory_transaction_batch_context();

create or replace function public.initialize_inventory_spoilage_batch()
returns trigger language plpgsql security definer set search_path = public as $$
declare profile_version integer;
begin
  if new.quantity > 0 then
    if new.initial_received_on is not null and new.initial_received_on > (now() at time zone 'Asia/Manila')::date then raise exception 'Receipt date cannot be in the future.'; end if;
    if new.initial_harvest_on is not null and new.initial_harvest_on > coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date) then raise exception 'Harvest date cannot be after receipt date.'; end if;
    select reference_version into profile_version from public.inventory_spoilage_profiles where id = new.spoilage_profile_id;
    insert into public.inventory_stock_batches(
      inventory_id, initial_quantity, remaining_quantity, received_on, harvest_on,
      age_known, profile_id, reference_version, origin_type, origin_recorded_at
    ) values (
      new.id, new.quantity, new.quantity,
      coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date),
      new.initial_harvest_on, true, new.spoilage_profile_id, profile_version,
      'opening', new.created_at
    );
  end if;
  return new;
end;
$$;

-- One read interface supplies movement history and all associated batch
-- summaries to both web and mobile clients. Historical stock remains distinct.
create or replace view public.inventory_movement_batch_details
with (security_invoker = true)
as
select
  transaction_row.id as event_id,
  transaction_row.id as movement_id,
  transaction_row.inventory_id,
  'movement'::text as event_kind,
  transaction_row.transaction_type,
  transaction_row.quantity,
  transaction_row.remarks,
  transaction_row.source,
  transaction_row.source_id,
  transaction_row.created_at,
  transaction_row.performed_by,
  actor.full_name as performed_by_name,
  created_batch.id as batch_id,
  created_batch.origin_type as batch_origin,
  created_batch.initial_quantity as batch_initial_quantity,
  created_batch.remaining_quantity as batch_remaining_quantity,
  created_batch.received_on as batch_received_on,
  created_batch.harvest_on as batch_harvest_on,
  created_batch.age_known as batch_age_known,
  created_batch.profile_id as batch_profile_id,
  created_batch.reference_profile_name as batch_profile_name,
  created_batch.reference_version as batch_reference_version,
  created_batch.reference_days as batch_reference_days,
  created_batch.reference_source_title as batch_reference_source_title,
  created_batch.reference_source_url as batch_reference_source_url,
  created_batch.reference_conditions as batch_reference_conditions,
  created_batch.reference_note as batch_reference_note,
  case when created_batch.age_known and created_batch.reference_days is not null
    then coalesce(created_batch.harvest_on, created_batch.received_on) + created_batch.reference_days
    else null end as batch_estimated_spoilage_on,
  case when created_batch.harvest_on is not null then 'Harvest date'
       when created_batch.origin_type = 'opening' and created_batch.age_known then 'Recording date (approximate age)'
       when created_batch.age_known then 'Receipt date (approximate age)'
       else 'Age unknown' end as batch_date_basis,
  coalesce(allocations.batches, '[]'::jsonb) as allocated_batches
from public.inventory_transactions transaction_row
left join public.profiles actor on actor.id = transaction_row.performed_by
left join public.inventory_stock_batches created_batch
  on created_batch.source_transaction_id = transaction_row.id
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'batch_id', batch.id,
    'quantity', allocation.quantity,
    'origin_type', batch.origin_type,
    'initial_quantity', batch.initial_quantity,
    'remaining_quantity', batch.remaining_quantity,
    'profile_id', batch.profile_id,
    'profile_name', batch.reference_profile_name,
    'reference_version', batch.reference_version,
    'reference_days', batch.reference_days,
    'reference_source_title', batch.reference_source_title,
    'reference_source_url', batch.reference_source_url,
    'reference_conditions', batch.reference_conditions,
    'reference_note', batch.reference_note,
    'age_known', batch.age_known,
    'received_on', batch.received_on,
    'harvest_on', batch.harvest_on,
    'date_basis', case
      when batch.harvest_on is not null then 'Harvest date'
      when batch.origin_type = 'opening' and batch.age_known then 'Recording date (approximate age)'
      when batch.age_known then 'Receipt date (approximate age)'
      else 'Age unknown' end,
    'estimated_spoilage_on', case when batch.age_known and batch.reference_days is not null
      then coalesce(batch.harvest_on, batch.received_on) + batch.reference_days else null end
  ) order by batch.age_known, coalesce(batch.harvest_on, batch.received_on), batch.received_on, batch.id) as batches
    from public.inventory_transaction_batch_allocations allocation
    join public.inventory_stock_batches batch on batch.id = allocation.batch_id
   where allocation.transaction_id = transaction_row.id
) allocations on true
union all
select
  batch.id as event_id,
  null::uuid as movement_id,
  batch.inventory_id,
  case when batch.origin_type = 'opening' then 'opening' else 'historical' end as event_kind,
  null::text as transaction_type,
  batch.initial_quantity as quantity,
  case when batch.origin_type = 'opening' then 'Opening stock' else 'Existing stock; receipt history unavailable' end as remarks,
  'batch'::text as source,
  null::uuid as source_id,
  case when batch.origin_type = 'opening' then batch.origin_recorded_at else null end as created_at,
  null::uuid as performed_by,
  null::text as performed_by_name,
  batch.id as batch_id,
  batch.origin_type as batch_origin,
  batch.initial_quantity as batch_initial_quantity,
  batch.remaining_quantity as batch_remaining_quantity,
  batch.received_on as batch_received_on,
  batch.harvest_on as batch_harvest_on,
  batch.age_known as batch_age_known,
  batch.profile_id as batch_profile_id,
  batch.reference_profile_name as batch_profile_name,
  batch.reference_version as batch_reference_version,
  batch.reference_days as batch_reference_days,
  batch.reference_source_title as batch_reference_source_title,
  batch.reference_source_url as batch_reference_source_url,
  batch.reference_conditions as batch_reference_conditions,
  batch.reference_note as batch_reference_note,
  case when batch.age_known and batch.reference_days is not null
    then coalesce(batch.harvest_on, batch.received_on) + batch.reference_days
    else null end as batch_estimated_spoilage_on,
  case when batch.harvest_on is not null then 'Harvest date'
       when batch.origin_type = 'opening' and batch.age_known then 'Recording date (approximate age)'
       when batch.age_known then 'Receipt date (approximate age)'
       else 'Age unknown' end as batch_date_basis,
  '[]'::jsonb as allocated_batches
from public.inventory_stock_batches batch
where batch.source_transaction_id is null;

grant select on public.inventory_movement_batch_details to authenticated;

notify pgrst, 'reload schema';
