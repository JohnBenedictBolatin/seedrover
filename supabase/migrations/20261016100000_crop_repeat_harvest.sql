begin;

-- Harvest behavior is snapshotted when a crop is planted so profile edits do
-- not silently change the lifecycle of existing crops.
alter table public.crop_profiles
  add column if not exists harvest_mode text not null default 'single';
alter table public.crop_profiles drop constraint if exists crop_profiles_harvest_mode_allowed;
alter table public.crop_profiles add constraint crop_profiles_harvest_mode_allowed
  check (harvest_mode in ('single', 'repeat'));
update public.crop_profiles set harvest_mode = 'repeat'
 where lower(profile_key) in ('sitaw', 'calamansi');

alter table public.crops
  add column if not exists harvest_mode text not null default 'single';
alter table public.crops drop constraint if exists crops_harvest_mode_allowed;
alter table public.crops add constraint crops_harvest_mode_allowed
  check (harvest_mode in ('single', 'repeat'));
update public.crops c set harvest_mode = p.harvest_mode
  from public.crop_profiles p where p.profile_key = c.crop_profile_key
    and c.crop_status not in ('Completed', 'Cancelled');

create or replace function public.snapshot_crop_harvest_mode()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  select harvest_mode into new.harvest_mode from public.crop_profiles where profile_key=new.crop_profile_key;
  new.harvest_mode:=coalesce(new.harvest_mode,'single');
  return new;
end $$;
drop trigger if exists crops_snapshot_harvest_mode on public.crops;
create trigger crops_snapshot_harvest_mode before insert on public.crops
  for each row execute function public.snapshot_crop_harvest_mode();
create or replace function public.prevent_crop_harvest_mode_change()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.harvest_mode is distinct from old.harvest_mode then
    raise exception 'A crop harvest plan cannot be changed after planting.';
  end if;
  return new;
end $$;
drop trigger if exists crops_harvest_mode_immutable on public.crops;
create trigger crops_harvest_mode_immutable before update of harvest_mode on public.crops
  for each row execute function public.prevent_crop_harvest_mode_change();
alter table public.crop_harvests
  add column if not exists submission_payload jsonb;

create table if not exists public.crop_closures (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid not null unique references public.crops(id) on delete restrict,
  reason text not null check (length(btrim(reason)) > 0),
  explanation text,
  closed_by uuid references public.profiles(id) on delete set null,
  closed_at timestamptz not null default now(),
  closure_source text not null check (closure_source in ('farmer', 'single_harvest', 'legacy')),
  submission_id text not null unique,
  submission_payload jsonb not null
);
alter table public.crop_closures enable row level security;
drop policy if exists crop_closures_read on public.crop_closures;
create policy crop_closures_read on public.crop_closures for select to authenticated
  using (public.has_permission('crops.view') or public.has_permission('crops.manage'));
grant select on public.crop_closures to authenticated;
grant all on public.crop_closures to service_role;

create index if not exists crop_harvests_crop_date_idx
  on public.crop_harvests(crop_id, harvest_date desc, id desc);
create index if not exists crop_harvests_performed_by_idx
  on public.crop_harvests(harvested_by);

-- All newly created and explicitly ended crops get one auditable closure row.
create or replace function public.guard_crop_closure()
returns trigger language plpgsql set search_path=public as $$
begin
  if old.crop_status in ('Completed','Cancelled') and new.crop_status is distinct from old.crop_status then
    raise exception 'Closed crops cannot be changed or reopened.';
  end if;
  if new.crop_status in ('Completed','Cancelled') and old.crop_status not in ('Completed','Cancelled') then
    if not exists (select 1 from public.crop_closures where crop_id = new.id) then
      raise exception 'Use the crop ending form to close this crop.';
    end if;
    if new.crop_status = 'Completed' and not exists (
      select 1 from public.crop_harvests where crop_id = new.id
    ) then raise exception 'Record a harvest before closing this crop as harvested.'; end if;
  end if;
  return new;
