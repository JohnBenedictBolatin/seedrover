begin;

alter table public.crops
  add column if not exists assigned_planting_name text,
  add column if not exists custom_planting_name text,
  add column if not exists planting_name_version integer not null default 0;

create or replace function public.generate_assigned_planting_name(
  p_profile_key text, p_crop_name text, p_batch_code text
) returns text language plpgsql immutable set search_path=public as $$
declare seed_name text; names text[]; suffix text; number_value bigint; name_index integer;
begin
  seed_name := case lower(coalesce(p_profile_key,''))
    when 'sitaw' then 'Sitaw'
    when 'calamansi' then 'Calamansi'
    when 'peanut' then 'Peanut'
    else initcap(coalesce(nullif(btrim(p_crop_name),''),'Crop'))
  end;
  suffix := nullif(regexp_replace(coalesce(p_batch_code,''),'^.*-',''), '');
  if suffix ~ '^[0-9]+$' then
    number_value := suffix::bigint;
  else
    number_value := 0;
  end if;
  names := case lower(coalesce(p_profile_key,''))
    when 'sitaw' then array['Sunny','Garden','Backyard','Morning','Family']
    when 'calamansi' then array['Garden','Orchard','Backyard','Sunny','Family']
    when 'peanut' then array['Garden','Field','Backyard','Family','Sunny']
    else array['Garden']
  end;
  name_index := mod(number_value,cardinality(names))::integer + 1;
  return names[name_index] || ' ' || seed_name || ' ' || coalesce(nullif(ltrim(suffix,'0'),''),'0');
end $$;

with missing_batch_numbers as (
  select id, row_number() over (partition by coalesce(crop_profile_key,crop_name) order by planting_date,id) as sequence_no
  from public.crops where batch_code is null or btrim(batch_code) = ''
)
update public.crops c
set assigned_planting_name = public.generate_assigned_planting_name(c.crop_profile_key,c.crop_name,
      coalesce(nullif(btrim(c.batch_code),''),'CRP-LEGACY-'||missing_batch_numbers.sequence_no::text)),
    planting_name_version = 0
from missing_batch_numbers
where c.id = missing_batch_numbers.id
  and (c.assigned_planting_name is null or btrim(c.assigned_planting_name) = '');

update public.crops c
set assigned_planting_name = public.generate_assigned_planting_name(c.crop_profile_key,c.crop_name,c.batch_code),
    planting_name_version = 0
where (c.assigned_planting_name is null or btrim(c.assigned_planting_name) = '')
  and c.batch_code is not null and btrim(c.batch_code) <> '';

create or replace function public.set_assigned_planting_name()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.assigned_planting_name := public.generate_assigned_planting_name(
    new.crop_profile_key,new.crop_name,new.batch_code);
  new.custom_planting_name := null;
  new.planting_name_version := 0;
  return new;
end $$;
drop trigger if exists crops_set_assigned_planting_name on public.crops;
create trigger crops_set_assigned_planting_name before insert on public.crops
  for each row execute function public.set_assigned_planting_name();

create table if not exists public.crop_planting_name_changes (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null references public.crops(id) on delete cascade,
  changed_by uuid not null references public.profiles(id),
  submission_id text not null unique,
  payload jsonb not null,
  previous_name text not null,
  new_name text not null,
  result_version integer not null,
  created_at timestamptz not null default now()
);
alter table public.crop_planting_name_changes enable row level security;
drop policy if exists crop_planting_name_changes_read on public.crop_planting_name_changes;
create policy crop_planting_name_changes_read on public.crop_planting_name_changes
  for select to authenticated using (public.has_permission('crops.view') or public.has_permission('crops.manage'));
grant select on public.crop_planting_name_changes to authenticated;
grant all on public.crop_planting_name_changes to service_role;

