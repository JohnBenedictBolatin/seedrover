alter table public.customers
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists middle_initial text;

alter table public.sales_orders
  add column if not exists customer_id uuid references public.customers(id) on delete set null;
alter table public.sales_transactions
  add column if not exists customer_id uuid references public.customers(id) on delete set null;

create index if not exists sales_orders_customer_id_idx on public.sales_orders(customer_id);
create index if not exists sales_transactions_customer_id_idx on public.sales_transactions(customer_id);

update public.sales_orders s set customer_id = c.id from public.customers c
where s.customer_id is null and c.customer_key = lower(trim(coalesce(s.customer_name, ''))) || '::' || lower(trim(coalesce(s.customer_contact, '')));
update public.sales_transactions s set customer_id = c.id from public.customers c
where s.customer_id is null and c.customer_key = lower(trim(coalesce(s.customer_name, ''))) || '::not provided';

create or replace function public.link_sales_order_customer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.customer_id is null and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id into new.customer_id from public.customers c
    where c.customer_key = lower(trim(new.customer_name)) || '::' || lower(trim(coalesce(nullif(trim(new.customer_contact), ''), 'Not provided'))) limit 1;
  end if;
  return new;
end; $$;

create or replace function public.link_sales_transaction_customer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.customer_id is null and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id into new.customer_id from public.customers c
    where c.customer_key = lower(trim(new.customer_name)) || '::not provided' limit 1;
  end if;
  return new;
end; $$;

drop trigger if exists sales_orders_link_customer on public.sales_orders;
create trigger sales_orders_link_customer before insert or update of customer_name, customer_contact, customer_id on public.sales_orders for each row execute function public.link_sales_order_customer();
drop trigger if exists sales_transactions_link_customer on public.sales_transactions;
create trigger sales_transactions_link_customer before insert or update of customer_name, customer_id on public.sales_transactions for each row execute function public.link_sales_transaction_customer();
