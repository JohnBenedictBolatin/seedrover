begin;

select plan(4);

select has_trigger(
  'public',
  'planting_logs',
  'planting_logs_normalize_rover_temperatures',
  'rover planting-log writes normalize the legacy environmental temperature field'
);
select ok(
  position('new.client_session_id is not null' in pg_get_functiondef('public.normalize_rover_planting_temperatures()'::regprocedure)) > 0,
  'temperature normalization is limited to synced rover sessions'
);
select ok(
  position('new.air_temperature_c' in pg_get_functiondef('public.normalize_rover_planting_temperatures()'::regprocedure)) > 0
    and position('status,air_temperature_c' in pg_get_functiondef('public.normalize_rover_planting_temperatures()'::regprocedure)) > 0,
  'environmental temperature comes from the air-temperature value, including payload fallback'
);
select ok(
  position('new.air_temperature_c is distinct from old.air_temperature_c' in pg_get_functiondef('public.normalize_rover_planting_temperatures()'::regprocedure)) > 0,
  'unrelated updates do not overwrite the previously stored environmental temperature'
);

select * from finish();
rollback;
