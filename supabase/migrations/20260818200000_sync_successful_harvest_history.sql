-- Successful Crop History must be derived from the authoritative Harvested
-- activity, not only from a later crop-status update.
create or replace function public.sync_successful_harvest_outcome()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  crop_row public.crops;
  existing_id uuid;
  total_quantity numeric(12,2);
begin
  if new.activity_type <> 'Harvested' then return new; end if;

  select * into crop_row from public.crops where id = new.crop_id;
  select coalesce(sum(quantity), 0)::numeric(12,2)
    into total_quantity
    from public.crop_activities
   where crop_id = new.crop_id and activity_type = 'Harvested';

  select id into existing_id
    from public.crop_outcomes
   where crop_id = new.crop_id
   order by recorded_at desc
   limit 1;

  if existing_id is null then
    insert into public.crop_outcomes (
      crop_id, crop_name, outcome, reason, quantity, recorded_by, recorded_at
    ) values (
      new.crop_id, crop_row.crop_name, 'Harvested',
      coalesce(nullif(trim(new.notes), ''), 'Successful harvest recorded.'),
      nullif(total_quantity, 0),
      coalesce(new.performed_by, crop_row.assigned_manager),
      coalesce(new.performed_at, now())
    );
  else
    update public.crop_outcomes
       set crop_name = crop_row.crop_name,
           outcome = 'Harvested',
           reason = coalesce(nullif(trim(new.notes), ''), 'Successful harvest recorded.'),
           quantity = nullif(total_quantity, 0),
           recorded_by = coalesce(new.performed_by, recorded_by, crop_row.assigned_manager),
           recorded_at = coalesce(new.performed_at, recorded_at)
     where id = existing_id;
  end if;
  return new;
end;
$$;

drop trigger if exists crop_activities_sync_successful_outcome on public.crop_activities;
create trigger crop_activities_sync_successful_outcome
  after insert on public.crop_activities
  for each row execute function public.sync_successful_harvest_outcome();

insert into public.crop_outcomes (
  crop_id, crop_name, outcome, reason, quantity, recorded_by, recorded_at
)
select
  c.id,
  c.crop_name,
  'Harvested',
  coalesce(nullif(trim(latest.notes), ''), 'Successful harvest recorded.'),
  nullif(totals.total_quantity, 0),
  coalesce(latest.performed_by, c.assigned_manager),
  latest.performed_at
from public.crops c
join lateral (
  select a.notes, a.performed_by, a.performed_at
  from public.crop_activities a
  where a.crop_id = c.id and a.activity_type = 'Harvested'
  order by a.performed_at desc
  limit 1
) latest on true
join lateral (
  select coalesce(sum(a.quantity), 0)::numeric(12,2) as total_quantity
  from public.crop_activities a
  where a.crop_id = c.id and a.activity_type = 'Harvested'
) totals on true
where not exists (
  select 1 from public.crop_outcomes o where o.crop_id = c.id
);
