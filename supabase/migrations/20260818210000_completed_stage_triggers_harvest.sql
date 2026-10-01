-- Treat an observed stage of Completed as an authoritative harvest event.
-- The existing harvest triggers then add inventory stock/history, finalize the
-- crop, and create its successful Crop History outcome in one transaction.
create or replace function public.completed_stage_becomes_harvest()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(trim(coalesce(new.observed_stage, ''))) = 'completed'
     and new.activity_type <> 'Harvested' then
    new.activity_type := 'Harvested';
    new.notes := coalesce(
      nullif(trim(new.notes), ''),
      'Observed stage Completed; crop marked successfully harvested.'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists aaa_crop_completed_stage_becomes_harvest on public.crop_activities;
create trigger aaa_crop_completed_stage_becomes_harvest
  before insert on public.crop_activities
  for each row execute function public.completed_stage_becomes_harvest();

-- Repair crops whose stage was previously marked Completed without producing
-- a harvest. Only crops with their matching vegetable inventory item can be
-- repaired, preserving the all-or-nothing harvest workflow.
insert into public.crop_activities (
  crop_id, activity_type, performed_at, performed_by, quantity, unit,
  material, notes, observed_stage, source, idempotency_key
)
select
  c.id,
  'Harvested',
  now(),
  c.assigned_manager,
  greatest(coalesce(c.completed_drop_cycles, 1), 1),
  i.unit,
  i.item_name,
  'Previously observed as Completed; synchronized as a successful harvest.',
  'Completed',
  'System',
  'completed-stage:' || c.id::text
from public.crops c
join lateral (
  select inv.*
  from public.inventory inv
  where lower(trim(inv.item_name)) = lower(trim(c.crop_name))
  order by inv.created_at
  limit 1
) i on true
where lower(trim(c.growth_stage)) = 'completed'
  and c.assigned_manager is not null
  and not exists (
    select 1 from public.crop_activities a
    where a.crop_id = c.id and a.activity_type = 'Harvested'
  )
on conflict (idempotency_key) where idempotency_key is not null do nothing;
