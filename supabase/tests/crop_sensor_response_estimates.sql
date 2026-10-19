begin;

select plan(7);

select has_function(
  'public'::name,
  'record_crop_sensor_estimate'::name,
  array['uuid', 'uuid', 'integer', 'numeric', 'numeric', 'numeric', 'timestamp with time zone', 'text']::name[],
  'crop sensor test estimates have a dedicated RPC'
);
select ok(
  (select prosecdef from pg_proc where oid = 'public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure),
  'the estimate RPC runs with its restricted security-definer checks'
);
select ok(
  position('crops.manage' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0,
  'the RPC requires crop-management permission'
);
select ok(
  position('crop_status not in' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0,
  'the RPC rejects readings for closed crops'
);
select ok(
  position('Estimated sensor response' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0
    and position('sensor-response-estimate-v1' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0,
  'saved responses are explicitly marked as test estimates'
);
select ok(
  position('pg_advisory_xact_lock' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0
    and position('different values' in pg_get_functiondef('public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)'::regprocedure)) > 0,
  'submission retries are serialized and changed payloads are rejected'
);
select ok(
  has_function_privilege('authenticated', 'public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)', 'EXECUTE')
    and not has_function_privilege('anon', 'public.record_crop_sensor_estimate(uuid,uuid,integer,numeric,numeric,numeric,timestamptz,text)', 'EXECUTE'),
  'only authenticated callers may invoke the permission-checked RPC'
);

select * from finish();
rollback;
