-- Crop records are authoritative planting results from SeedRover hardware.
-- Existing records are retained, but all future inserts must be linked to a
-- planting log produced by record_rover_planting_session().

drop policy if exists crops_insert_manager_manual_only on public.crops;
drop policy if exists crops_insert_allowed on public.crops;

drop trigger if exists crops_audit_manual_creation on public.crops;
drop function if exists public.audit_manual_crop_creation();

create or replace function public.enforce_rover_crop_creation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.planting_source <> 'Rover' or new.planting_log_id is null then
    raise exception 'Crop records must originate from a SeedRover planting receipt.';
  end if;

  return new;
end;
$$;

drop trigger if exists crops_enforce_rover_creation on public.crops;
create trigger crops_enforce_rover_creation
  before insert on public.crops
  for each row execute function public.enforce_rover_crop_creation();
