create or replace function public.prevent_duplicate_sale_transaction_reference()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_reference text := nullif(upper(btrim(coalesce(new.transaction_reference, ''))), '');
begin
  if normalized_reference is null then
    return new;
  end if;

  -- Serialize the same payment reference across both the current receipt
  -- workflow and legacy single-item sale records.
  perform pg_advisory_xact_lock(
    hashtextextended('sale_transaction_reference:' || normalized_reference, 0)
  );

  if tg_table_name = 'sales_orders' then
    if exists (
      select 1
      from public.sales_orders existing
      where existing.id <> new.id
        and nullif(upper(btrim(coalesce(existing.transaction_reference, ''))), '') = normalized_reference
    ) or exists (
      select 1
      from public.sales_transactions existing
      where nullif(upper(btrim(coalesce(existing.transaction_reference, ''))), '') = normalized_reference
    ) then
      raise exception 'Transaction ID has already been used for another sale.'
        using errcode = '23505';
    end if;
  elsif tg_table_name = 'sales_transactions' then
    if exists (
      select 1
      from public.sales_transactions existing
      where existing.id <> new.id
        and nullif(upper(btrim(coalesce(existing.transaction_reference, ''))), '') = normalized_reference
    ) or exists (
      select 1
      from public.sales_orders existing
      where nullif(upper(btrim(coalesce(existing.transaction_reference, ''))), '') = normalized_reference
    ) then
      raise exception 'Transaction ID has already been used for another sale.'
        using errcode = '23505';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists sales_orders_unique_transaction_reference on public.sales_orders;
create trigger sales_orders_unique_transaction_reference
before insert or update of transaction_reference on public.sales_orders
for each row execute function public.prevent_duplicate_sale_transaction_reference();

drop trigger if exists sales_transactions_unique_transaction_reference on public.sales_transactions;
create trigger sales_transactions_unique_transaction_reference
before insert or update of transaction_reference on public.sales_transactions
for each row execute function public.prevent_duplicate_sale_transaction_reference();

revoke all on function public.prevent_duplicate_sale_transaction_reference() from public, anon, authenticated;
