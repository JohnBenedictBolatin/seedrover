-- Replace the ambiguous Farm Staff role with responsibility-specific staff roles.
insert into public.roles (role_name, description)
values
  ('Planting Staff', 'Planting operations staff with the same operational access as the Farm Planting Manager.'),
  ('Inventory Staff', 'Inventory operations staff with the same operational access as the Farm Inventory Manager.')
on conflict (role_name) do update set description = excluded.description;

-- Existing generic staff with any inventory permission become Inventory Staff.
-- Remaining generic staff become Planting Staff so no account is left on an
-- unsupported role. Administrators can switch the role afterward if needed.
update public.profiles profile
set role_id = case
  when exists (
    select 1
    from public.profile_permissions profile_permission
    join public.permissions permission on permission.id = profile_permission.permission_id
    where profile_permission.profile_id = profile.id
      and permission.permission_key like 'stocks.%'
  ) then (select id from public.roles where role_name = 'Inventory Staff')
  else (select id from public.roles where role_name = 'Planting Staff')
end
where profile.role_id = (select id from public.roles where role_name = 'Farm Staff');

delete from public.roles where role_name = 'Farm Staff';

alter table public.activity_logs
  drop constraint if exists activity_logs_module_allowed;
alter table public.activity_logs
  add constraint activity_logs_module_allowed check (
    module in (
      'Authentication', 'Dashboard', 'Rover', 'Rover Monitor', 'Planting',
      'Crops', 'Inventory', 'Stocks', 'Sales', 'Customers', 'Discounts',
      'Reports', 'Notifications', 'Profile', 'Users', 'System'
    )
  );

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  default_staff_role_id uuid;
begin
  select id into default_staff_role_id
  from public.roles
  where role_name = 'Planting Staff'
  limit 1;

  insert into public.profiles (id, username, email, full_name, role_id)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'username', ''), 'user_' || replace(left(new.id::text, 8), '-', '')),
    coalesce(new.email, ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'SeedRover User'),
    default_staff_role_id
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.has_permission(requested_permission text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  with current_user_context as (
    select profile.id, role.role_name
    from public.profiles profile
    join public.roles role on role.id = profile.role_id
    where profile.id = auth.uid() and profile.is_active
    limit 1
  )
  select exists (
    select 1
    from current_user_context context
    where context.role_name = 'System Administrator'
      or (
        context.role_name in ('Farm Planting Manager', 'Planting Staff')
        and requested_permission = any(array[
          'dashboard.view', 'rover.view', 'rover.control', 'rover.camera.view',
          'rover.planting.control', 'crops.view', 'crops.manage',
          'notifications.view', 'profile.view', 'profile.manage_self'
        ])
      )
      or (
        context.role_name in ('Farm Inventory Manager', 'Inventory Staff')
        and requested_permission = any(array[
          'dashboard.view', 'stocks.view', 'stocks.manage',
          'stocks.transactions.view', 'stocks.sales.record',
          'stocks.pricing.manage', 'notifications.view', 'profile.view',
          'profile.manage_self'
        ])
      )
      or requested_permission = any(array['profile.view', 'profile.manage_self'])
      or exists (
        select 1
        from public.profile_permissions profile_permission
        join public.permissions permission on permission.id = profile_permission.permission_id
        where profile_permission.profile_id = context.id
          and permission.permission_key = requested_permission
      )
  );
$$;

drop policy if exists sales_transactions_update_allowed on public.sales_transactions;
create policy sales_transactions_update_allowed
  on public.sales_transactions for update to authenticated
  using (public.is_admin() or public.current_user_role_name() in ('Farm Inventory Manager', 'Inventory Staff'))
  with check (public.is_admin() or public.current_user_role_name() in ('Farm Inventory Manager', 'Inventory Staff'));

drop policy if exists sales_orders_update_allowed on public.sales_orders;
create policy sales_orders_update_allowed
  on public.sales_orders for update to authenticated
  using (public.is_admin() or public.current_user_role_name() in ('Farm Inventory Manager', 'Inventory Staff'))
  with check (public.is_admin() or public.current_user_role_name() in ('Farm Inventory Manager', 'Inventory Staff'));

drop policy if exists crops_insert_manager_manual_only on public.crops;
create policy crops_insert_manager_manual_only
  on public.crops for insert to authenticated
  with check (
    planting_source = 'Manual'
    and nullif(btrim(manual_creation_reason), '') is not null
    and assigned_manager = auth.uid()
    and public.current_user_role_name() in ('Farm Planting Manager', 'Planting Staff')
  );

-- All staff activity alerts the system administrators and the manager for the
-- staff member's responsibility. Manager/admin activity retains the existing
-- administrator audit notification behavior.
create or replace function public.notify_admin_on_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role text;
  related_route text;
  related_type text;
begin
  select role.role_name
  into actor_role
  from public.profiles profile
  join public.roles role on role.id = profile.role_id
  where profile.id = new.user_id;

  related_route := case
    when new.module in ('Crops', 'Planting', 'Rover') then '/crops'
    when new.module in ('Inventory', 'Stocks', 'Sales', 'Customers') then '/inventory'
    else '/activity-log'
  end;
  related_type := case
    when new.module in ('Crops', 'Planting', 'Rover') then 'Crop Reminder'
    when new.module in ('Inventory', 'Stocks', 'Sales', 'Customers') then 'Inventory'
    else 'System'
  end;

  insert into public.notifications (
    recipient_id,
    title,
    message,
    notification_type,
    action_route
  )
  select recipient.id,
    new.activity,
    coalesce(new.description, 'A new activity was recorded in SeedRover.'),
    related_type,
    related_route
  from public.profiles recipient
  join public.roles recipient_role on recipient_role.id = recipient.role_id
  where recipient.is_active
    and (recipient.id is distinct from new.user_id or actor_role = 'System Administrator')
    and (
      recipient_role.role_name = 'System Administrator'
      or (actor_role = 'Planting Staff' and recipient_role.role_name = 'Farm Planting Manager')
      or (actor_role = 'Inventory Staff' and recipient_role.role_name = 'Farm Inventory Manager')
    );

  return new;
end;
$$;
