-- A batch has one final harvest. Historical multi-picking records remain intact.
begin;

alter table public.crops
  add column if not exists harvest_inventory_id uuid references public.inventory(id),
  add column if not exists harvested_at timestamptz;
alter table public.crop_harvests add column if not exists submission_id text;
create unique index if not exists crop_harvest_submission_idx
  on public.crop_harvests(submission_id) where submission_id is not null;

drop trigger if exists aaa_crop_completed_stage_becomes_harvest on public.crop_activities;
drop trigger if exists crop_activities_keep_harvest_active on public.crop_activities;
drop trigger if exists crops_prevent_implicit_completion_after_harvest on public.crops;
drop trigger if exists crop_activities_finalize_harvest on public.crop_activities;
drop trigger if exists crop_activities_record_harvest_stock on public.crop_activities;
drop trigger if exists crop_activities_require_harvest_inventory on public.crop_activities;
drop trigger if exists crop_activities_sync_successful_outcome on public.crop_activities;

-- Status transitions must not replace an actual harvest total with zero.
create or replace function public.sync_crop_outcome_from_status()
returns trigger language plpgsql security definer set search_path = public as $$
declare total numeric; outcome_id uuid; harvest_time timestamptz;
begin
  if new.crop_status not in ('Completed','Cancelled') then return new; end if;
  select sum(quantity), max(performed_at) into total, harvest_time
    from public.crop_activities where crop_id = new.id and activity_type = 'Harvested';
  if total is null then
    select sum(quantity), max(harvest_date)::timestamptz into total, harvest_time
      from public.crop_harvests where crop_id = new.id;
  end if;
  select id into outcome_id from public.crop_outcomes where crop_id = new.id
    order by recorded_at desc limit 1;
  if outcome_id is null then
    insert into public.crop_outcomes(crop_id,crop_name,outcome,quantity,reason,recorded_by,recorded_at)
    values(new.id,new.crop_name,case when new.crop_status='Completed' then 'Harvested' else 'Failed' end,
      total,new.maintenance_notes,coalesce(auth.uid(),new.assigned_manager),coalesce(harvest_time,now()));
  else
    update public.crop_outcomes set crop_name=new.crop_name,
      outcome=case when new.crop_status='Completed' then 'Harvested' else 'Failed' end,
      quantity=total, recorded_at=coalesce(harvest_time,recorded_at)
    where id=outcome_id;
  end if;
  return new;
end $$;

-- Close old productive batches without inserting any activities or stock entries.
update public.crops c set crop_status='Completed',growth_stage='Completed',
  current_care_status='Batch harvested',
  harvested_at=coalesce(
    (select max(performed_at) from public.crop_activities where crop_id=c.id and activity_type='Harvested'),
    (select max(harvest_date)::timestamptz from public.crop_harvests where crop_id=c.id)),
  harvest_inventory_id=(select inventory_id from public.crop_harvests where crop_id=c.id order by harvest_date desc limit 1)
where exists(select 1 from public.crop_activities where crop_id=c.id and activity_type='Harvested')
   or exists(select 1 from public.crop_harvests where crop_id=c.id);
update public.crop_tasks t set status='Dismissed',updated_at=now()
where status not in ('Completed','Dismissed')
  and exists(select 1 from public.crops c where c.id=t.crop_id and c.crop_status in ('Completed','Cancelled'));

