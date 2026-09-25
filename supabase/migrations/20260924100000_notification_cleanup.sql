-- Authentication and notification-maintenance activity is audit history, not
-- user-facing notification content.
delete from public.notifications
where lower(title) in (
    'login',
    'logout',
    'web login',
    'web logout',
    'notification read',
    'notification deleted'
  )
   or lower(message) like '%signed in%'
   or lower(message) like '%signed out%';

-- Keep those events in activity_logs for audit purposes, but do not turn them
-- into notification cards. Notification read/delete events are also noise.
drop trigger if exists activity_logs_notify_admin on public.activity_logs;
create trigger activity_logs_notify_admin
  after insert on public.activity_logs
  for each row
  when (new.module not in ('Authentication', 'Notifications'))
  execute function public.notify_admin_on_activity();
