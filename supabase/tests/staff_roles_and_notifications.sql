begin;

select plan(10);

select is(
  (select count(*)::integer from public.roles where role_name in ('Planting Staff', 'Inventory Staff')),
  2,
  'both responsibility-specific staff roles exist'
);

select is(
  (select count(*)::integer from public.roles where role_name = 'Farm Staff'),
  0,
  'generic Farm Staff role no longer exists'
);

select has_function('public'::name, 'has_permission'::name, array['text']::name[]);
select has_function('public'::name, 'notify_admin_on_activity'::name);

select function_returns('public'::name, 'has_permission'::name, array['text']::name[], 'boolean');
select trigger_is(
  'public',
  'activity_logs',
  'activity_logs_notify_admin',
  'public',
  'notify_admin_on_activity',
  'activity log inserts route notifications through the role-aware notifier'
);

select has_column('public'::name, 'notifications'::name, 'actor_id'::name, 'notifications retain the actor');
select has_function('public'::name, 'prevent_self_notification'::name);
select trigger_is(
  'public',
  'notifications',
  'notifications_prevent_self',
  'public',
  'prevent_self_notification',
  'notification inserts are guarded against self-notification'
);
select has_function(
  'public'::name,
  'safe_notification'::name,
  array['uuid', 'text', 'text', 'text', 'text']::name[]
);

select * from finish();
rollback;
