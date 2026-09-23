-- Ensure every completed crop is represented in Crop History, regardless of
-- which client performed the harvest.
drop trigger if exists crops_sync_outcome on public.crops;
create trigger crops_sync_outcome
after insert or update of crop_status on public.crops
for each row
when (new.crop_status in ('Completed', 'Cancelled'))
execute function public.sync_crop_outcome_from_status();

insert into public.crop_outcomes (
  crop_id, crop_name, outcome, reason, quantity, recorded_by
)
select
  c.id,
  c.crop_name,
  'Harvested',
  'Harvest recorded from the crop card.',
  nullif(coalesce(h.total_quantity, 0), 0),
  c.assigned_manager
from public.crops c
left join (
  select crop_id, sum(quantity)::numeric(12,2) as total_quantity
  from public.crop_harvests
  group by crop_id
) h on h.crop_id = c.id
where c.crop_status = 'Completed'
  and not exists (
    select 1 from public.crop_outcomes o where o.crop_id = c.id
  );
