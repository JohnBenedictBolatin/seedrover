-- Retire installment sales, return their inventory, and remove their records.
-- Installment sale receipts are voided through the existing audited inventory
-- restoration workflow before their sales and payment records are deleted.
do $$
declare
  actor_id uuid;
  sale_row record;
  installment_plans_exist boolean := to_regclass('public.installment_plans') is not null;
  has_installment_sales boolean;
  has_completed_installment_sales boolean;
begin
  -- Some deployments may already have removed the installment tables while
  -- retaining installment sales. Keep those sales discoverable by payment
  -- method, and only query the plan table when it exists.
  if installment_plans_exist then
    execute $query$
      select exists (
        select 1
          from public.sales_orders sale
         where sale.payment_method = 'Installment'
            or sale.id in (select plan.sales_order_id from public.installment_plans plan)
      )
    $query$ into has_installment_sales;
    execute $query$
      select exists (
        select 1
          from public.sales_orders sale
         where sale.status = 'Completed'
           and (sale.payment_method = 'Installment'
             or sale.id in (select plan.sales_order_id from public.installment_plans plan))
      )
    $query$ into has_completed_installment_sales;
  else
    select exists (
      select 1 from public.sales_orders sale
       where sale.payment_method = 'Installment'
    ) into has_installment_sales;
    select exists (
      select 1 from public.sales_orders sale
       where sale.status = 'Completed'
         and sale.payment_method = 'Installment'
    ) into has_completed_installment_sales;
  end if;

  if has_installment_sales and has_completed_installment_sales then
    select profile.id
      into actor_id
      from public.profiles profile
      join public.roles role on role.id = profile.role_id
     where profile.is_active
       and role.role_name = 'System Administrator'
     order by profile.created_at
     limit 1;

    if actor_id is null then
      raise exception 'Installment sales cleanup requires an active System Administrator to restore inventory.';
    end if;

    perform set_config('request.jwt.claim.sub', actor_id::text, true);
    perform set_config('request.jwt.claim.role', 'authenticated', true);

    if installment_plans_exist then
      for sale_row in execute $query$
        select sale.id
          from public.sales_orders sale
         where sale.status = 'Completed'
           and (sale.payment_method = 'Installment'
             or sale.id in (select plan.sales_order_id from public.installment_plans plan))
         order by sale.id
      $query$ loop
        perform public.void_sales_record_internal(
          sale_row.id,
          'receipt',
          'Installment feature retired; sale removed and inventory restored.'
        );
      end loop;
    else
      for sale_row in
        select sale.id
          from public.sales_orders sale
         where sale.status = 'Completed'
           and sale.payment_method = 'Installment'
         order by sale.id
      loop
        perform public.void_sales_record_internal(
          sale_row.id,
          'receipt',
          'Installment feature retired; sale removed and inventory restored.'
        );
      end loop;
    end if;
  end if;
end;
$$;

-- Receipt files and their bucket are removed through the Supabase Storage API
-- before applying this migration. Remove the now-unused bucket policies here.
drop policy if exists installment_receipts_authenticated_select on storage.objects;
drop policy if exists installment_receipts_authenticated_insert on storage.objects;
drop policy if exists installment_receipts_authenticated_delete on storage.objects;

-- Reversals restrict receipt deletion, so clear collection rows before sales.
do $$
begin
  if to_regclass('public.installment_collection_reversals') is not null then
    execute 'delete from public.installment_collection_reversals';
  end if;
  if to_regclass('public.installment_payments') is not null then
    execute 'delete from public.installment_payments';
  end if;
  if to_regclass('public.installment_collections') is not null then
    execute 'delete from public.installment_collections';
  end if;
  if to_regclass('public.installment_sale_requests') is not null then
    execute 'delete from public.installment_sale_requests';
  end if;
end;
$$;

do $$
begin
  if to_regclass('public.installment_plans') is not null then
    execute $query$
      delete from public.sales_orders sale
       where sale.payment_method = 'Installment'
          or sale.id in (select plan.sales_order_id from public.installment_plans plan)
    $query$;
  else
    delete from public.sales_orders sale
     where sale.payment_method = 'Installment';
  end if;
end;
$$;

drop trigger if exists sales_orders_cancel_installment_plan on public.sales_orders;

drop function if exists public.cancel_installment_plan_on_void();
drop function if exists public.finalize_installment_sale(uuid, numeric);
drop function if exists public.create_installment_plan_with_details(uuid, text, integer, numeric, text, text);
drop function if exists public.create_installment_plan(uuid, text, numeric, numeric, text);
drop function if exists public.record_installment_payment(uuid, numeric, date, text, text, text, text);
drop function if exists public.record_installment_payment(uuid, numeric, date, text, text, text, text, text);
drop function if exists public.rollback_failed_installment_sale(uuid, uuid, text);
drop function if exists public.get_customer_active_installment(uuid, text);
drop function if exists public.record_installment_sale(uuid, uuid, text, text, text, integer, numeric, text, text, text, numeric, text, text, jsonb);
drop function if exists public.record_installment_collection(uuid, numeric, numeric, date, text, text, text, text, text, uuid);
drop function if exists public.reverse_installment_collection(uuid, text);
do $$
begin
  if to_regclass('public.installment_plans') is not null then
    execute 'drop trigger if exists installment_plans_single_active_customer on public.installment_plans';
  end if;
end;
$$;
drop function if exists public.guard_single_active_customer_installment();

drop table if exists public.installment_collection_reversals cascade;
drop table if exists public.installment_collections cascade;
drop table if exists public.installment_sale_requests cascade;
drop table if exists public.installment_payments cascade;
drop table if exists public.installment_schedule cascade;
drop table if exists public.installment_plans cascade;

alter table public.sales_orders
  drop constraint if exists sales_orders_payment_method_allowed;
alter table public.sales_orders
  add constraint sales_orders_payment_method_allowed
  check (payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Other'));

-- Keep the existing role-restricted sale void endpoint after retiring the guard
-- wrapper introduced alongside installment collection receipts.
create or replace function public.void_sales_record(
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

revoke all on function public.void_sales_record(uuid, text, text) from public, anon;
grant execute on function public.void_sales_record(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';
