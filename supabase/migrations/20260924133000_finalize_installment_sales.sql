-- Normalize installment sales through a security-definer function because
-- authenticated clients are not allowed to update sales_orders directly.
create or replace function public.finalize_installment_sale(
  p_id uuid,
  p_amount_paid numeric default null
)
returns public.sales_orders
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in before finalizing an installment sale.';
  end if;

  if not public.has_permission('stocks.sales.record')
    and not public.has_permission('stocks.manage') then
    raise exception 'Not allowed to finalize installment sales.';
  end if;

  if p_amount_paid is not null and p_amount_paid < 0 then
    raise exception 'Amount paid cannot be negative.';
  end if;

  update public.sales_orders
  set payment_method = 'Installment',
      other_payment_method = null,
      transaction_reference = null,
      amount_paid = p_amount_paid,
      change_amount = null
  where id = p_id
  returning * into order_row;

  if not found then
    raise exception 'The sale could not be found while saving installment details.';
  end if;

  return order_row;
end;
$$;

revoke all on function public.finalize_installment_sale(uuid, numeric) from public;
grant execute on function public.finalize_installment_sale(uuid, numeric) to authenticated;

-- Ask PostgREST to refresh its exposed function cache after the migration.
notify pgrst, 'reload schema';
