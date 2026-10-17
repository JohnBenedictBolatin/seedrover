begin;

-- Keep retry identity separate from payment references and inventory request IDs.
create table if not exists public.action_submissions (
  operation text not null,
  submission_id uuid not null,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  payload jsonb not null,
  result jsonb,
  created_at timestamptz not null default now(),
  primary key (operation, submission_id)
);
alter table public.action_submissions enable row level security;
revoke all on public.action_submissions from public, anon, authenticated;
grant all on public.action_submissions to service_role;

create table if not exists public.crop_harvest_corrections (
  id uuid primary key default gen_random_uuid(),
  crop_harvest_id uuid not null references public.crop_harvests(id) on delete restrict,
  revision integer not null check (revision > 0),
  corrected_by uuid not null references public.profiles(id) on delete restrict,
  previous_quantity numeric(12,2) not null,
  new_quantity numeric(12,2) not null check (new_quantity > 0),
  previous_notes text,
  new_notes text,
  reason text not null check (length(btrim(reason)) > 0),
  submission_id uuid not null unique,
  submission_payload jsonb not null,
  result jsonb,
  created_at timestamptz not null default now(),
  unique (crop_harvest_id, revision)
);
alter table public.crop_harvest_corrections enable row level security;
revoke all on public.crop_harvest_corrections from public, anon, authenticated;
grant all on public.crop_harvest_corrections to service_role;

-- Persisted business records are written through permission-checked RPCs.
-- Keep direct client reads under RLS, while preventing a client from bypassing
-- those workflows with table inserts/updates/deletes.
revoke insert, update, delete on public.inventory_transactions from public, anon, authenticated;
revoke insert, update, delete on public.crop_harvests from public, anon, authenticated;
revoke insert, update, delete on public.sales_orders from public, anon, authenticated;
revoke insert, update, delete on public.sales_order_items from public, anon, authenticated;
grant select on public.inventory_transactions, public.crop_harvests,
  public.sales_orders, public.sales_order_items to authenticated;
grant all on public.inventory_transactions, public.crop_harvests,
  public.sales_orders, public.sales_order_items to service_role;

alter table public.inventory_transactions
  drop constraint if exists inventory_transactions_source_allowed;
alter table public.inventory_transactions
  add constraint inventory_transactions_source_allowed
  check (source in ('manual', 'sale', 'void_sale', 'harvest', 'harvest_correction'));

create or replace function public.get_operation_submission(
  p_operation text,
  p_submission_id uuid
) returns jsonb
language plpgsql stable security definer set search_path = public, auth as $$
declare response jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in to check this saved action.'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active) then
    raise exception 'This account is inactive.';
  end if;
  select s.result into response from public.action_submissions s
   where s.operation = p_operation and s.submission_id = p_submission_id
     and s.actor_id = auth.uid();
  return response;
end;
$$;

