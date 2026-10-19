-- Preserve who created opening stock so the shared web/mobile history can
-- attribute an item's initial quantity to the signed-in user.
alter table public.inventory_stock_batches
  add column if not exists recorded_by uuid references public.profiles(id) on delete set null;

-- Backfill only inventory rows that have never been updated since creation.
-- In that case updated_by is still the original creator. Do not infer actors
-- for older rows whose updated_at changed after creation.
update public.inventory_stock_batches batch
   set recorded_by = inventory.updated_by
  from public.inventory inventory
 where batch.inventory_id = inventory.id
   and batch.origin_type = 'opening'
   and batch.source_transaction_id is null
   and batch.recorded_by is null
   and inventory.updated_by is not null
   and inventory.updated_at = inventory.created_at
   and batch.origin_recorded_at = inventory.created_at;

create or replace function public.initialize_inventory_spoilage_batch()
returns trigger language plpgsql security definer set search_path = public as $$
declare profile_version integer;
begin
  if new.quantity > 0 then
    if new.initial_received_on is not null and new.initial_received_on > (now() at time zone 'Asia/Manila')::date then
      raise exception 'Receipt date cannot be in the future.';
    end if;
    if new.initial_harvest_on is not null and new.initial_harvest_on > coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date) then
      raise exception 'Harvest date cannot be after receipt date.';
    end if;

    select reference_version into profile_version
      from public.inventory_spoilage_profiles
     where id = new.spoilage_profile_id;

    insert into public.inventory_stock_batches(
      inventory_id, initial_quantity, remaining_quantity, received_on,
      harvest_on, age_known, profile_id, reference_version, origin_type,
      origin_recorded_at, recorded_by
    ) values (
      new.id, new.quantity, new.quantity,
      coalesce(new.initial_received_on, (now() at time zone 'Asia/Manila')::date),
      new.initial_harvest_on, true, new.spoilage_profile_id, profile_version,
      'opening', new.created_at, new.updated_by
    );
  end if;
  return new;
end;
$$;

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
       when created_batch.origin_type = 'historical' and created_batch.age_known then 'Stocked today'
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
      when batch.origin_type = 'historical' and batch.age_known then 'Stocked today'
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
  case when batch.origin_type = 'opening' then 'Opening stock' else 'Historical stock' end as remarks,
  'batch'::text as source,
  null::uuid as source_id,
  coalesce(batch.origin_recorded_at,
    case when batch.origin_type = 'opening' then batch.created_at else null end) as created_at,
  batch.recorded_by as performed_by,
  opening_actor.full_name as performed_by_name,
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
       when batch.origin_type = 'historical' and batch.age_known then 'Stocked today'
       when batch.origin_type = 'opening' and batch.age_known then 'Recording date (approximate age)'
       when batch.age_known then 'Receipt date (approximate age)'
       else 'Age unknown' end as batch_date_basis,
  '[]'::jsonb as allocated_batches
from public.inventory_stock_batches batch
left join public.profiles opening_actor on opening_actor.id = batch.recorded_by
where batch.source_transaction_id is null;

grant select on public.inventory_movement_batch_details to authenticated;
notify pgrst, 'reload schema';