create or replace function public.guard_crop_planting_name_update()
returns trigger language plpgsql set search_path=public as $$
begin
  if (new.assigned_planting_name is distinct from old.assigned_planting_name
      or new.custom_planting_name is distinct from old.custom_planting_name
      or new.planting_name_version is distinct from old.planting_name_version)
     and coalesce(current_setting('app.crop_planting_name_rpc',true),'') <> 'on' then
    raise exception 'Use the planting name form to rename this crop.';
  end if;
  return new;
end $$;
drop trigger if exists crops_guard_planting_name_update on public.crops;
create trigger crops_guard_planting_name_update before update of assigned_planting_name,custom_planting_name,planting_name_version on public.crops
  for each row execute function public.guard_crop_planting_name_update();

create or replace function public.rename_crop_planting(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare crop_row public.crops; submission text; version_value integer; use_assigned boolean;
  requested text; normalized text; old_name text; next_name text; saved_payload jsonb;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;
  submission := nullif(btrim(p_entry->>'submission_id'),'');
  if submission is null then raise exception 'A name submission ID is required.'; end if;
  use_assigned := coalesce((p_entry->>'use_assigned')::boolean,false);
  requested := p_entry->>'planting_name';
  if use_assigned then
    normalized := null;
  else
    if requested is null or requested ~ '[[:cntrl:]]' then
      raise exception 'Enter a one-line planting name.';
    end if;
    normalized := regexp_replace(btrim(requested),'[[:space:]]+',' ','g');
    if char_length(normalized) < 1 or char_length(normalized) > 60 then
      raise exception 'Planting names must be between 1 and 60 characters.';
    end if;
  end if;
  version_value := coalesce(nullif(p_entry->>'expected_version','')::integer,0);
  saved_payload := jsonb_build_object('crop_id',p_entry->>'crop_id','planting_name',normalized,
    'use_assigned',use_assigned,'expected_version',version_value);

  perform pg_advisory_xact_lock(hashtext('crop-name:'||submission));
  select * into crop_row from public.crops where id=(p_entry->>'crop_id')::uuid for update;
  if not found then raise exception 'Crop not found.'; end if;
  if exists(select 1 from public.crop_planting_name_changes where submission_id=submission) then
    if not exists(select 1 from public.crop_planting_name_changes where submission_id=submission
      and crop_id=crop_row.id and changed_by=auth.uid() and payload=saved_payload) then
      raise exception 'This submission ID belongs to a different name change.';
    end if;
    select new_name,result_version into next_name,version_value
      from public.crop_planting_name_changes where submission_id=submission;
    return jsonb_build_object('crop_id',crop_row.id,'planting_name',next_name,
      'assigned_planting_name',crop_row.assigned_planting_name,'planting_name_version',version_value);
  end if;
  if crop_row.planting_name_version <> version_value then
    raise exception 'This planting name changed on another device. Refresh and review before saving.';
  end if;
  old_name := coalesce(crop_row.custom_planting_name,crop_row.assigned_planting_name);
  next_name := case when normalized is null or normalized= crop_row.assigned_planting_name
    then crop_row.assigned_planting_name else normalized end;
  perform set_config('app.crop_planting_name_rpc','on',true);
  update public.crops set custom_planting_name=case when next_name=assigned_planting_name then null else next_name end,
    planting_name_version=planting_name_version + case when old_name is distinct from next_name then 1 else 0 end,
    updated_at=now() where id=crop_row.id returning * into crop_row;
  insert into public.crop_planting_name_changes(crop_id,changed_by,submission_id,payload,previous_name,new_name,result_version)
    values(crop_row.id,auth.uid(),submission,saved_payload,old_name,next_name,crop_row.planting_name_version);
  return jsonb_build_object('crop_id',crop_row.id,'planting_name',next_name,
    'assigned_planting_name',crop_row.assigned_planting_name,'planting_name_version',crop_row.planting_name_version);
end $$;

revoke all on function public.rename_crop_planting(jsonb) from public;
grant execute on function public.rename_crop_planting(jsonb) to authenticated;

commit;