create or replace function public.crop_harvest_destination(p_crop_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.crops; i public.inventory; matches integer;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.'; end if;
  select * into c from public.crops where id=p_crop_id;
  if not found then raise exception 'Crop not found.'; end if;
  select count(*) into matches from public.inventory
    where lower(btrim(item_name))=lower(btrim(c.crop_name));
  if matches=0 then raise exception 'Create the % produce inventory item in kg before harvesting.',c.crop_name; end if;
  if matches>1 then raise exception 'More than one inventory item matches %. Ask the inventory manager to resolve it.',c.crop_name; end if;
  select * into i from public.inventory where lower(btrim(item_name))=lower(btrim(c.crop_name));
  if lower(btrim(i.unit))<>'kg' then raise exception 'The % inventory item must use kg.',i.item_name; end if;
  if c.harvest_inventory_id is not null and c.harvest_inventory_id<>i.id then
    raise exception 'The linked harvest inventory no longer matches this crop.'; end if;
  return jsonb_build_object('id',i.id,'name',i.item_name,'unit','kg');
end $$;

create or replace function public.harvest_crop_batch(
  p_crop_id uuid, p_quantity numeric, p_performed_at timestamptz,
  p_notes text, p_submission_id text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.crops; h public.crop_harvests; destination jsonb; activity_id uuid;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.'; end if;
  if nullif(btrim(p_submission_id),'') is null then raise exception 'Submission ID required.'; end if;
  if p_quantity is null or p_quantity::text in ('NaN','Infinity','-Infinity') or p_quantity<=0
     or p_quantity<>round(p_quantity,2) then raise exception 'Enter a positive weight in kg, with up to two decimal places.'; end if;
  if p_performed_at is null or p_performed_at>now()+interval '1 minute' then raise exception 'Enter a valid harvest time, not in the future.'; end if;
  perform pg_advisory_xact_lock(hashtext('crop-submit:'||p_submission_id));
  select * into h from public.crop_harvests where submission_id=p_submission_id;
  if found then
    if h.crop_id<>p_crop_id or h.harvested_by<>auth.uid() or h.quantity<>p_quantity then
      raise exception 'Submission ID already belongs to another harvest.'; end if;
    return jsonb_build_object('harvest_id',h.id,'crop_id',h.crop_id,'inventory_id',h.inventory_id,'quantity',h.quantity,'unit','kg','status','Completed');
  end if;
  select * into c from public.crops where id=p_crop_id for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.crop_status in ('Completed','Cancelled') or exists(select 1 from public.crop_activities where crop_id=c.id and activity_type='Harvested') then
    raise exception 'This batch is already closed. Its harvest cannot be recorded again.'; end if;
  if (p_performed_at at time zone 'Asia/Manila')::date<c.planting_date then raise exception 'Harvest cannot precede planting.'; end if;
  destination:=public.crop_harvest_destination(c.id);
  -- Keep destination properties stable until the stock movement commits.
  perform 1 from public.inventory where id=(destination->>'id')::uuid for update;
  destination:=public.crop_harvest_destination(c.id);
  insert into public.crop_harvests(crop_id,inventory_id,quantity,unit,harvest_date,harvested_by,remarks,submission_id)
    values(c.id,(destination->>'id')::uuid,p_quantity,'kg',(p_performed_at at time zone 'Asia/Manila')::date,auth.uid(),p_notes,p_submission_id)
    returning * into h;
  insert into public.inventory_transactions(inventory_id,transaction_type,quantity,remarks,performed_by,source,source_id)
    values(h.inventory_id,'IN',p_quantity,'Batch harvest: '||coalesce(c.batch_code,c.id::text),auth.uid(),'harvest',h.id);
  insert into public.crop_activities(crop_id,activity_type,performed_at,performed_by,quantity,unit,notes,source,idempotency_key,metadata)
    values(c.id,'Harvested',p_performed_at,auth.uid(),p_quantity,'kg',p_notes,'User',p_submission_id,
      jsonb_build_object('crop_harvest_id',h.id,'inventory_id',h.inventory_id)) returning id into activity_id;
  update public.crops set crop_status='Completed',growth_stage='Completed',harvested_at=p_performed_at,
    harvest_inventory_id=h.inventory_id,current_care_status='Batch harvested',updated_at=now() where id=c.id;
  update public.crop_tasks set status='Dismissed',updated_at=now() where crop_id=c.id and status not in ('Completed','Dismissed');
  perform public.safe_activity_log(auth.uid(),'Batch harvested',c.crop_name||': '||p_quantity||' kg added to inventory. Batch closed.','Crops');
  return jsonb_build_object('harvest_id',h.id,'activity_id',activity_id,'crop_id',c.id,'inventory_id',h.inventory_id,
    'inventory_name',destination->>'name','quantity',p_quantity,'unit','kg','status','Completed');
end $$;

-- Keep the old API callable, but give every client the same final-harvest rules.
create or replace function public.harvest_crop_to_inventory(p_crop_id uuid,p_inventory_id uuid,p_quantity numeric,p_harvest_date date,p_remarks text default null)
returns public.crops language plpgsql security definer set search_path=public as $$
declare c public.crops; destination jsonb;
begin
  destination:=public.crop_harvest_destination(p_crop_id);
  if (destination->>'id')::uuid is distinct from p_inventory_id then raise exception 'Choose the matching crop inventory item.'; end if;
  perform public.harvest_crop_batch(p_crop_id,p_quantity,p_harvest_date::timestamp at time zone 'Asia/Manila',p_remarks,
    'legacy-harvest:'||p_crop_id::text||':'||p_quantity::text||':'||p_harvest_date::text);
  select * into c from public.crops where id=p_crop_id; return c;
end $$;

create or replace function public.refresh_crop_attention(p_crop_id uuid)
returns void language sql security definer set search_path=public as $$
  update public.crops c set current_care_status=coalesce(
    (select title from public.crop_tasks where crop_id=c.id and status in ('Due','Overdue')
      order by case priority when 'Critical' then 0 when 'Important' then 1 else 2 end,due_at limit 1),
    'No care tasks due'),
    crop_status=case when exists(select 1 from public.crop_tasks where crop_id=c.id and status in ('Due','Overdue')) then 'Needs Attention'
      when c.growth_stage='Harvest Ready' then 'Harvest Ready' else 'Active' end
  where c.id=p_crop_id and c.crop_status not in ('Completed','Cancelled');
$$;

create or replace function public.record_crop_activity(
  p_crop_id uuid,p_activity_type text,p_performed_at timestamptz,p_quantity numeric default null,
  p_unit text default null,p_material text default null,p_notes text default null,
  p_observed_stage text default null,p_task_id uuid default null,p_idempotency_key text default null
) returns uuid language plpgsql security definer set search_path=public as $$
declare c public.crops; existing public.crop_activities; result_id uuid; task public.crop_tasks; matching_type text;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then raise exception 'Crop management permission required.'; end if;
  if nullif(btrim(p_idempotency_key),'') is null then raise exception 'Submission ID required.'; end if;
  perform pg_advisory_xact_lock(hashtext('crop-submit:'||p_idempotency_key));
  select * into existing from public.crop_activities where idempotency_key=p_idempotency_key;
  if found then
    if existing.crop_id<>p_crop_id or existing.performed_by<>auth.uid() or existing.activity_type<>p_activity_type
      or existing.quantity is distinct from p_quantity then raise exception 'Submission ID already used for another activity.'; end if;
    return existing.id;
  end if;
  if p_activity_type='Harvested' then
    if lower(coalesce(p_unit,'kg'))<>'kg' then raise exception 'Harvest weight must be in kg.'; end if;
    perform public.harvest_crop_batch(p_crop_id,p_quantity,p_performed_at,p_notes,p_idempotency_key);
    select id into result_id from public.crop_activities where idempotency_key=p_idempotency_key; return result_id;
  end if;
  select * into c from public.crops where id=p_crop_id for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.crop_status in ('Completed','Cancelled') then raise exception 'This batch is already closed.'; end if;
  if p_performed_at is null or p_performed_at>now()+interval '1 minute'
    or (p_performed_at at time zone 'Asia/Manila')::date<c.planting_date then raise exception 'Activity time must be between planting and now.'; end if;
  if p_activity_type not in ('Watered','Fertilized','Inspected','Stage Observed','Transplanted','Not Harvested') then raise exception 'Choose a supported crop activity.'; end if;
  if p_activity_type in ('Watered','Fertilized') and (p_quantity is null or p_quantity<=0 or p_quantity::text in ('NaN','Infinity','-Infinity') or nullif(btrim(p_unit),'') is null) then
    raise exception 'Enter a positive quantity and its unit.'; end if;
  if p_activity_type='Fertilized' and nullif(btrim(p_material),'') is null then raise exception 'Enter the fertilizer used.'; end if;
  if p_activity_type='Not Harvested' and nullif(btrim(p_notes),'') is null then raise exception 'Explain why this batch is closing without harvest.'; end if;
  if p_activity_type='Stage Observed' and nullif(btrim(p_observed_stage),'') is null then raise exception 'Select the observed stage.'; end if;
  if nullif(btrim(p_observed_stage),'') is not null then
    if p_observed_stage in ('Completed','Repeated Harvest') or not exists(
      select 1 from public.crop_profiles p, jsonb_array_elements(p.stage_plan) s
      where p.profile_key=c.crop_profile_key and s->>'stage'=p_observed_stage
      union all select 1 where p_observed_stage='Harvest Ready') then raise exception 'Choose an observed stage from this crop profile.'; end if;
  end if;
  matching_type:=case p_activity_type when 'Watered' then 'Water' when 'Fertilized' then 'Fertilize'
    when 'Inspected' then 'Inspect' when 'Stage Observed' then 'Harvest Check' when 'Transplanted' then 'Transplant' end;
  if p_task_id is not null then
    select * into task from public.crop_tasks where id=p_task_id and crop_id=c.id for update;
    if not found then raise exception 'This task does not belong to the selected crop.'; end if;
    if task.status in ('Completed','Dismissed') then raise exception 'This task has already been resolved.'; end if;
    if task.task_type<>matching_type and not(p_activity_type='Inspected' and task.task_type in ('Harvest Check','Weather Risk')) then
      raise exception 'Record the activity requested by this task.'; end if;
  end if;
  insert into public.crop_activities(crop_id,activity_type,performed_at,performed_by,quantity,unit,material,notes,observed_stage,task_id,source,idempotency_key)
    values(c.id,p_activity_type,p_performed_at,auth.uid(),p_quantity,nullif(btrim(p_unit),''),nullif(btrim(p_material),''),p_notes,
      nullif(btrim(p_observed_stage),''),p_task_id,'User',p_idempotency_key) returning id into result_id;
  update public.crop_tasks set status='Completed',completed_at=now(),completed_by=auth.uid(),updated_at=now()
    where crop_id=c.id and status not in ('Completed','Dismissed')
      and (id=p_task_id or (p_task_id is null and task_type=matching_type and due_at<=p_performed_at));
  update public.crops set
    last_watered_at=case when p_activity_type='Watered' then greatest(last_watered_at,p_performed_at) else last_watered_at end,
    last_fertilized_at=case when p_activity_type='Fertilized' then greatest(last_fertilized_at,p_performed_at) else last_fertilized_at end,
    transplanted_at=case when p_activity_type='Transplanted' then p_performed_at else transplanted_at end,
    growth_stage=coalesce(nullif(btrim(p_observed_stage),''),growth_stage),
    crop_status=case when p_activity_type='Not Harvested' then 'Cancelled' else crop_status end,
    maintenance_notes=case when p_activity_type='Not Harvested' then p_notes else maintenance_notes end,
    updated_at=now() where id=c.id;
  if p_activity_type='Not Harvested' then
    update public.crop_tasks set status='Dismissed',updated_at=now() where crop_id=c.id and status not in ('Completed','Dismissed');
  else perform public.refresh_crop_attention(c.id); end if;
  perform public.safe_activity_log(auth.uid(),'Crop activity recorded',c.crop_name||': '||p_activity_type,'Crops');
  return result_id;
end $$;

create or replace function public.finish_crop_cycle(p_crop_id uuid,p_outcome text default 'Finished',p_notes text default null,p_idempotency_key text default null)
returns uuid language plpgsql security definer set search_path=public as $$
begin
  if p_outcome not in ('Failed','Removed') then raise exception 'Use Harvest batch and enter the actual weight in kg.'; end if;
  return public.record_crop_activity(p_crop_id,'Not Harvested',now(),null,null,null,p_notes,null,null,p_idempotency_key);
end $$;

create table public.crop_activity_photos(
  id uuid primary key default gen_random_uuid(),activity_id uuid not null references public.crop_activities(id) on delete cascade,
  crop_id uuid not null references public.crops(id),path text not null unique,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now()
);
alter table public.crop_activity_photos enable row level security;
create policy crop_photo_read on public.crop_activity_photos for select to authenticated
  using(public.has_permission('crops.view') or public.has_permission('crops.manage'));
grant select on public.crop_activity_photos to authenticated;
grant all on public.crop_activity_photos to service_role;

-- Private journal photos, separate from public crop illustrations.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('crop-journal','crop-journal',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy crop_journal_read on storage.objects for select to authenticated
  using(bucket_id='crop-journal' and (public.has_permission('crops.view') or public.has_permission('crops.manage')));
create policy crop_journal_upload on storage.objects for insert to authenticated
  with check(bucket_id='crop-journal' and public.has_permission('crops.manage') and (storage.foldername(name))[1]=auth.uid()::text);

create or replace function public.record_crop_entry(p_entry jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare activity_id uuid; photo text; c_id uuid:=(p_entry->>'crop_id')::uuid;
begin
  activity_id:=public.record_crop_activity(c_id,p_entry->>'activity_type',(p_entry->>'performed_at')::timestamptz,
    (p_entry->>'quantity')::numeric,p_entry->>'unit',p_entry->>'material',p_entry->>'notes',p_entry->>'observed_stage',
    nullif(p_entry->>'task_id','')::uuid,p_entry->>'submission_id');
  for photo in select jsonb_array_elements_text(coalesce(p_entry->'photos','[]')) loop
    if split_part(photo,'/',1)<>auth.uid()::text or split_part(photo,'/',2)<>c_id::text
      or not exists(select 1 from storage.objects where bucket_id='crop-journal' and name=photo) then
      raise exception 'Photo must be uploaded by you for this crop.'; end if;
    if exists(select 1 from public.crop_activity_photos where path=photo and activity_id<>record_crop_entry.activity_id) then
      raise exception 'Photo is already attached to another observation.'; end if;
    insert into public.crop_activity_photos(activity_id,crop_id,path,created_by) values(activity_id,c_id,photo,auth.uid()) on conflict(path) do nothing;
  end loop;
  return activity_id;
end $$;

-- Direct table writes must not bypass the validated, atomic entry points.
revoke insert,update,delete on public.crop_activities,public.crop_harvests from authenticated;
create or replace function public.guard_crop_closure()
returns trigger language plpgsql set search_path=public as $$
begin
  if old.crop_status in ('Completed','Cancelled') and new.crop_status not in ('Completed','Cancelled') then
    raise exception 'Closed batches cannot be reopened.'; end if;
  if new.crop_status='Completed' and old.crop_status<>'Completed' and not exists(select 1 from public.crop_harvests where crop_id=new.id) then
    raise exception 'Record the actual harvested weight to close this batch.'; end if;
  if new.crop_status='Cancelled' and old.crop_status<>'Cancelled' and not exists(
    select 1 from public.crop_activities where crop_id=new.id and activity_type='Not Harvested'
      and performed_by=auth.uid() and nullif(btrim(notes),'') is not null
  ) then raise exception 'Use Close without harvest and enter a reason.'; end if;
  return new;
end $$;
create trigger crops_guard_closure before update of crop_status on public.crops for each row execute function public.guard_crop_closure();

create table public.crop_notification_preferences(
  user_id uuid primary key references public.profiles(id) on delete cascade,
  digest_enabled boolean not null default true,digest_hour integer not null default 6 check(digest_hour between 0 and 23),
  quiet_start integer not null default 21 check(quiet_start between 0 and 23),quiet_end integer not null default 6 check(quiet_end between 0 and 23)
);
alter table public.crop_notification_preferences enable row level security;
create policy crop_preferences_own on public.crop_notification_preferences for all to authenticated
  using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update on public.crop_notification_preferences to authenticated;
grant all on public.crop_notification_preferences to service_role;

revoke all on function public.refresh_crop_attention(uuid) from public,authenticated;
revoke all on function public.crop_harvest_destination(uuid),public.harvest_crop_batch(uuid,numeric,timestamptz,text,text),public.record_crop_entry(jsonb) from public;
grant execute on function public.crop_harvest_destination(uuid),public.harvest_crop_batch(uuid,numeric,timestamptz,text,text),public.record_crop_entry(jsonb) to authenticated;
commit;
