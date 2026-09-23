-- Notifications must be relevant to the recipient and must never notify the
-- user whose action produced the event.
alter table public.notifications
  add column if not exists actor_id uuid references public.profiles(id) on delete set null;

create index if not exists notifications_actor_id_idx
  on public.notifications(actor_id);

create or replace function public.prevent_self_notification()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  effective_actor uuid := coalesce(new.actor_id, auth.uid());
begin
  if effective_actor is not null and new.recipient_id = effective_actor then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_prevent_self on public.notifications;
create trigger notifications_prevent_self
  before insert or update of recipient_id, actor_id on public.notifications
  for each row execute function public.prevent_self_notification();

drop policy if exists notifications_select_own_or_admin on public.notifications;
create policy notifications_select_own_or_admin
  on public.notifications for select to authenticated
  using (
    actor_id is distinct from auth.uid()
    and (public.is_admin() or recipient_id = auth.uid())
  );

drop policy if exists notifications_update_own_or_admin on public.notifications;
create policy notifications_update_own_or_admin
  on public.notifications for update to authenticated
  using (
    actor_id is distinct from auth.uid()
    and (public.is_admin() or recipient_id = auth.uid())
  )
  with check (
    actor_id is distinct from auth.uid()
    and (public.is_admin() or recipient_id = auth.uid())
  );

create or replace function public.notify_admin_on_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role text;
  domain text;
  related_route text;
  related_type text;
  is_harvest_event boolean;
begin
  select role.role_name
    into actor_role
    from public.profiles profile
    join public.roles role on role.id = profile.role_id
   where profile.id = new.user_id;

  domain := case
    when new.module in ('Crops', 'Planting', 'Rover', 'Rover Monitor') then 'planting'
    when new.module in ('Inventory', 'Stocks', 'Sales', 'Customers', 'Discounts') then 'inventory'
    else 'system'
  end;
  is_harvest_event := domain = 'planting' and (
    lower(coalesce(new.activity, '')) like '%harvest%'
    or lower(coalesce(new.description, '')) like '%harvest%'
  );
  related_route := case
    when is_harvest_event then '/inventory'
    when domain = 'planting' then '/crops'
    when domain = 'inventory' then '/inventory'
    else '/activity-log'
  end;
  related_type := case
    when is_harvest_event then 'Inventory'
    when domain = 'planting' then 'Crop Reminder'
    when domain = 'inventory' then 'Inventory'
    else 'System'
  end;

  insert into public.notifications (
    recipient_id, actor_id, title, message, notification_type, action_route
  )
  select
    recipient.id,
    new.user_id,
    new.activity,
    coalesce(new.description, 'A new activity was recorded in SeedRover.'),
    related_type,
    related_route
  from public.profiles recipient
  join public.roles recipient_role on recipient_role.id = recipient.role_id
  where recipient.is_active
    and recipient.id is distinct from new.user_id
    and (
      -- Administrators receive every event performed by somebody else.
      recipient_role.role_name = 'System Administrator'
      -- Managers receive activity performed by staff in their responsibility.
      or (
        actor_role = 'Planting Staff'
        and domain = 'planting'
        and recipient_role.role_name = 'Farm Planting Manager'
      )
      or (
        actor_role = 'Inventory Staff'
        and domain = 'inventory'
        and recipient_role.role_name = 'Farm Inventory Manager'
      )
      -- Harvest receipts concern both inventory roles.
      or (
        is_harvest_event
        and recipient_role.role_name in ('Farm Inventory Manager', 'Inventory Staff')
      )
      -- Hardware/system planting events without a user concern planting roles.
      or (
        new.user_id is null
        and domain = 'planting'
        and recipient_role.role_name in ('Farm Planting Manager', 'Planting Staff')
      )
      -- Automated inventory events concern inventory roles.
      or (
        new.user_id is null
        and domain = 'inventory'
        and recipient_role.role_name in ('Farm Inventory Manager', 'Inventory Staff')
      )
    );

  return new;
end;
$$;

drop trigger if exists activity_logs_notify_admin on public.activity_logs;
create trigger activity_logs_notify_admin
  after insert on public.activity_logs
  for each row execute function public.notify_admin_on_activity();

-- Keep legacy callers safe: a direct alert addressed to the current actor is
-- ignored instead of appearing in that actor's notification list.
create or replace function public.safe_notification(
  p_recipient_id uuid,
  p_title text,
  p_message text,
  p_notification_type text,
  p_action_route text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_recipient_id is null or p_recipient_id = auth.uid() then return; end if;
  insert into public.notifications (
    recipient_id, actor_id, title, message, notification_type, action_route
  ) values (
    p_recipient_id, auth.uid(), p_title, p_message, p_notification_type,
    p_action_route
  );
exception
  when others then null;
end;
$$;
