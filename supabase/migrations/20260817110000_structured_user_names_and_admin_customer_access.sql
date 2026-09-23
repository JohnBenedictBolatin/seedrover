alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists middle_initial text;

-- Backfill the structured fields from existing full names without destroying legacy data.
update public.profiles
set first_name = coalesce(first_name, split_part(trim(full_name), ' ', 1)),
    last_name = coalesce(last_name, nullif(trim(regexp_replace(trim(full_name), '^\\S+\\s*', '')), ''))
where first_name is null or last_name is null;

drop policy if exists customers_select_allowed on public.customers;
create policy customers_select_allowed on public.customers for select to authenticated
using (public.is_admin() or public.has_permission('stocks.view') or public.has_permission('stocks.transactions.view') or public.has_permission('stocks.sales.record') or public.has_permission('stocks.manage'));

drop policy if exists sales_orders_select_allowed on public.sales_orders;
create policy sales_orders_select_allowed on public.sales_orders for select to authenticated
using (public.is_admin() or public.has_permission('stocks.view') or public.has_permission('stocks.transactions.view'));

drop policy if exists sales_transactions_select_allowed on public.sales_transactions;
create policy sales_transactions_select_allowed on public.sales_transactions for select to authenticated
using (public.is_admin() or public.has_permission('stocks.view') or public.has_permission('stocks.transactions.view'));
