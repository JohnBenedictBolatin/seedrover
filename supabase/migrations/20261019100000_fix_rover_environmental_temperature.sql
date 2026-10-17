-- Guided rover sync has separate soil and air temperature values. Keep the
-- legacy environmental_temperature column aligned with the measured air value.
-- This applies only to synced rover sessions; manual readings retain their
-- existing behavior.
create or replace function public.normalize_rover_planting_temperatures()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.client_session_id is not null then
      new.environmental_temperature := coalesce(
        new.air_temperature_c,
        nullif(new.sync_payload #>> '{status,air_temperature_c}', '')::numeric
      );
    end if;
  elsif new.client_session_id is not null
        and new.air_temperature_c is distinct from old.air_temperature_c then
    new.environmental_temperature := coalesce(
      new.air_temperature_c,
      nullif(new.sync_payload #>> '{status,air_temperature_c}', '')::numeric
    );
  end if;
  return new;
end;
$$;

drop trigger if exists planting_logs_normalize_rover_temperatures on public.planting_logs;
create trigger planting_logs_normalize_rover_temperatures
before insert or update on public.planting_logs
for each row
execute function public.normalize_rover_planting_temperatures();

revoke all on function public.normalize_rover_planting_temperatures() from public;
