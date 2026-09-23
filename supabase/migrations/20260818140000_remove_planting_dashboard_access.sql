-- Planting roles work directly from Crops and Rover and do not use Dashboard.
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
          'rover.view', 'rover.control', 'rover.camera.view',
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
      or (
        context.role_name not in ('Farm Planting Manager', 'Planting Staff')
        and exists (
          select 1
          from public.profile_permissions profile_permission
          join public.permissions permission on permission.id = profile_permission.permission_id
          where profile_permission.profile_id = context.id
            and permission.permission_key = requested_permission
        )
      )
  );
$$;

-- Remove any legacy per-user override that would restore Dashboard to planting roles.
delete from public.profile_permissions profile_permission
using public.profiles profile, public.roles role, public.permissions permission
where profile_permission.profile_id = profile.id
  and profile.role_id = role.id
  and profile_permission.permission_id = permission.id
  and role.role_name in ('Farm Planting Manager', 'Planting Staff')
  and permission.permission_key = 'dashboard.view';