end $$;

create or replace function public.prevent_tasks_for_ended_crops()
returns trigger language plpgsql security definer set search_path=public as $$
declare current_status text;
begin
  if new.status not in ('Upcoming','Due','Overdue','Postponed') then return new; end if;
  select crop_status into current_status from public.crops where id=new.crop_id for update;
  if current_status in ('Completed','Cancelled') then return null; end if;
  return new;
end $$;
drop trigger if exists crop_tasks_reject_after_closure on public.crop_tasks;
create trigger crop_tasks_reject_after_closure before insert or update on public.crop_tasks
  for each row execute function public.prevent_tasks_for_ended_crops();

create or replace function public.prevent_crop_growth_regression()
returns trigger language plpgsql security definer set search_path=public as $$
declare previous_order integer; next_order integer;
begin
  if new.growth_stage is not distinct from old.growth_stage then return new; end if;
  if new.growth_stage='Completed' and new.crop_status='Completed'
    and exists(select 1 from public.crop_closures where crop_id=new.id) then return new; end if;
  previous_order:=public.crop_growth_stage_order(old.id,old.growth_stage);
  next_order:=public.crop_growth_stage_order(new.id,new.growth_stage);
  if next_order is null then raise exception 'Growth stage must be configured for this crop.'; end if;
  if previous_order is not null and next_order<previous_order then
    raise exception 'Growth stage cannot move backward from % to %.',old.growth_stage,new.growth_stage; end if;
  return new;
end $$;

create or replace function public.sync_crop_outcome_from_status()
returns trigger language plpgsql security definer set search_path=public as $$
declare total numeric; outcome_id uuid; close_time timestamptz; close_reason text;
begin
  if new.crop_status not in ('Completed','Cancelled') then return new; end if;
  select sum(quantity) into total from public.crop_harvests where crop_id = new.id;
  select closed_at, reason || case when nullif(btrim(explanation), '') is null then '' else ': ' || explanation end
    into close_time, close_reason from public.crop_closures where crop_id = new.id;
  select id into outcome_id from public.crop_outcomes where crop_id = new.id
    order by recorded_at desc, id desc limit 1;
  if outcome_id is null then
    insert into public.crop_outcomes(crop_id,crop_name,outcome,quantity,reason,recorded_by,recorded_at)
    values(new.id,new.crop_name,case when new.crop_status='Completed' then 'Harvested' else 'Failed' end,
      nullif(total, 0),coalesce(close_reason,new.maintenance_notes),coalesce(auth.uid(),new.assigned_manager),coalesce(close_time,now()));
  else
    update public.crop_outcomes set crop_name=new.crop_name,
      outcome=case when new.crop_status='Completed' then 'Harvested' else 'Failed' end,
      quantity=case when new.crop_status='Completed' then nullif(total,0) else null end,
      reason=coalesce(close_reason,new.maintenance_notes),
      recorded_by=coalesce(auth.uid(),new.assigned_manager),
      recorded_at=coalesce(close_time,recorded_at)
    where id=outcome_id;
  end if;
  return new;
end $$;

create or replace function public.refresh_crop_attention(p_crop_id uuid)
returns void language sql security definer set search_path=public as $$
  update public.crops c set
    current_care_status=coalesce((select title from public.crop_tasks where crop_id=c.id and status in ('Due','Overdue')
      order by case priority when 'Critical' then 0 when 'Important' then 1 else 2 end,due_at limit 1),'No care tasks due'),
    crop_status=case when exists(select 1 from public.crop_tasks where crop_id=c.id and status in ('Due','Overdue'))
      then 'Needs Attention' else 'Active' end
  where c.id=p_crop_id and c.crop_status not in ('Completed','Cancelled');
$$;

