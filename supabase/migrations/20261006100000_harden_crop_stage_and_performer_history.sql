create or replace function public.prevent_crop_growth_stage_regression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  previous_rank bigint;
  requested_rank bigint;
begin
  if new.growth_stage is not distinct from old.growth_stage then
    return new;
  end if;

  select case old.growth_stage
    when 'Harvest Ready' then 100000
    when 'Repeated Harvest' then 100001
    when 'Completed' then 100002
    else (
      select stage.ordinality
      from public.crop_profiles profile,
           jsonb_array_elements(profile.stage_plan) with ordinality as stage(value, ordinality)
      where profile.profile_key = old.crop_profile_key
        and stage.value->>'stage' = old.growth_stage
      limit 1
    )
  end into previous_rank;

  select case new.growth_stage
    when 'Harvest Ready' then 100000
    when 'Repeated Harvest' then 100001
    when 'Completed' then 100002
    else (
      select stage.ordinality
      from public.crop_profiles profile,
           jsonb_array_elements(profile.stage_plan) with ordinality as stage(value, ordinality)
      where profile.profile_key = new.crop_profile_key
        and stage.value->>'stage' = new.growth_stage
      limit 1
    )
  end into requested_rank;

  if previous_rank is not null and requested_rank is not null and requested_rank < previous_rank then
    new.growth_stage := old.growth_stage;
  end if;
  return new;
end;
$$;

drop trigger if exists crops_prevent_growth_stage_regression on public.crops;
create trigger crops_prevent_growth_stage_regression
before update of growth_stage on public.crops
for each row execute function public.prevent_crop_growth_stage_regression();

create or replace function public.crop_performer_names(p_performer_ids uuid[])
returns table (performer_id uuid, full_name text)
language sql
stable
security definer
set search_path = public
as $$
  select profile.id,
         coalesce(
           nullif(btrim(profile.full_name), ''),
           nullif(concat_ws(' ', nullif(btrim(profile.first_name), ''), nullif(btrim(profile.last_name), '')), '')
         )
  from public.profiles profile
  where profile.id = any(coalesce(p_performer_ids, '{}'::uuid[]))
    and (
      (
        public.has_permission('crops.view')
        and exists (
        select 1 from public.crop_activities activity
        join public.crops crop on crop.id = activity.crop_id
        where activity.performed_by = profile.id
        )
      )
      or (
        (public.is_admin() or public.current_user_role_name() = 'Farm Planting Manager')
        and exists (
        select 1 from public.crop_outcomes outcome
        where outcome.recorded_by = profile.id
        )
      )
    );
$$;

revoke all on function public.crop_performer_names(uuid[]) from public, anon;
grant execute on function public.crop_performer_names(uuid[]) to authenticated;
