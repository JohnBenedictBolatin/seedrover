-- Staff use their responsibility-specific workspaces, not the dashboard.
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
        context.role_name = 'Farm Inventory Manager'
        and requested_permission = any(array[
          'dashboard.view', 'stocks.view', 'stocks.manage',
          'stocks.transactions.view', 'stocks.sales.record',
          'stocks.pricing.manage', 'notifications.view', 'profile.view',
          'profile.manage_self'
        ])
      )
      or (
        context.role_name = 'Inventory Staff'
        and requested_permission = any(array[
          'stocks.view', 'stocks.manage', 'stocks.transactions.view',
          'stocks.sales.record', 'stocks.pricing.manage', 'notifications.view',
          'profile.view', 'profile.manage_self'
        ])
      )
      or requested_permission = any(array['profile.view', 'profile.manage_self'])
      or (
        context.role_name not in ('Farm Planting Manager', 'Planting Staff')
        and not (
          context.role_name = 'Inventory Staff'
          and requested_permission = 'dashboard.view'
        )
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

-- Remove dashboard overrides from existing staff profiles too.
delete from public.profile_permissions profile_permission
using public.profiles profile, public.roles role, public.permissions permission
where profile_permission.profile_id = profile.id
  and profile.role_id = role.id
  and profile_permission.permission_id = permission.id
  and role.role_name in ('Planting Staff', 'Inventory Staff')
  and permission.permission_key = 'dashboard.view';

-- Staff may record sales, but only managers and admins may update sale rows.
drop policy if exists sales_orders_update_allowed on public.sales_orders;
create policy sales_orders_update_allowed
  on public.sales_orders
  for update
  to authenticated
  using (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  )
  with check (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  );

drop policy if exists sales_transactions_update_allowed on public.sales_transactions;
create policy sales_transactions_update_allowed
  on public.sales_transactions
  for update
  to authenticated
  using (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  )
  with check (
    public.is_admin()
    or public.current_user_role_name() = 'Farm Inventory Manager'
  );

-- Keep the existing void workflow intact, but make it private behind an exact-role wrapper.
alter function public.void_sales_record(uuid, text, text)
  rename to void_sales_record_internal;

revoke all on function public.void_sales_record_internal(uuid, text, text)
  from public, anon, authenticated;

-- The server may need to undo a just-created sale if installment setup fails.
-- Keep this compensation path service-role-only and verify it is an unplanned
-- receipt created by the same inventory user before invoking the private void.
create function public.rollback_failed_installment_sale(
  p_id uuid,
  p_actor_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  receipt_row public.sales_orders%rowtype;
  actor_role text;
begin
  select role.role_name
  into actor_role
  from public.profiles profile
  join public.roles role on role.id = profile.role_id
  where profile.id = p_actor_id and profile.is_active;

  if coalesce(actor_role, '') not in (
    'System Administrator', 'Farm Inventory Manager', 'Inventory Staff'
  ) then
    raise exception 'The sale creator is not authorized to record inventory sales.';
  end if;

  select *
  into receipt_row
  from public.sales_orders
  where id = p_id
  for update;

  if not found
    or receipt_row.recorded_by <> p_actor_id
    or receipt_row.status <> 'Completed'
    or receipt_row.payment_method <> 'Cash'
    or exists (
      select 1 from public.installment_plans
      where sales_order_id = p_id
    ) then
    raise exception 'The receipt is not eligible for installment setup rollback.';
  end if;

  perform set_config('request.jwt.claim.sub', p_actor_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  return public.void_sales_record_internal(
    p_id,
    'receipt',
    coalesce(nullif(trim(p_reason), ''), 'Installment schedule creation failed; receipt rolled back.')
  );
end;
$$;

revoke all on function public.rollback_failed_installment_sale(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.rollback_failed_installment_sale(uuid, uuid, text)
  to service_role;

create function public.void_sales_record(
  p_id uuid,
  p_source text,
  p_reason text default 'Voided from SeedRover.'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if coalesce(public.current_user_role_name(), '') not in (
    'System Administrator', 'Farm Inventory Manager'
  ) then
    raise exception 'Only an administrator or inventory manager can void sales.';
  end if;

  return public.void_sales_record_internal(p_id, p_source, p_reason);
end;
$$;

revoke all on function public.void_sales_record(uuid, text, text)
  from public, anon;
grant execute on function public.void_sales_record(uuid, text, text)
  to authenticated;
