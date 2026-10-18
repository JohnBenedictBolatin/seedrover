begin;

select plan(4);

select ok(
  (select allowed from public.consume_assistant_rate_limit(repeat('a', 64), 2, 60)),
  'the first assistant request is allowed'
);

select ok(
  (select remaining = 0 from public.consume_assistant_rate_limit(repeat('a', 64), 2, 60)),
  'the limit reports no remaining requests after the second request'
);

select ok(
  not (select allowed from public.consume_assistant_rate_limit(repeat('a', 64), 2, 60)),
  'requests beyond the limit are rejected atomically'
);

select ok(
  not has_function_privilege('authenticated', 'public.consume_assistant_rate_limit(text,integer,integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.consume_assistant_rate_limit(text,integer,integer)', 'EXECUTE'),
  'the rate-limit helper cannot be called by app users'
);

select * from finish();
rollback;
