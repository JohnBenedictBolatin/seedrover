alter table public.inventory
  add column if not exists notes text;

alter table public.sales_transactions
  add column if not exists customer_contact text;

create or replace function public.link_sales_transaction_customer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.customer_id is null and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id into new.customer_id from public.customers c
    where c.customer_key = lower(trim(new.customer_name)) || '::' ||
      lower(trim(coalesce(nullif(trim(new.customer_contact), ''), 'Not provided')))
    limit 1;
  end if;
  return new;
end; $$;

drop trigger if exists sales_transactions_link_customer on public.sales_transactions;
create trigger sales_transactions_link_customer
before insert or update of customer_name, customer_contact, customer_id
on public.sales_transactions for each row
execute function public.link_sales_transaction_customer();

create or replace function public.record_inventory_sale_v2(
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
returns public.sales_transactions
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  completed_sale public.sales_transactions%rowtype;
begin
  if nullif(trim(coalesce(p_customer_name, '')), '') is null then
    raise exception 'Customer name is required.';
  end if;
  if nullif(trim(coalesce(p_customer_contact, '')), '') is null then
    raise exception 'Customer contact is required.';
  end if;

  completed_sale := public.record_inventory_sale(
    p_inventory_id, p_quantity_sold, p_unit_price, p_sale_date,
    p_customer_name, p_remarks, p_payment_method,
    p_transaction_reference, p_other_payment_method
  );

  update public.sales_transactions
  set customer_contact = nullif(trim(p_customer_contact), '')
  where id = completed_sale.id
  returning * into completed_sale;

  return completed_sale;
end;
$$;

revoke all on function public.record_inventory_sale_v2(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text
) from public;
grant execute on function public.record_inventory_sale_v2(
  uuid, numeric, numeric, timestamptz, text, text, text, text, text, text
) to authenticated;
