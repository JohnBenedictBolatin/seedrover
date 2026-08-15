-- System administrators should receive notifications for their own actions too.
create or replace function public.notify_admin_on_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, title, message, notification_type, action_route)
  select p.id,
    new.activity,
    coalesce(new.description, 'A new activity was recorded in SeedRover.'),
    case when new.module in ('Crops', 'Planting') then 'Crop Reminder' else 'System' end,
    case when new.module in ('Crops', 'Planting') then '/crops' else '/activity-log' end
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.is_active and r.role_name = 'System Administrator';
  return new;
end;
$$;
