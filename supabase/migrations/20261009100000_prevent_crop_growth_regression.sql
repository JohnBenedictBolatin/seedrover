begin;

create or replace function public.crop_growth_stage_order(p_crop_id uuid, p_stage text)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile_key text;
  last_stage_order integer;
  requested_stage text := nullif(btrim(p_stage), '');
begin
  if requested_stage is null then return null; end if;
  if lower(requested_stage) in ('harvest ready', 'first harvest') then
    select c.crop_profile_key into profile_key from public.crops c where c.id = p_crop_id;
    if profile_key is null then return 10000; end if;
    select coalesce(max(s.ordinality)::integer, 0) + 1 into last_stage_order
      from public.crop_profiles p, jsonb_array_elements(p.stage_plan) with ordinality as s(value, ordinality)
      where p.profile_key = profile_key;
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

create or replace function public.prevent_crop_growth_regression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_order integer;
  next_order integer;
begin
  if new.growth_stage is not distinct from old.growth_stage then return new; end if;
  previous_order := public.crop_growth_stage_order(old.id, old.growth_stage);
  next_order := public.crop_growth_stage_order(new.id, new.growth_stage);

  if next_order is null then
    raise exception 'Growth stage must be configured for this crop.';
  end if;
  if previous_order is not null and next_order < previous_order then
    raise exception 'Growth stage cannot move backward from % to %.', old.growth_stage, new.growth_stage;
  end if;
  return new;
end;
$$;

drop trigger if exists crops_prevent_growth_regression on public.crops;
create trigger crops_prevent_growth_regression
before update of growth_stage on public.crops
for each row execute function public.prevent_crop_growth_regression();

revoke all on function public.crop_growth_stage_order(uuid, text) from public;
revoke all on function public.prevent_crop_growth_regression() from public;

commit;
