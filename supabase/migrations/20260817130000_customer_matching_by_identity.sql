create or replace function public.link_sales_order_customer() returns trigger
language plpgsql security definer set search_path = public as $$
declare match_id uuid;
begin
  if new.customer_id is null and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id into match_id from public.customers c where c.customer_key = lower(trim(new.customer_name)) || '::' || lower(trim(coalesce(nullif(trim(new.customer_contact), ''), 'Not provided'))) limit 1;
    if match_id is null then select min(c.id) into match_id from public.customers c where lower(trim(c.display_name)) = lower(trim(new.customer_name)) having count(*) = 1; end if;
    new.customer_id = match_id;
  end if;
  return new;
end; $$;

create or replace function public.link_sales_transaction_customer() returns trigger
language plpgsql security definer set search_path = public as $$
declare match_id uuid;
begin
  if new.customer_id is null and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id into match_id from public.customers c where c.customer_key = lower(trim(new.customer_name)) || '::not provided' limit 1;
    if match_id is null then select min(c.id) into match_id from public.customers c where lower(trim(c.display_name)) = lower(trim(new.customer_name)) having count(*) = 1; end if;
    new.customer_id = match_id;
  end if;
  return new;
end; $$;
