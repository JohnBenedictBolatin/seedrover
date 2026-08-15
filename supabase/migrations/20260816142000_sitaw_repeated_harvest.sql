-- Preserve productive sitaw batches after each picking while completing annual one-time harvest crops.

create or replace function public.harvest_crop_to_inventory(
  p_crop_id uuid,
  p_inventory_id uuid,
  p_quantity numeric,
  p_harvest_date date,
  p_remarks text default null
) returns public.crops
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor uuid := auth.uid();
  crop_row public.crops%rowtype;
  inventory_row public.inventory%rowtype;
  harvest_row public.crop_harvests%rowtype;
  clean_remarks text := coalesce(nullif(trim(coalesce(p_remarks, '')), ''), 'Harvest recorded.');
  harvest_note text;
  repeated_sitaw boolean;
begin
  if actor is null then raise exception 'Sign in before recording harvest.'; end if;
  if not public.has_permission('crops.manage') then raise exception 'Not allowed to record crop harvests.'; end if;
  if p_crop_id is null or p_inventory_id is null then raise exception 'Choose the crop and inventory item for this harvest.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Harvest quantity must be greater than zero.'; end if;
  if p_harvest_date is null or p_harvest_date > current_date then raise exception 'Enter a valid harvest date that is not in the future.'; end if;

  select * into crop_row from public.crops where id = p_crop_id for update;
  if not found then raise exception 'Crop record was not found.'; end if;
  select * into inventory_row from public.inventory where id = p_inventory_id for update;
  if not found then raise exception 'Inventory item was not found.'; end if;
  repeated_sitaw := crop_row.crop_profile_key = 'sitaw';

  insert into public.crop_harvests(crop_id, inventory_id, quantity, unit, harvest_date, harvested_by, remarks)
  values (crop_row.id, inventory_row.id, p_quantity, inventory_row.unit, p_harvest_date, actor, clean_remarks)
  returning * into harvest_row;

  insert into public.inventory_transactions(inventory_id, transaction_type, quantity, remarks, performed_by, source, source_id)
  values (inventory_row.id, 'IN', p_quantity, 'Harvest from ' || crop_row.crop_name || ': ' || clean_remarks, actor, 'harvest', harvest_row.id);

  harvest_note := to_char(p_harvest_date, 'YYYY-MM-DD') || ' - Harvested '
    || trim(to_char(p_quantity, 'FM9999999990.##')) || ' ' || inventory_row.unit
    || ' into ' || inventory_row.item_name || '. ' || clean_remarks;

  update public.crops set
    growth_stage = case when repeated_sitaw then 'Repeated Harvest' else 'Completed' end,
    crop_status = case when repeated_sitaw then 'Active' else 'Completed' end,
    current_care_status = case when repeated_sitaw then 'Next pod harvest check due in 3-4 days' else 'Crop cycle completed' end,
    maintenance_notes = concat_ws(E'\n', nullif(trim(coalesce(crop_row.maintenance_notes, '')), ''), harvest_note),
    updated_at = now()
  where id = crop_row.id returning * into crop_row;

  insert into public.crop_activities(crop_id, activity_type, performed_at, performed_by, quantity, unit, material, notes, source, idempotency_key, metadata)
  values (
    crop_row.id, 'Harvested', p_harvest_date::timestamptz, actor, p_quantity, inventory_row.unit,
    inventory_row.item_name, clean_remarks, 'User', 'harvest:' || harvest_row.id::text,
    jsonb_build_object('crop_harvest_id', harvest_row.id, 'inventory_id', inventory_row.id)
  ) on conflict (idempotency_key) where idempotency_key is not null do nothing;

  if repeated_sitaw then
    insert into public.crop_tasks(crop_id, task_type, title, recommendation, due_at, due_window_end, status, priority, deduplication_key)
    values (
      crop_row.id, 'Harvest Check', 'Check sitaw pods for the next harvest',
      'Inspect pod size and tenderness before picking. The 3-4 day interval is guidance, not an automatic harvest decision.',
      p_harvest_date::timestamptz + interval '3 days', p_harvest_date::timestamptz + interval '4 days',
      'Upcoming', 'Routine', 'crop:' || crop_row.id::text || ':repeat-harvest:' || p_harvest_date::text
    ) on conflict (deduplication_key) do nothing;
  end if;

  perform public.safe_activity_log(actor, 'Crop harvest recorded', crop_row.crop_name || ' harvest added to ' || inventory_row.item_name || ' inventory.', 'Crops');
  perform public.safe_notification(actor, 'Harvest added to inventory', trim(to_char(p_quantity, 'FM9999999990.##')) || ' ' || inventory_row.unit || ' of ' || crop_row.crop_name || ' was added to ' || inventory_row.item_name || '.', 'Inventory', '/stocks');
  return crop_row;
end;
$$;

revoke all on function public.harvest_crop_to_inventory(uuid,uuid,numeric,date,text) from public;
grant execute on function public.harvest_crop_to_inventory(uuid,uuid,numeric,date,text) to authenticated;
