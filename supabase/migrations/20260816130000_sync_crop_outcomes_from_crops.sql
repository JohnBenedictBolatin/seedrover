-- Keep Past Crops derived from crop-card status changes instead of manual entries.

create or replace function public.sync_crop_outcome_from_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  next_outcome text;
  next_reason text;
  harvested_quantity numeric(12,2);
  existing_outcome_id uuid;
begin
  if new.crop_status not in ('Completed', 'Cancelled') then
    return new;
  end if;

  next_outcome := case when new.crop_status = 'Completed' then 'Harvested' else 'Failed' end;
  next_reason := case
    when new.crop_status = 'Completed' then 'Harvest recorded from the crop card.'
    else coalesce(nullif(trim(new.maintenance_notes), ''), 'Marked as not harvested from the crop card.')
  end;

  if new.crop_status = 'Completed' then
    select coalesce(sum(quantity), 0)
      into harvested_quantity
      from public.crop_harvests
     where crop_id = new.id;
  else
    harvested_quantity := null;
  end if;

  select id
    into existing_outcome_id
    from public.crop_outcomes
   where crop_id = new.id
   order by recorded_at desc
   limit 1;

  if existing_outcome_id is null then
    insert into public.crop_outcomes (
      crop_id,
      crop_name,
      outcome,
      reason,
      quantity,
      recorded_by
    ) values (
      new.id,
      new.crop_name,
      next_outcome,
      next_reason,
      nullif(harvested_quantity, 0),
      coalesce(auth.uid(), new.assigned_manager)
    );
  else
    update public.crop_outcomes
       set crop_name = new.crop_name,
           outcome = next_outcome,
           reason = next_reason,
           quantity = nullif(harvested_quantity, 0),
           recorded_by = coalesce(recorded_by, auth.uid(), new.assigned_manager)
     where id = existing_outcome_id;
  end if;

  return new;
end;
$$;

drop trigger if exists crops_sync_outcome on public.crops;
create trigger crops_sync_outcome
after insert or update of crop_status on public.crops
for each row
when (new.crop_status in ('Completed', 'Cancelled'))
execute function public.sync_crop_outcome_from_status();

insert into public.crop_outcomes (
  crop_id,
  crop_name,
  outcome,
  reason,
  quantity,
  recorded_by
)
select
  crop.id,
  crop.crop_name,
  case when crop.crop_status = 'Completed' then 'Harvested' else 'Failed' end,
  case
    when crop.crop_status = 'Completed' then 'Harvest recorded from the crop card.'
    else coalesce(nullif(trim(crop.maintenance_notes), ''), 'Marked as not harvested from the crop card.')
  end,
  case when crop.crop_status = 'Completed' then nullif(coalesce(harvest.total_quantity, 0), 0) else null end,
  crop.assigned_manager
from public.crops as crop
left join (
  select crop_id, sum(quantity)::numeric(12,2) as total_quantity
  from public.crop_harvests
  group by crop_id
) as harvest on harvest.crop_id = crop.id
where crop.crop_status in ('Completed', 'Cancelled')
  and not exists (
    select 1 from public.crop_outcomes as outcome where outcome.crop_id = crop.id
  );
