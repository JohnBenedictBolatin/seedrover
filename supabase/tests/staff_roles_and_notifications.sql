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

select has_function('public', 'has_permission', array['text']);
select has_function('public', 'notify_admin_on_activity');

select function_returns('public', 'has_permission', array['text'], 'boolean');
select trigger_is(
  'public',
  'activity_logs',
  'activity_logs_notify_admin',
  'public',
  'notify_admin_on_activity',
  'activity log inserts route notifications through the role-aware notifier'
);

select has_column('public', 'notifications', 'actor_id');
select has_function('public', 'prevent_self_notification');
select trigger_is(
  'public',
  'notifications',
  'notifications_prevent_self',
  'public',
  'prevent_self_notification',
  'notification inserts are guarded against self-notification'
);
select has_function(
  'public',
  'safe_notification',
  array['uuid', 'text', 'text', 'text', 'text']
);

select * from finish();
rollback;
