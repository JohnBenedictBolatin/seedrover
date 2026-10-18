begin;

select plan(6);

select ok(
  to_regprocedure('public.get_crop_activity_summaries(uuid[],timestamp with time zone,timestamp with time zone)') is not null,
  'crop overviews can read aggregated activity without downloading history'
);
select ok(
  has_function_privilege('authenticated', 'public.get_crop_activity_summaries(uuid[],timestamp with time zone,timestamp with time zone)', 'EXECUTE'),
  'crop viewers can read activity summaries'
);
select ok(
  not has_function_privilege('anon', 'public.get_crop_activity_summaries(uuid[],timestamp with time zone,timestamp with time zone)', 'EXECUTE'),
  'anonymous sessions cannot read crop activity summaries'
);
select throws_ok(
  $$select * from public.get_crop_activity_summaries(array[]::uuid[], now(), now())$$,
  'P0001',
  'Crop viewing permission required.',
  'the summary function enforces authenticated crop permissions'
);
select ok(
  has_function_privilege('service_role', 'public.get_crop_monitor_inputs(uuid[],timestamp with time zone,timestamp with time zone)', 'EXECUTE'),
  'the crop monitor can read its aggregated inputs'
);
select throws_ok(
  $$select * from public.get_crop_monitor_inputs(array[]::uuid[], now() - interval '1 day', now())$$,
  'P0001',
  'Crop monitoring service access is required.',
  'app and anonymous sessions cannot read internal crop monitor inputs'
);

select * from finish();
rollback;
