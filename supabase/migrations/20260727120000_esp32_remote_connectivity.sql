-- Phase 1 ESP32 connectivity: one rover, one control lease, PING only.
alter table public.robot_commands
  add column if not exists rover_id text not null default 'seedrover-01',
  add column if not exists correlation_id uuid not null default gen_random_uuid(),
  add column if not exists expires_at timestamptz,
  add column if not exists acknowledged_at timestamptz,
  add column if not exists failure_details text;

create unique index if not exists robot_commands_correlation_id_idx
  on public.robot_commands(correlation_id);
create index if not exists robot_commands_rover_pending_idx
  on public.robot_commands(rover_id, status, created_at);

create table if not exists public.rover_control_leases (
  rover_id text primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  acquired_at timestamptz not null default now(),
  renewed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint rover_control_leases_future_expiry check (expires_at > acquired_at)
);

alter table public.rover_control_leases enable row level security;

create policy rover_control_leases_select_allowed
  on public.rover_control_leases for select to authenticated
  using (public.has_permission('rover.view') or public.has_permission('rover.control'));

create or replace function public.acquire_rover_control_lease(
  target_rover_id text default 'seedrover-01',
  lease_seconds integer default 30
)
returns public.rover_control_leases
language plpgsql security definer set search_path = public
as $$
declare result public.rover_control_leases;
begin
  if not public.has_permission('rover.control') then
    raise exception 'rover.control permission required';
  end if;
  if lease_seconds < 10 or lease_seconds > 120 then
    raise exception 'lease_seconds must be between 10 and 120';
  end if;
  insert into public.rover_control_leases(rover_id, owner_id, expires_at)
  values (target_rover_id, auth.uid(), now() + make_interval(secs => lease_seconds))
  on conflict (rover_id) do update set
    owner_id = excluded.owner_id,
    acquired_at = case when rover_control_leases.owner_id = auth.uid()
      then rover_control_leases.acquired_at else now() end,
    renewed_at = now(),
    expires_at = excluded.expires_at
  where rover_control_leases.owner_id = auth.uid()
     or rover_control_leases.expires_at <= now()
  returning * into result;
  if result.rover_id is null then raise exception 'rover is controlled by another operator'; end if;
  return result;
end;
$$;

create or replace function public.release_rover_control_lease(
  target_rover_id text default 'seedrover-01'
) returns boolean language sql security definer set search_path = public
as $$
  with deleted as (
    delete from public.rover_control_leases
    where rover_id = target_rover_id and owner_id = auth.uid()
    returning 1
  ) select exists(select 1 from deleted);
$$;

revoke all on function public.acquire_rover_control_lease(text, integer) from public;
revoke all on function public.release_rover_control_lease(text) from public;
grant execute on function public.acquire_rover_control_lease(text, integer) to authenticated;
grant execute on function public.release_rover_control_lease(text) to authenticated;

alter publication supabase_realtime add table public.rover_control_leases;

