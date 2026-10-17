begin;

create or replace function public.force_delete_inventory_item(p_inventory_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_item public.inventory%rowtype;
  current_user_id uuid := auth.uid();
  related_sales_order_ids uuid[] := '{}'::uuid[];
begin
  if current_user_id is null then
    raise exception 'Sign in before deleting inventory items.';
  end if;

  if not public.is_admin() then
    raise exception 'Only system administrators can delete inventory items.';
  end if;

  select * into target_item
  from public.inventory
  where id = p_inventory_id
  for update;

  if target_item.id is null then
    raise exception 'Inventory item was not found.';
  end if;

  select coalesce(array_agg(distinct sales_order_id) filter (where sales_order_id is not null), '{}'::uuid[])
    into related_sales_order_ids
  from public.sales_order_items
  where inventory_id = p_inventory_id;

  delete from public.sales_order_items item
  where item.sales_order_id = any(related_sales_order_ids);

  delete from public.sales_orders sales_order
  where sales_order.id = any(related_sales_order_ids);

  delete from public.sales_transactions
  where inventory_id = p_inventory_id;

  delete from public.crop_harvests
  where inventory_id = p_inventory_id;

  delete from public.inventory_transactions
  where inventory_id = p_inventory_id;

  delete from public.inventory
  where id = p_inventory_id;

  insert into public.activity_logs (user_id, activity, description, module)
  values (
    current_user_id,
    'Inventory item force deleted',
    target_item.item_name || ' and related stock/sales references were removed from the inventory list.',
    'Stocks'
  );
end;
$$;

create or replace function public.crop_growth_stage_order(p_crop_id uuid, p_stage text)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  local_profile_key text;
  last_stage_order integer;
  requested_stage text := nullif(btrim(p_stage), '');
begin
  if requested_stage is null then return null; end if;
  if lower(requested_stage) in ('harvest ready', 'first harvest') then
    select c.crop_profile_key into local_profile_key
    from public.crops c
    where c.id = p_crop_id;
    if local_profile_key is null then return 10000; end if;
    select coalesce(max(s.ordinality)::integer, 0) + 1 into last_stage_order
    from public.crop_profiles p,
      jsonb_array_elements(p.stage_plan) with ordinality as s(value, ordinality)
    where p.profile_key = local_profile_key;
    return last_stage_order;
  end if;

  select s.ordinality::integer into last_stage_order
  from public.crops c
  join public.crop_profiles p on p.profile_key = c.crop_profile_key
  cross join lateral jsonb_array_elements(p.stage_plan) with ordinality as s(value, ordinality)
  where c.id = p_crop_id and lower(s.value->>'stage') = lower(requested_stage)
  limit 1;
  return last_stage_order;
end;
$$;

create or replace function public.get_crop_harvest_history(
  p_crop_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table(
  id uuid,
  quantity numeric,
  unit text,
  harvest_date date,
  harvested_by uuid,
  harvested_by_name text,
  remarks text,
  inventory_id uuid
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not (public.has_permission('crops.view') or public.has_permission('crops.manage')) then
    raise exception 'Crop viewing permission required.';
  end if;

  if not exists(select 1 from public.crops c where c.id = p_crop_id) then
    raise exception 'Crop not found.';
  end if;

  return query
  select h.id, h.quantity, h.unit, h.harvest_date, h.harvested_by,
    p.full_name, h.remarks, h.inventory_id
  from public.crop_harvests h
  left join public.profiles p on p.id = h.harvested_by
  where h.crop_id = p_crop_id
  order by h.harvest_date desc, h.id desc
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

commit;
