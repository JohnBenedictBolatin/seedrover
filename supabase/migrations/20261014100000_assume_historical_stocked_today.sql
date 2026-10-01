-- Give historical on-hand batches a simple, explicit estimate base without
-- changing inventory balances or creating stock transactions.
with assumptions as (
  select
    batch.id,
    batch.received_on as previous_received_on,
    batch.harvest_on as previous_harvest_on,
    (now() at time zone 'Asia/Manila')::date as assumed_received_on,
    batch.remaining_quantity
  from public.inventory_stock_batches batch
  where batch.origin_type = 'historical'
    and batch.source_transaction_id is null
    and not batch.age_known
)
insert into public.inventory_stock_batch_audit (
  batch_id, previous_received_on, new_received_on, previous_harvest_on,
  new_harvest_on, previous_profile_id, new_profile_id, action, quantity,
  changed_by
)
select
  assumptions.id,
  assumptions.previous_received_on,
  assumptions.assumed_received_on,
  assumptions.previous_harvest_on,
  null,
  batch.profile_id,
  batch.profile_id,
  'historical_assume_stocked_today',
  assumptions.remaining_quantity,
  null
from assumptions
join public.inventory_stock_batches batch on batch.id = assumptions.id;

update public.inventory_stock_batches batch
   set received_on = (now() at time zone 'Asia/Manila')::date,
       harvest_on = null,
       age_known = true,
       origin_recorded_at = now()
 where batch.origin_type = 'historical'
   and batch.source_transaction_id is null
   and not batch.age_known;

-- Keep the shared history read shape; historical entries now use their
-- assumed date in the timeline without pretending a stock transaction exists.
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
       when batch.origin_type = 'historical' and batch.age_known then 'Stocked today'
       when batch.origin_type = 'opening' and batch.age_known then 'Recording date (approximate age)'
       when batch.age_known then 'Receipt date (approximate age)'
       else 'Age unknown' end as batch_date_basis,
  '[]'::jsonb as allocated_batches
from public.inventory_stock_batches batch
where batch.source_transaction_id is null;

grant select on public.inventory_movement_batch_details to authenticated;
notify pgrst, 'reload schema';
