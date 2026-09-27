-- Contact fields remain text for historical and optional values, while every
-- new or changed non-placeholder value is normalized and validated.
create or replace function public.normalize_contact_number(p_value text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  trimmed_value text := trim(coalesce(p_value, ''));
  digits text;
begin
  if trimmed_value = '' then
    return null;
  end if;

  if lower(trimmed_value) = 'not provided' then
    return 'Not provided';
  end if;

  if trimmed_value !~ '^\+?[0-9 ()-]+$' then
    raise exception 'Contact number must contain exactly 11 digits.';
  end if;

  digits := regexp_replace(trimmed_value, '[^0-9]', '', 'g');

  if length(digits) = 12
     and left(digits, 2) = '63'
     and (left(trimmed_value, 3) = '+63' or left(trimmed_value, 2) = '63') then
    return '0' || substring(digits from 3);
  end if;

  if length(digits) = 11 then
    return digits;
  end if;

  raise exception 'Contact number must contain exactly 11 digits.';
end;
$$;

create or replace function public.guard_contact_number_write()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  field_name text := tg_argv[0];
  new_value text := to_jsonb(new) ->> tg_argv[0];
  old_value text;
  normalized_value text;
begin
  if tg_op = 'UPDATE' then
    old_value := to_jsonb(old) ->> field_name;
    -- Leave pre-existing invalid legacy values alone when a different field
    -- is edited. Any new or changed contact is normalized and validated.
    if new_value is not distinct from old_value then
      return new;
    end if;
  end if;

  normalized_value := public.normalize_contact_number(new_value);
  if coalesce(tg_argv[1], '') = 'required'
     and (normalized_value is null or normalized_value = 'Not provided') then
    raise exception 'Contact number is required.';
  end if;
  new := jsonb_populate_record(new, jsonb_build_object(field_name, normalized_value));
  return new;
end;
$$;

drop trigger if exists contact_number_guard_profiles on public.profiles;
create trigger contact_number_guard_profiles
before insert or update on public.profiles
for each row execute function public.guard_contact_number_write('contact_number');

drop trigger if exists contact_number_guard_customers on public.customers;
create trigger contact_number_guard_customers
before insert or update on public.customers
for each row execute function public.guard_contact_number_write('contact_number');

drop trigger if exists contact_number_guard_sales_orders on public.sales_orders;
create trigger contact_number_guard_sales_orders
before insert or update on public.sales_orders
for each row execute function public.guard_contact_number_write('customer_contact', 'required');

drop trigger if exists contact_number_guard_sales_transactions on public.sales_transactions;
create trigger contact_number_guard_sales_transactions
before insert or update on public.sales_transactions
for each row execute function public.guard_contact_number_write('customer_contact');

drop trigger if exists contact_number_guard_customer_discounts on public.customer_discounts;
create trigger contact_number_guard_customer_discounts
before insert or update on public.customer_discounts
for each row execute function public.guard_contact_number_write('customer_contact');

drop trigger if exists contact_number_guard_installment_plans on public.installment_plans;
create trigger contact_number_guard_installment_plans
before insert or update on public.installment_plans
for each row execute function public.guard_contact_number_write('customer_contact');

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
  p_customer_contact := public.normalize_contact_number(p_customer_contact);
  if p_customer_contact is null then
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
