create sequence if not exists public.crop_batch_code_seq;

create or replace function public.next_crop_batch_code()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
begin
  return 'CRP-' || to_char(timezone('Asia/Manila', now()), 'YYYY') || '-' ||
    lpad(nextval('public.crop_batch_code_seq')::text, 6, '0');
end;
$$;

revoke all on function public.next_crop_batch_code() from public;
grant execute on function public.next_crop_batch_code() to authenticated, service_role;

alter table public.crops
  add column if not exists batch_code text;

alter table public.crops
  alter column batch_code set default public.next_crop_batch_code();

update public.crops
set batch_code = 'CRP-' || to_char(planting_date, 'YYYY') || '-' ||
  lpad(nextval('public.crop_batch_code_seq')::text, 6, '0')
where batch_code is null or btrim(batch_code) = '';

alter table public.crops
  alter column batch_code set not null;

create unique index if not exists crops_batch_code_unique
  on public.crops (batch_code);

comment on column public.crops.batch_code is
  'Stable human-readable crop batch tracking ID. The UUID id remains the relational primary key.';

insert into public.crop_activities (
  crop_id, activity_type, performed_at, performed_by, notes, observed_stage,
  source, idempotency_key
)
select
  crop.id,
  'Planted',
  crop.planting_date::timestamp at time zone 'Asia/Manila',
  crop.assigned_manager,
  case crop.planting_source
    when 'Rover' then 'Crop batch created from its rover planting record.'
    when 'Manual' then 'Crop batch was added manually.'
    else 'Planting record preserved from the legacy crop history.'
  end,
  crop.growth_stage,
  case crop.planting_source
    when 'Rover' then 'Rover'
    when 'Manual' then 'User'
    else 'Legacy'
  end,
  'crop-created:' || crop.id::text
from public.crops crop
where not exists (
  select 1 from public.crop_activities activity
  where activity.crop_id = crop.id
);

create or replace function public.record_manual_crop_planting_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.planting_source = 'Manual' then
    insert into public.crop_activities (
      crop_id, activity_type, performed_at, performed_by, notes,
      observed_stage, source, idempotency_key
    ) values (
      new.id, 'Planted', new.planting_date::timestamp at time zone 'Asia/Manila',
      new.assigned_manager, 'Crop batch was added manually.', new.growth_stage,
      'User', 'crop-created:' || new.id::text
    ) on conflict (idempotency_key) where idempotency_key is not null do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.record_manual_crop_planting_activity() from public;

drop trigger if exists crops_record_manual_planting_activity on public.crops;
create trigger crops_record_manual_planting_activity
after insert on public.crops
for each row execute function public.record_manual_crop_planting_activity();