create or replace function public.record_inventory_movement_v2(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  submission uuid := nullif(p_entry->>'submission_id', '')::uuid;
  payload jsonb;
  prior public.action_submissions%rowtype;
  movement public.inventory_transactions%rowtype;
  activity_label text;
  activity_description text;
  operation_name constant text := 'inventory_movement';
begin
  if actor is null or not exists (select 1 from public.profiles p where p.id = actor and p.is_active)
    or not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to change inventory stock.';
  end if;
  if submission is null then raise exception 'A saved action ID is required.'; end if;
  payload := jsonb_build_object(
    'inventory_id', p_entry->>'inventory_id',
    'transaction_type', upper(trim(coalesce(p_entry->>'transaction_type', ''))),
    'quantity', (p_entry->>'quantity')::numeric,
    'reason', nullif(trim(p_entry->>'reason'), ''),
    'remarks', nullif(trim(p_entry->>'remarks'), ''),
    'received_on', nullif(p_entry->>'received_on', '')::date,
    'harvest_on', nullif(p_entry->>'harvest_on', '')::date,
    'profile_id', nullif(p_entry->>'profile_id', ''),
    'target_batch_id', nullif(p_entry->>'target_batch_id', '')
  );
  perform pg_advisory_xact_lock(hashtextextended(operation_name || ':' || submission::text, 0));
  select * into prior from public.action_submissions
   where operation = operation_name and submission_id = submission for update;
  if found then
    if prior.actor_id <> actor or prior.payload <> payload then
      raise exception 'This saved action ID belongs to a different inventory change.';
    end if;
    return prior.result;
  end if;
  insert into public.action_submissions(operation, submission_id, actor_id, payload)
    values(operation_name, submission, actor, payload);
  movement := public.record_inventory_movement_with_batch(
    (payload->>'inventory_id')::uuid,
    payload->>'transaction_type',
    (payload->>'quantity')::numeric,
    payload->>'reason', payload->>'remarks',
    (payload->>'received_on')::date, (payload->>'harvest_on')::date,
    payload->>'profile_id', submission,
    nullif(payload->>'target_batch_id', '')::uuid
  );
  if movement.id is null or movement.performed_by <> actor
    or movement.inventory_id <> (payload->>'inventory_id')::uuid
    or movement.transaction_type <> payload->>'transaction_type'
    or movement.quantity <> (payload->>'quantity')::numeric
    or movement.remarks is distinct from concat_ws(E'\n',
      nullif(trim(payload->>'reason'), ''),
      coalesce(nullif(trim(payload->>'remarks'), ''), 'Inventory updated.'))
    or movement.batch_received_on is distinct from (payload->>'received_on')::date
    or movement.batch_harvest_on is distinct from (payload->>'harvest_on')::date
    or movement.batch_profile_id is distinct from payload->>'profile_id'
    or movement.target_batch_id is distinct from nullif(payload->>'target_batch_id', '')::uuid
    or movement.request_id is distinct from submission then
    raise exception 'The saved inventory action could not be verified.';
  end if;
  activity_label := case payload->>'transaction_type'
    when 'IN' then 'Receive stock recorded'
    when 'OUT' then 'Issue stock recorded'
    else 'Inventory quantity adjusted' end;
  activity_description := (select i.item_name from public.inventory i
    where i.id = (payload->>'inventory_id')::uuid) || ': '
    || case payload->>'transaction_type'
      when 'IN' then (payload->>'quantity') || ' kg added.'
      when 'OUT' then (payload->>'quantity') || ' kg deducted.'
      else 'quantity set to ' || (payload->>'quantity') || ' kg.' end;
  perform public.safe_activity_log(actor, activity_label, activity_description, 'Inventory');
  update public.action_submissions set result = to_jsonb(movement)
   where operation = operation_name and submission_id = submission;
  return to_jsonb(movement);
end;
$$;

-- A corrected harvest retains its original request payload for safe retries.
-- Compare that immutable payload instead of the corrected display fields.
create or replace function public.record_crop_harvest(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  submission text := nullif(btrim(p_entry->>'submission_id'), '');
  submission_uuid uuid;
  performed timestamptz := nullif(p_entry->>'performed_at', '')::timestamptz;
  quantity_value numeric := nullif(p_entry->>'quantity', '')::numeric;
  next_day date := nullif(p_entry->>'next_check_on', '')::date;
  original public.crop_harvests%rowtype;
  prior public.action_submissions%rowtype;
  crop_row public.crops%rowtype;
  result jsonb;
  payload jsonb;
  count_value bigint;
  total_value numeric;
  latest_day date;
begin
  if auth.uid() is null or not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active)
    or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;
  if submission is null then raise exception 'Submission ID required.'; end if;
  begin
    submission_uuid := submission::uuid;
  exception when invalid_text_representation then
    -- Preserve the legacy text-ID contract for older clients. New clients send
    -- UUIDs and receive the stronger submission journal behavior below.
    return public._record_crop_harvest_v2(p_entry);
  end;
  payload := jsonb_build_object(
    'crop_id', p_entry->>'crop_id',
    'quantity', quantity_value,
    'performed_at', performed,
    'notes', nullif(btrim(p_entry->>'notes'), ''),
    'task_id', nullif(p_entry->>'task_id', ''),
    'next_check_on', next_day,
    'version', 2
  );
  perform pg_advisory_xact_lock(hashtext('crop-submit:' || submission));
  select * into prior from public.action_submissions
   where operation = 'crop_harvest' and submission_id = submission_uuid for update;
  if found then
    if prior.actor_id <> auth.uid() or prior.payload <> payload then
      raise exception 'This saved harvest ID has different original details. Keep it for review.';
    end if;
    return prior.result;
  end if;
  select * into original from public.crop_harvests where submission_id = submission;
  if found then
    if original.harvested_by <> auth.uid()
      or original.crop_id is distinct from nullif(payload->>'crop_id', '')::uuid
      or original.quantity is distinct from quantity_value
      or original.harvest_date is distinct from (performed at time zone 'Asia/Manila')::date
      or original.remarks is distinct from payload->>'notes'
      or (original.submission_payload is not null and original.submission_payload <> payload) then
      raise exception 'This saved harvest ID has different original details. Keep it for review.';
    end if;
    select * into crop_row from public.crops where id = original.crop_id;
    select count(*), coalesce(sum(quantity), 0), max(harvest_date)
      into count_value, total_value, latest_day
      from public.crop_harvests where crop_id = original.crop_id;
    result := jsonb_build_object(
      'harvest_id', original.id, 'crop_id', original.crop_id,
      'activity_id', (select id from public.crop_activities where idempotency_key = submission),
      'inventory_id', original.inventory_id,
      'inventory_name', (select item_name from public.inventory where id = original.inventory_id),
      'quantity', (original.submission_payload->>'quantity')::numeric, 'unit', 'kg', 'status', crop_row.crop_status,
      'harvest_mode', crop_row.harvest_mode, 'harvest_count', count_value,
      'total_quantity', total_value, 'latest_harvest_date', latest_day
    );
    insert into public.action_submissions(operation, submission_id, actor_id, payload, result)
      values ('crop_harvest', submission_uuid, auth.uid(), payload, result);
    return result;
  end if;
  result := public._record_crop_harvest_v2(p_entry);
  insert into public.action_submissions(operation, submission_id, actor_id, payload, result)
    values ('crop_harvest', submission_uuid, auth.uid(), payload, result);
  return result;
end;
$$;

create or replace function public.record_sales_order_v2(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  submission uuid := nullif(p_entry->>'submission_id', '')::uuid;
  payload jsonb;
  prior public.action_submissions%rowtype;
  receipt public.sales_orders%rowtype;
  operation_name constant text := 'sales_order';
begin
  if actor is null or not exists (select 1 from public.profiles p where p.id = actor and p.is_active)
    or (not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage')) then
    raise exception 'Not allowed to record sales.';
  end if;
  if submission is null then raise exception 'A saved action ID is required.'; end if;
  if jsonb_typeof(p_entry->'items') = 'array' then
    payload := jsonb_build_object(
      'customer_name', nullif(trim(p_entry->>'customer_name'), ''),
      'customer_contact', public.normalize_contact_number(p_entry->>'customer_contact'),
      'payment_method', p_entry->>'payment_method',
      'transaction_reference', nullif(trim(p_entry->>'transaction_reference'), ''),
      'other_payment_method', nullif(trim(p_entry->>'other_payment_method'), ''),
      'discount_type', p_entry->>'discount_type',
      'discount_value', (p_entry->>'discount_value')::numeric,
      'discount_code', nullif(trim(p_entry->>'discount_code'), ''),
      'amount_paid', (p_entry->>'amount_paid')::numeric,
      'remarks', nullif(trim(p_entry->>'remarks'), ''),
      'items', p_entry->'items', 'version', 2
    );
    if payload->>'customer_contact' is null then raise exception 'Enter a valid customer contact number.'; end if;
    perform pg_advisory_xact_lock(hashtextextended(operation_name || ':' || submission::text, 0));
    select * into prior from public.action_submissions
     where operation = operation_name and submission_id = submission for update;
    if found then
      if prior.actor_id <> actor or prior.payload <> payload then
        raise exception 'This saved action ID belongs to a different sale.';
      end if;
      return prior.result;
    end if;
    insert into public.action_submissions(operation, submission_id, actor_id, payload)
      values(operation_name, submission, actor, payload);
    receipt := public.record_sales_order(
      payload->>'customer_name', payload->>'customer_contact', payload->>'payment_method',
      payload->>'discount_type', (payload->>'discount_value')::numeric,
      (payload->>'amount_paid')::numeric, payload->>'remarks', payload->'items',
      payload->>'discount_code', payload->>'transaction_reference',
      payload->>'other_payment_method'
    );
    update public.action_submissions set result = to_jsonb(receipt)
     where operation = operation_name and submission_id = submission;
    return to_jsonb(receipt);
  end if;
  payload := jsonb_build_object(
    'inventory_id', p_entry->>'inventory_id',
    'quantity_sold', (p_entry->>'quantity_sold')::numeric,
    'unit_price', (p_entry->>'unit_price')::numeric,
    'sale_date', (p_entry->>'sale_date')::timestamptz,
    'customer_name', nullif(trim(p_entry->>'customer_name'), ''),
    'customer_contact', public.normalize_contact_number(p_entry->>'customer_contact'),
    'remarks', nullif(trim(p_entry->>'remarks'), ''),
    'payment_method', p_entry->>'payment_method',
    'transaction_reference', nullif(trim(p_entry->>'transaction_reference'), ''),
    'other_payment_method', nullif(trim(p_entry->>'other_payment_method'), ''),
    'target_batch_id', nullif(p_entry->>'target_batch_id', '')
  );
  perform pg_advisory_xact_lock(hashtextextended(operation_name || ':' || submission::text, 0));
  select * into prior from public.action_submissions
   where operation = operation_name and submission_id = submission for update;
  if found then
    if prior.actor_id <> actor or prior.payload <> payload then
      raise exception 'This saved action ID belongs to a different sale.';
    end if;
    return prior.result;
  end if;
  insert into public.action_submissions(operation, submission_id, actor_id, payload)
    values(operation_name, submission, actor, payload);
  receipt := public.record_inventory_sale_receipt(
    (payload->>'inventory_id')::uuid,
    (payload->>'quantity_sold')::numeric,
    (payload->>'unit_price')::numeric,
    (payload->>'sale_date')::timestamptz,
    payload->>'customer_name', payload->>'customer_contact', payload->>'remarks',
    payload->>'payment_method', payload->>'transaction_reference',
    payload->>'other_payment_method', nullif(payload->>'target_batch_id', '')::uuid
  );
  update public.action_submissions set result = to_jsonb(receipt)
   where operation = operation_name and submission_id = submission;
  return to_jsonb(receipt);
end;
$$;

create or replace function public.void_sales_record_v2(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  submission uuid := nullif(p_entry->>'submission_id', '')::uuid;
  payload jsonb;
  prior public.action_submissions%rowtype;
  result_value jsonb;
  operation_name constant text := 'void_sale';
begin
  if actor is null or not exists (select 1 from public.profiles p where p.id = actor and p.is_active)
    or coalesce(public.current_user_role_name(), '') not in (
    'System Administrator', 'Farm Inventory Manager'
  ) then raise exception 'Only an administrator or inventory manager can void sales.'; end if;
  if submission is null then raise exception 'A saved action ID is required.'; end if;
  payload := jsonb_build_object(
    'id', p_entry->>'id', 'source', p_entry->>'source',
    'reason', coalesce(nullif(trim(p_entry->>'reason'), ''), 'Voided from SeedRover.')
  );
  perform pg_advisory_xact_lock(hashtextextended(operation_name || ':' || submission::text, 0));
  select * into prior from public.action_submissions
   where operation = operation_name and submission_id = submission for update;
  if found then
    if prior.actor_id <> actor or prior.payload <> payload then
      raise exception 'This saved action ID belongs to a different cancellation.';
    end if;
    return prior.result;
  end if;
  insert into public.action_submissions(operation, submission_id, actor_id, payload)
    values(operation_name, submission, actor, payload);
  result_value := public.void_sales_record(
    (payload->>'id')::uuid, payload->>'source', payload->>'reason'
  );
  update public.action_submissions set result = result_value
   where operation = operation_name and submission_id = submission;
  return result_value;
end;
$$;

create or replace function public.correct_crop_harvest(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  harvest_id uuid := nullif(p_entry->>'harvest_id', '')::uuid;
  submission uuid := nullif(p_entry->>'submission_id', '')::uuid;
  new_quantity numeric := (p_entry->>'quantity')::numeric;
  new_notes text := nullif(trim(p_entry->>'notes'), '');
  correction_reason text := nullif(trim(p_entry->>'reason'), '');
  expected_revision integer := (p_entry->>'expected_revision')::integer;
  payload jsonb;
  prior public.crop_harvest_corrections%rowtype;
  crop public.crops%rowtype;
  harvest public.crop_harvests%rowtype;
  receipt public.inventory_transactions%rowtype;
  batch public.inventory_stock_batches%rowtype;
  item public.inventory%rowtype;
  revision integer;
  correction_id uuid;
  correction_activity_id uuid;
  result_value jsonb;
begin
  if actor is null or public.current_user_role_name() <> 'System Administrator'
    or not exists (select 1 from public.profiles p where p.id = actor and p.is_active) then
    raise exception 'Only an active administrator can correct a harvest.';
  end if;
  if harvest_id is null or submission is null then raise exception 'A saved correction ID is required.'; end if;
  if new_quantity is null or new_quantity::text in ('NaN','Infinity','-Infinity')
    or new_quantity <= 0 or new_quantity > 9999999999.99
    or new_quantity <> round(new_quantity, 2) then
    raise exception 'Enter a harvest weight greater than zero, with up to two decimal places.';
  end if;
  if correction_reason is null or char_length(correction_reason) > 500 then
    raise exception 'Explain why this harvest needs correction.';
  end if;
  if new_notes is not null and char_length(new_notes) > 2000 then
    raise exception 'Harvest notes must be 2,000 characters or fewer.';
  end if;
  payload := jsonb_build_object(
    'harvest_id', harvest_id, 'quantity', new_quantity, 'notes', new_notes,
    'reason', correction_reason, 'expected_revision', expected_revision, 'version', 1
  );
  perform pg_advisory_xact_lock(hashtextextended('harvest-correction:' || submission::text, 0));
  select * into prior from public.crop_harvest_corrections
   where submission_id = submission;
  if found then
    if prior.corrected_by <> actor or prior.submission_payload <> payload then
      raise exception 'This saved action ID belongs to a different correction.';
    end if;
    return prior.result;
  end if;

  select c.* into crop from public.crops c
   join public.crop_harvests h on h.crop_id = c.id where h.id = harvest_id for update of c;
  if not found then raise exception 'Harvest record was not found.'; end if;
  if crop.crop_status in ('Completed', 'Cancelled') then
    raise exception 'Harvests on ended crops cannot be corrected.';
  end if;
  select * into harvest from public.crop_harvests where id = harvest_id for update;
  if harvest.quantity = new_quantity and harvest.remarks is not distinct from new_notes then
    raise exception 'Change the weight or notes before saving this correction.';
  end if;
  select count(*)::integer into revision from public.crop_harvest_corrections where crop_harvest_id = harvest_id;
  if expected_revision is null or expected_revision <> revision then
    raise exception 'This harvest changed on another device. Refresh it before correcting.';
  end if;

  select t.* into receipt from public.inventory_transactions t
   where t.source = 'harvest' and t.source_id = harvest.id
     and t.inventory_id = harvest.inventory_id and t.transaction_type = 'IN'
   order by t.created_at, t.id limit 1;
  if not found or (select count(*) from public.inventory_transactions t
      where t.source = 'harvest' and t.source_id = harvest.id
        and t.inventory_id = harvest.inventory_id and t.transaction_type = 'IN') <> 1 then
    raise exception 'This older harvest has no unambiguous stock receipt and cannot be corrected here.';
  end if;
  -- Inventory is locked before its batches, matching sale and movement paths.
  select * into item from public.inventory where id = harvest.inventory_id for update;
  if not found then raise exception 'The harvest inventory item was not found.'; end if;
  select * into batch from public.inventory_stock_batches b
   where b.source_transaction_id = receipt.id and b.inventory_id = harvest.inventory_id
   for update;
  if not found or batch.origin_type <> 'harvest'
    or exists (select 1 from public.inventory_stock_batches b
      where b.source_transaction_id = receipt.id and b.inventory_id = harvest.inventory_id
        and b.id <> batch.id)
    or exists (select 1 from public.inventory_stock_batch_audit a where a.batch_id = batch.id)
    or batch.initial_quantity <> harvest.quantity
    or batch.remaining_quantity <> batch.initial_quantity
    or exists (select 1 from public.inventory_transaction_batch_allocations a
      join public.inventory_transactions t on t.id = a.transaction_id
      where a.batch_id = batch.id and t.id <> receipt.id and t.source <> 'harvest_correction') then
    raise exception 'This harvest batch has been used or changed, so it cannot be safely corrected.';
  end if;
  insert into public.crop_harvest_corrections(
    crop_harvest_id, revision, corrected_by, previous_quantity, new_quantity,
    previous_notes, new_notes, reason, submission_id, submission_payload
  ) values (
    harvest.id, revision + 1, actor, harvest.quantity, new_quantity,
    harvest.remarks, new_notes, correction_reason, submission, payload
  ) returning id into correction_id;

  if new_quantity <> harvest.quantity then
    update public.inventory_stock_batches set
      initial_quantity = new_quantity,
      remaining_quantity = new_quantity
     where id = batch.id;
    insert into public.inventory_transactions(
      inventory_id, transaction_type, quantity, remarks, performed_by, source,
      source_id, request_id
    ) values (
      item.id, 'ADJUSTMENT', item.quantity + (new_quantity - harvest.quantity),
      'Harvest correction ' || harvest.quantity::text || ' kg -> ' || new_quantity::text || ' kg. ' || correction_reason,
      actor, 'harvest_correction', correction_id, submission
    );
  end if;
  update public.crop_harvests set quantity = new_quantity, remarks = new_notes
   where id = harvest.id;
  insert into public.crop_activities(
    crop_id, activity_type, performed_at, performed_by, quantity, unit, notes,
    source, idempotency_key, metadata
  ) values (
    crop.id, 'Harvest corrected', now(), actor, new_quantity, 'kg', correction_reason,
    'User', 'harvest-correction:' || submission::text,
    jsonb_build_object('crop_harvest_id', harvest.id, 'correction_id', correction_id,
      'previous_quantity', harvest.quantity, 'new_quantity', new_quantity)
  ) returning id into correction_activity_id;
  result_value := jsonb_build_object(
    'correction_id', correction_id, 'activity_id', correction_activity_id,
    'harvest_id', harvest.id, 'revision', revision + 1,
    'quantity', new_quantity, 'notes', new_notes,
    'inventory_quantity', item.quantity + (new_quantity - harvest.quantity)
  );
  update public.crop_harvest_corrections set result = result_value
   where id = correction_id;
  insert into public.action_submissions(operation, submission_id, actor_id, payload, result)
    values ('harvest_correction', submission, actor, payload, result_value);
  return result_value;
end;
$$;

create or replace function public.get_crop_harvest_corrections(p_harvest_id uuid)
returns table(revision integer, previous_quantity numeric, new_quantity numeric,
  previous_notes text, new_notes text, reason text, corrected_by_name text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or public.current_user_role_name() <> 'System Administrator'
    or not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active) then
    raise exception 'Only an active administrator can view harvest corrections.';
  end if;
  return query select c.revision, c.previous_quantity, c.new_quantity,
    c.previous_notes, c.new_notes, c.reason, p.full_name, c.created_at
    from public.crop_harvest_corrections c
    left join public.profiles p on p.id = c.corrected_by
    where c.crop_harvest_id = p_harvest_id order by c.revision desc;
end;
$$;

-- Keep the existing final-harvest and crop-ending signatures for older clients,
-- while journaling new UUID-backed requests before the workflow runs.
alter function public.harvest_crop_batch(uuid, numeric, timestamptz, text, text)
  rename to _harvest_crop_batch_v1;
create function public.harvest_crop_batch(
  p_crop_id uuid, p_quantity numeric, p_performed_at timestamptz,
  p_notes text, p_submission_id text
) returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  submission uuid;
  payload jsonb;
  prior public.action_submissions%rowtype;
  result jsonb;
begin
  begin submission := nullif(p_submission_id, '')::uuid;
  exception when invalid_text_representation then
    return public._harvest_crop_batch_v1(p_crop_id, p_quantity, p_performed_at, p_notes, p_submission_id);
  end;
  if actor is null or not exists (select 1 from public.profiles p where p.id = actor and p.is_active)
    or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;
  payload := jsonb_build_object('crop_id', p_crop_id, 'quantity', p_quantity,
    'performed_at', p_performed_at, 'notes', nullif(btrim(p_notes), ''), 'version', 1);
  perform pg_advisory_xact_lock(hashtextextended('crop-harvest-v1:' || submission::text, 0));
  select * into prior from public.action_submissions
   where operation = 'crop_harvest' and submission_id = submission for update;
  if found then
    if prior.actor_id <> actor or prior.payload <> payload then
      raise exception 'This saved harvest ID has different original details. Keep it for review.';
    end if;
    return prior.result;
  end if;
  result := public._harvest_crop_batch_v1(p_crop_id, p_quantity, p_performed_at, p_notes, p_submission_id);
  insert into public.action_submissions(operation, submission_id, actor_id, payload, result)
    values ('crop_harvest', submission, actor, payload, result);
  return result;
end;
$$;

alter function public.end_crop(jsonb) rename to _end_crop_v2;
create function public.end_crop(p_entry jsonb)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  submission uuid := nullif(p_entry->>'submission_id', '')::uuid;
  payload jsonb;
  prior public.action_submissions%rowtype;
  result jsonb;
begin
  if actor is null or not exists (select 1 from public.profiles p where p.id = actor and p.is_active)
    or not public.has_permission('crops.manage') then
    raise exception 'Crop management permission required.';
  end if;
  if submission is null then raise exception 'A saved ending ID is required.'; end if;
  payload := jsonb_build_object(
    'crop_id', p_entry->>'crop_id',
    'reason', nullif(trim(p_entry->>'reason'), ''),
    'explanation', nullif(trim(p_entry->>'explanation'), ''),
    'version', 2
  );
  perform pg_advisory_xact_lock(hashtextextended('crop-end:' || submission::text, 0));
  select * into prior from public.action_submissions
   where operation = 'end_crop' and submission_id = submission for update;
  if found then
    if prior.actor_id <> actor or prior.payload <> payload then
      raise exception 'This saved crop-ending ID has different details. Keep it for review.';
    end if;
    return prior.result;
  end if;
  result := public._end_crop_v2(p_entry);
  insert into public.action_submissions(operation, submission_id, actor_id, payload, result)
    values ('end_crop', submission, actor, payload, result);
  return result;
end;
$$;
revoke all on function public._harvest_crop_batch_v1(uuid, numeric, timestamptz, text, text),
  public._end_crop_v2(jsonb) from public, anon, authenticated;
revoke all on function public.harvest_crop_batch(uuid, numeric, timestamptz, text, text),
  public.end_crop(jsonb) from public, anon;
grant execute on function public.harvest_crop_batch(uuid, numeric, timestamptz, text, text),
  public.end_crop(jsonb) to authenticated;

revoke all on function public.get_operation_submission(text, uuid),
  public.record_inventory_movement_v2(jsonb), public.record_sales_order_v2(jsonb),
  public.void_sales_record_v2(jsonb), public.correct_crop_harvest(jsonb),
  public.get_crop_harvest_corrections(uuid) from public, anon;
grant execute on function public.get_operation_submission(text, uuid),
  public.record_inventory_movement_v2(jsonb), public.record_sales_order_v2(jsonb),
  public.void_sales_record_v2(jsonb), public.correct_crop_harvest(jsonb),
  public.get_crop_harvest_corrections(uuid) to authenticated;

commit;
