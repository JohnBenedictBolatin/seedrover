create or replace function public.record_inventory_sale_receipt(
  p_inventory_id uuid,
  p_quantity_sold numeric,
  p_unit_price numeric,
  p_sale_date timestamptz,
  p_customer_name text,
  p_customer_contact text,
  p_remarks text,
  p_payment_method text,
  p_transaction_reference text,
  p_other_payment_method text
)
returns public.sales_orders
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  order_row public.sales_orders%rowtype;
begin
  if nullif(trim(coalesce(p_customer_contact, '')), '') is null then
    raise exception 'Customer contact is required.';
  end if;

  order_row := public.record_sales_order(
    p_customer_name,
    p_customer_contact,
    p_payment_method,
    'None',
    0,
    round(p_quantity_sold * p_unit_price, 2),
    p_remarks,
    jsonb_build_array(jsonb_build_object(
      'inventory_id', p_inventory_id,
      'quantity', p_quantity_sold,
      'unit_price', p_unit_price
    )),
    null,
    p_transaction_reference,
    p_other_payment_method
  );

  if p_sale_date is not null then
    update public.sales_orders
    set sale_date = p_sale_date
    where id = order_row.id
    returning * into order_row;

    update public.inventory_transactions
    set created_at = p_sale_date
    where source = 'sale'
      and source_id = order_row.id;
  end if;

  return order_row;
end;
$$;

revoke all on function public.record_inventory_sale_receipt(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text
) from public;
grant execute on function public.record_inventory_sale_receipt(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text
) to authenticated;

-- Prevent installed clients from continuing to create standalone sales rows.
revoke all on function public.record_inventory_sale_v2(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text
) from public, authenticated;
revoke all on function public.record_inventory_sale(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text
) from public, authenticated;
