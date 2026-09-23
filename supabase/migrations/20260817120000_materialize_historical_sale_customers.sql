-- Ensure every historical named sale has a durable customer profile.
insert into public.customers (customer_key, display_name, contact_number)
select distinct
  lower(trim(coalesce(s.customer_name, ''))) || '::' || lower(trim(coalesce(nullif(trim(s.customer_contact), ''), 'Not provided'))),
  trim(s.customer_name),
  coalesce(nullif(trim(s.customer_contact), ''), 'Not provided')
from public.sales_orders s
where nullif(trim(coalesce(s.customer_name, '')), '') is not null
on conflict (customer_key) do nothing;

insert into public.customers (customer_key, display_name, contact_number)
select distinct
  lower(trim(s.customer_name)) || '::not provided',
  trim(s.customer_name),
  'Not provided'
from public.sales_transactions s
where nullif(trim(coalesce(s.customer_name, '')), '') is not null
on conflict (customer_key) do nothing;

update public.sales_orders s
set customer_id = c.id
from public.customers c
where s.customer_id is null
  and c.customer_key = lower(trim(coalesce(s.customer_name, ''))) || '::' || lower(trim(coalesce(nullif(trim(s.customer_contact), ''), 'Not provided')));

update public.sales_transactions s
set customer_id = c.id
from public.customers c
where s.customer_id is null
  and c.customer_key = lower(trim(coalesce(s.customer_name, ''))) || '::not provided';
