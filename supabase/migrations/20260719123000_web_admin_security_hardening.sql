create table if not exists public.rate_limit_buckets (
  key text primary key,
  count integer not null default 0,
  reset_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.rate_limit_buckets enable row level security;

drop trigger if exists rate_limit_buckets_set_updated_at on public.rate_limit_buckets;
create trigger rate_limit_buckets_set_updated_at
  before update on public.rate_limit_buckets
  for each row execute function public.set_updated_at();

revoke all on public.rate_limit_buckets from anon, authenticated;
grant all on public.rate_limit_buckets to service_role;

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if new.username is distinct from old.username then
    raise exception 'Only administrators can change usernames.';
  end if;

  if new.email is distinct from old.email then
    raise exception 'Only administrators can change account emails.';
  end if;

  if new.role_id is distinct from old.role_id then
    raise exception 'Only administrators can change user roles.';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'Only administrators can change account status.';
  end if;

  return new;
end;
$$;

drop policy if exists profiles_update_own_or_admin on public.profiles;

create policy profiles_update_own_safe_or_admin
  on public.profiles
  for update
  to authenticated
  using (
    public.is_admin()
    or (
      id = auth.uid()
      and public.has_permission('profile.manage_self')
    )
  )
  with check (
    public.is_admin()
    or (
      id = auth.uid()
      and public.has_permission('profile.manage_self')
    )
  );

revoke update on public.profiles from authenticated;
grant update (
  full_name,
  role_id,
  is_active,
  profile_image_path,
  updated_at
) on public.profiles to authenticated;

revoke update on public.sales_order_items from authenticated;
revoke insert on public.sales_order_items from authenticated;
revoke delete on public.sales_order_items from authenticated;

revoke update on public.sales_orders from authenticated;
revoke insert on public.sales_orders from authenticated;
revoke delete on public.sales_orders from authenticated;
grant update (
  status,
  voided_at,
  voided_by,
  void_reason,
  updated_at
) on public.sales_orders to authenticated;

revoke update on public.sales_transactions from authenticated;
revoke insert on public.sales_transactions from authenticated;
revoke delete on public.sales_transactions from authenticated;
grant update (
  status,
  voided_at,
  voided_by,
  void_reason,
  updated_at
) on public.sales_transactions to authenticated;

revoke update on public.customer_discounts from authenticated;
grant update (
  status,
  used_at,
  used_by,
  used_sales_order_id,
  updated_at
) on public.customer_discounts to authenticated;

alter table public.sales_orders
  drop constraint if exists sales_orders_status_allowed,
  add constraint sales_orders_status_allowed check (status in ('Completed', 'Voided'));

alter table public.sales_transactions
  drop constraint if exists sales_transactions_status_allowed,
  add constraint sales_transactions_status_allowed check (status in ('Completed', 'Voided'));

alter table public.customer_discounts
  drop constraint if exists customer_discounts_status_allowed,
  add constraint customer_discounts_status_allowed check (status in ('Released', 'Used', 'Voided'));