-- Legacy clients must continue to receive the final-harvest behavior they
-- present in their UI. Already committed submissions remain safely retryable.
create or replace function public.harvest_crop_batch(
  p_crop_id uuid, p_quantity numeric, p_performed_at timestamptz,
  p_notes text, p_submission_id text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.crops; h public.crop_harvests; destination jsonb; activity_id uuid;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then raise exception 'Crop management permission required.'; end if;
  if nullif(btrim(p_submission_id),'') is null then raise exception 'Submission ID required.'; end if;
  if p_quantity is null or p_quantity::text in ('NaN','Infinity','-Infinity') or p_quantity<=0 or p_quantity<>round(p_quantity,2)
    then raise exception 'Enter a positive weight in kg, with up to two decimal places.'; end if;
  if p_performed_at is null or p_performed_at>now()+interval '1 minute' then raise exception 'Enter a valid harvest time, not in the future.'; end if;
  perform pg_advisory_xact_lock(hashtext('crop-submit:'||p_submission_id));
  select * into h from public.crop_harvests where submission_id=p_submission_id;
  if found then
    if h.crop_id<>p_crop_id or h.harvested_by<>auth.uid() or h.quantity<>p_quantity
      or h.harvest_date<>(p_performed_at at time zone 'Asia/Manila')::date
      or h.remarks is distinct from p_notes then raise exception 'Submission ID already belongs to another harvest.'; end if;
    return jsonb_build_object('harvest_id',h.id,'crop_id',h.crop_id,'inventory_id',h.inventory_id,'quantity',h.quantity,'unit','kg','status','Completed');
  end if;
  select * into c from public.crops where id=p_crop_id for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.harvest_mode='repeat' then raise exception 'Update the app to record repeat harvests for this crop.'; end if;
  if c.crop_status in ('Completed','Cancelled') or exists(select 1 from public.crop_activities where crop_id=c.id and activity_type='Harvested')
    then raise exception 'This crop has already been harvested and closed.'; end if;
  if (p_performed_at at time zone 'Asia/Manila')::date<c.planting_date then raise exception 'Harvest cannot precede planting.'; end if;
  destination:=public.crop_harvest_destination(c.id);
  perform 1 from public.inventory where id=(destination->>'id')::uuid for update;
  destination:=public.crop_harvest_destination(c.id);
  insert into public.crop_harvests(crop_id,inventory_id,quantity,unit,harvest_date,harvested_by,remarks,submission_id)
    values(c.id,(destination->>'id')::uuid,p_quantity,'kg',(p_performed_at at time zone 'Asia/Manila')::date,auth.uid(),p_notes,p_submission_id) returning * into h;
  insert into public.inventory_transactions(inventory_id,transaction_type,quantity,remarks,performed_by,source,source_id)
    values(h.inventory_id,'IN',p_quantity,'Batch harvest: '||coalesce(c.batch_code,c.id::text),auth.uid(),'harvest',h.id);
  insert into public.crop_activities(crop_id,activity_type,performed_at,performed_by,quantity,unit,notes,source,idempotency_key,metadata)
    values(c.id,'Harvested',p_performed_at,auth.uid(),p_quantity,'kg',p_notes,'User',p_submission_id,
      jsonb_build_object('crop_harvest_id',h.id,'inventory_id',h.inventory_id)) returning id into activity_id;
  insert into public.crop_closures(crop_id,reason,closed_by,closure_source,submission_id,submission_payload)
    values(c.id,'Harvest recorded',auth.uid(),'single_harvest','close:'||p_submission_id,
      jsonb_build_object('crop_id',c.id,'source_submission_id',p_submission_id)) on conflict(crop_id) do nothing;
  update public.crops set crop_status='Completed',growth_stage='Completed',harvested_at=p_performed_at,
    harvest_inventory_id=h.inventory_id,current_care_status='Crop harvested',updated_at=now() where id=c.id;
  update public.crop_tasks set status='Dismissed',updated_at=now() where crop_id=c.id and status not in ('Completed','Dismissed');
  perform public.safe_activity_log(auth.uid(),'Crop harvested',c.crop_name||': '||p_quantity||' kg added to inventory. Crop closed.','Crops');
  return jsonb_build_object('harvest_id',h.id,'activity_id',activity_id,'crop_id',c.id,'inventory_id',h.inventory_id,
    'inventory_name',destination->>'name','quantity',p_quantity,'unit','kg','status','Completed','harvest_mode','single');
end $$;

create or replace function public._record_crop_harvest_v2(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.crops; h public.crop_harvests; destination jsonb; activity_id uuid; submission text; payload jsonb;
  quantity_value numeric; performed timestamptz; next_day date; total_value numeric; count_value integer; first_harvest boolean;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then raise exception 'Crop management permission required.'; end if;
  submission:=nullif(btrim(p_entry->>'submission_id'),'');
  if submission is null then raise exception 'Submission ID required.'; end if;
  quantity_value:=nullif(p_entry->>'quantity','')::numeric;
  performed:=nullif(p_entry->>'performed_at','')::timestamptz;
  next_day:=nullif(p_entry->>'next_check_on','')::date;
  if quantity_value is null or quantity_value::text in ('NaN','Infinity','-Infinity') or quantity_value<=0 or quantity_value<>round(quantity_value,2)
    then raise exception 'Enter a positive weight in kg, with up to two decimal places.'; end if;
  if performed is null or performed>now()+interval '1 minute' then raise exception 'Enter a valid harvest time, not in the future.'; end if;
  if next_day is not null and next_day < (now() at time zone 'Asia/Manila')::date then raise exception 'Choose today or a later date for the next check.'; end if;
  payload:=jsonb_build_object('crop_id',p_entry->>'crop_id','quantity',quantity_value,'performed_at',performed,
    'notes',nullif(btrim(p_entry->>'notes'),''),'task_id',nullif(p_entry->>'task_id',''),
    'next_check_on',next_day,'version',2);
  perform pg_advisory_xact_lock(hashtext('crop-submit:'||submission));
  select * into h from public.crop_harvests where submission_id=submission;
  if found then
    if h.crop_id<>(p_entry->>'crop_id')::uuid or h.harvested_by<>auth.uid() or h.quantity<>quantity_value
      or h.harvest_date<>(performed at time zone 'Asia/Manila')::date
      or h.remarks is distinct from payload->>'notes'
      or (h.submission_payload is not null and h.submission_payload<>payload)
      then raise exception 'Submission ID already belongs to a different harvest. Contact support before trying again.'; end if;
    select * into c from public.crops where id=h.crop_id;
    select count(*),coalesce(sum(quantity),0),max(harvest_date) into count_value,total_value,performed from public.crop_harvests where crop_id=h.crop_id;
    return jsonb_build_object('harvest_id',h.id,'crop_id',h.crop_id,'activity_id',(select id from public.crop_activities where idempotency_key=submission),
      'inventory_id',h.inventory_id,'inventory_name',(select item_name from public.inventory where id=h.inventory_id),
      'quantity',h.quantity,'unit','kg','status',c.crop_status,'harvest_mode',c.harvest_mode,
      'harvest_count',count_value,'total_quantity',total_value,'latest_harvest_date',performed);
  end if;
  select * into c from public.crops where id=(p_entry->>'crop_id')::uuid for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.harvest_mode<>'repeat' or lower(coalesce(c.crop_profile_key,'')) not in ('sitaw','calamansi') then
    raise exception 'This crop uses a single harvest. Use its final-harvest action.'; end if;
  if c.crop_status in ('Completed','Cancelled') then raise exception 'This crop has ended and cannot be harvested again.'; end if;
  if (performed at time zone 'Asia/Manila')::date<c.planting_date then raise exception 'Harvest cannot precede planting.'; end if;
  if not exists(select 1 from public.crop_harvests where crop_id=c.id)
    and not (c.crop_status='Harvest Ready' or public.crop_growth_stage_order(c.id,c.growth_stage)>=public.crop_growth_stage_order(c.id,'Harvest Ready')
      or (c.crop_profile_key='calamansi' and c.growth_stage='First Bearing')) then
    raise exception 'Record the first harvest when this crop is ready.'; end if;
  select not exists(select 1 from public.crop_harvests where crop_id=c.id) into first_harvest;
  if nullif(p_entry->>'task_id','') is not null and not exists(
    select 1 from public.crop_tasks where id=(p_entry->>'task_id')::uuid and crop_id=c.id and status not in ('Completed','Dismissed')
      and task_type in ('Harvest Check','Inspect')) then raise exception 'This harvest check no longer belongs to the crop.'; end if;
  destination:=public.crop_harvest_destination(c.id);
  perform 1 from public.inventory where id=(destination->>'id')::uuid for update;
  destination:=public.crop_harvest_destination(c.id);
  insert into public.crop_harvests(crop_id,inventory_id,quantity,unit,harvest_date,harvested_by,remarks,submission_id,submission_payload)
    values(c.id,(destination->>'id')::uuid,quantity_value,'kg',(performed at time zone 'Asia/Manila')::date,auth.uid(),payload->>'notes',submission,payload) returning * into h;
  insert into public.inventory_transactions(inventory_id,transaction_type,quantity,remarks,performed_by,source,source_id)
    values(h.inventory_id,'IN',quantity_value,'Harvest: '||coalesce(c.batch_code,c.id::text),auth.uid(),'harvest',h.id);
  insert into public.crop_activities(crop_id,activity_type,performed_at,performed_by,quantity,unit,notes,task_id,source,idempotency_key,metadata)
    values(c.id,'Harvested',performed,auth.uid(),quantity_value,'kg',payload->>'notes',nullif(p_entry->>'task_id','')::uuid,'User',submission,
      jsonb_build_object('crop_harvest_id',h.id,'inventory_id',h.inventory_id,'harvest_mode','repeat')) returning id into activity_id;
  update public.crop_tasks set status='Completed',completed_at=now(),completed_by=auth.uid(),updated_at=now()
    where crop_id=c.id and status not in ('Completed','Dismissed') and task_type='Harvest Check'
      and (id=nullif(p_entry->>'task_id','')::uuid or due_at<=performed or first_harvest);
  if next_day is not null then
    update public.crop_tasks set status='Dismissed',updated_at=now()
      where crop_id=c.id and task_type='Harvest Check' and status not in ('Completed','Dismissed')
        and coalesce(recommendation_data->>'repeat_harvest_check','false')='true';
    insert into public.crop_tasks(crop_id,task_type,title,recommendation,recommendation_data,due_at,status,priority,deduplication_key)
      values(c.id,'Harvest Check','Check whether more produce is ready to pick.',
        'Look over the plants and pick only produce that is ready.',
        jsonb_build_object('repeat_harvest_check',true,'source_submission_id',submission),
        (next_day::timestamp + time '09:00') at time zone 'Asia/Manila',
        case when (next_day::timestamp + time '09:00') at time zone 'Asia/Manila' <= now() then 'Due' else 'Upcoming' end,
        'Routine','repeat-harvest:'||c.id::text||':'||submission);
  end if;
  update public.crops set harvested_at=greatest(coalesce(harvested_at,performed),performed),
    harvest_inventory_id=h.inventory_id,updated_at=now() where id=c.id;
  perform public.refresh_crop_attention(c.id);
  perform public.safe_activity_log(auth.uid(),'Crop harvest recorded',c.crop_name||': '||quantity_value||' kg added to inventory. Crop remains active.','Crops');
  select count(*),coalesce(sum(quantity),0),max(harvest_date) into count_value,total_value,performed from public.crop_harvests where crop_id=c.id;
  select * into c from public.crops where id=c.id;
  return jsonb_build_object('harvest_id',h.id,'activity_id',activity_id,'crop_id',c.id,'inventory_id',h.inventory_id,
    'inventory_name',destination->>'name','quantity',quantity_value,'unit','kg','status',c.crop_status,'harvest_mode',c.harvest_mode,
    'harvest_count',count_value,'total_quantity',total_value,'latest_harvest_date',performed);
end $$;

create or replace function public.record_crop_harvest(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
begin return public._record_crop_harvest_v2(p_entry); end $$;

create or replace function public.end_crop(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.crops; submission text; reason_text text; explanation_text text; payload jsonb; closure_id uuid;
  activity_id uuid; total_value numeric; count_value integer; status_value text;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then raise exception 'Crop management permission required.'; end if;
  submission:=nullif(btrim(p_entry->>'submission_id'),'');
  reason_text:=nullif(btrim(p_entry->>'reason'),'');
  explanation_text:=nullif(btrim(p_entry->>'explanation'),'');
  if submission is null then raise exception 'Submission ID required.'; end if;
  if reason_text is null or reason_text not in ('Plants stopped producing','Plants removed','Plants died','Other') then raise exception 'Choose why this crop is ending.'; end if;
  if reason_text='Other' and explanation_text is null then raise exception 'Explain why this crop is ending.'; end if;
  payload:=jsonb_build_object('crop_id',p_entry->>'crop_id','reason',reason_text,'explanation',explanation_text,'version',2);
  perform pg_advisory_xact_lock(hashtext('crop-submit:'||submission));
  select id into closure_id from public.crop_closures where submission_id=submission;
  if closure_id is not null then
    if not exists(select 1 from public.crop_closures where id=closure_id and crop_id=(p_entry->>'crop_id')::uuid
      and closed_by=auth.uid() and submission_payload=payload) then raise exception 'Submission ID already belongs to a different crop closure.'; end if;
    select * into c from public.crops where id=(p_entry->>'crop_id')::uuid;
    select count(*),coalesce(sum(quantity),0) into count_value,total_value from public.crop_harvests where crop_id=c.id;
    return jsonb_build_object('closure_id',closure_id,'crop_id',c.id,'status',c.crop_status,'closed_at',(select closed_at from public.crop_closures where id=closure_id),'harvest_count',count_value,'total_quantity',total_value);
  end if;
  select * into c from public.crops where id=(p_entry->>'crop_id')::uuid for update;
  if not found then raise exception 'Crop not found.'; end if;
  if c.crop_status in ('Completed','Cancelled') then raise exception 'This crop has already ended.'; end if;
  insert into public.crop_closures(crop_id,reason,explanation,closed_by,closure_source,submission_id,submission_payload)
    values(c.id,reason_text,explanation_text,auth.uid(),'farmer',submission,payload) returning id into closure_id;
  select count(*),coalesce(sum(quantity),0) into count_value,total_value from public.crop_harvests where crop_id=c.id;
  status_value:=case when count_value>0 then 'Completed' else 'Cancelled' end;
  insert into public.crop_activities(crop_id,activity_type,performed_at,performed_by,notes,source,idempotency_key,metadata)
    values(c.id,'Not Harvested',now(),auth.uid(),coalesce(explanation_text,reason_text),'User','end:'||submission,
      jsonb_build_object('closure_id',closure_id,'closure_reason',reason_text)) returning id into activity_id;
  update public.crop_tasks set status='Dismissed',updated_at=now() where crop_id=c.id and status not in ('Completed','Dismissed');
  update public.crops set crop_status=status_value,
    growth_stage=case when status_value='Completed' then 'Completed' else growth_stage end,
    maintenance_notes=coalesce(explanation_text,reason_text),current_care_status='Crop ended',updated_at=now()
    where id=c.id;
  perform public.safe_activity_log(auth.uid(),'Crop ended',c.crop_name||': '||reason_text||'. '||count_value||' harvests recorded.','Crops');
  return jsonb_build_object('closure_id',closure_id,'activity_id',activity_id,'crop_id',c.id,'status',status_value,
    'closed_at',(select closed_at from public.crop_closures where id=closure_id),'harvest_count',count_value,'total_quantity',total_value);
end $$;

create or replace function public.get_crop_harvest_summaries(p_crop_ids uuid[])
returns table(crop_id uuid, harvest_count bigint, total_quantity numeric, latest_harvest_date date)
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null or not (public.has_permission('crops.view') or public.has_permission('crops.manage')) then raise exception 'Crop viewing permission required.'; end if;
  return query select h.crop_id,count(*)::bigint,coalesce(sum(h.quantity),0),max(h.harvest_date)
    from public.crop_harvests h join public.crops c on c.id=h.crop_id
    where h.crop_id=any(coalesce(p_crop_ids,'{}'::uuid[])) group by h.crop_id;
end $$;

create or replace function public.get_crop_harvest_history(p_crop_id uuid,p_limit integer default 20,p_offset integer default 0)
returns table(id uuid,quantity numeric,unit text,harvest_date date,harvested_by uuid,harvested_by_name text,remarks text,inventory_id uuid)
language plpgsql stable security definer set search_path=public as $$
begin
  if auth.uid() is null or not (public.has_permission('crops.view') or public.has_permission('crops.manage')) then raise exception 'Crop viewing permission required.'; end if;
  if not exists(select 1 from public.crops where id=p_crop_id) then raise exception 'Crop not found.'; end if;
  return query select h.id,h.quantity,h.unit,h.harvest_date,h.harvested_by,p.full_name,h.remarks,h.inventory_id
    from public.crop_harvests h left join public.profiles p on p.id=h.harvested_by where h.crop_id=p_crop_id
    order by h.harvest_date desc,h.id desc limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(coalesce(p_offset,0),0);
end $$;

create or replace function public.get_crop_harvest_submission(p_submission_id text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare h public.crop_harvests;
begin
  if auth.uid() is null or not public.has_permission('crops.manage') then raise exception 'Crop management permission required.'; end if;
  select * into h from public.crop_harvests where submission_id=p_submission_id and harvested_by=auth.uid();
  if not found then return null; end if;
  return jsonb_build_object('id',h.id,'crop_id',h.crop_id,'quantity',h.quantity,'harvest_date',h.harvest_date,'inventory_id',h.inventory_id);
end $$;

create or replace function public.finish_crop_cycle(p_crop_id uuid,p_outcome text default 'Finished',p_notes text default null,p_idempotency_key text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare result jsonb; reason_text text;
begin
  reason_text:=case p_outcome when 'Removed' then 'Plants removed' when 'Failed' then 'Plants died' else 'Other' end;
  if reason_text='Other' and nullif(btrim(p_notes),'') is null then p_notes:='Crop ended from an older app version.'; end if;
  result:=public.end_crop(jsonb_build_object('crop_id',p_crop_id,'reason',reason_text,'explanation',p_notes,'submission_id',coalesce(p_idempotency_key,gen_random_uuid()::text)));
  return (result->>'closure_id')::uuid;
end $$;

revoke all on function public._record_crop_harvest_v2(jsonb) from public,authenticated;
revoke all on function public.record_crop_harvest(jsonb),public.end_crop(jsonb),
  public.get_crop_harvest_summaries(uuid[]),public.get_crop_harvest_history(uuid,integer,integer),
  public.get_crop_harvest_submission(text) from public;
grant execute on function public.record_crop_harvest(jsonb),public.end_crop(jsonb),
  public.get_crop_harvest_summaries(uuid[]),public.get_crop_harvest_history(uuid,integer,integer),
  public.get_crop_harvest_submission(text) to authenticated;
grant all on public.crop_closures to service_role;

commit;
