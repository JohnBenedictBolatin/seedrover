-- Keep receipt history linked to existing customer profiles when a legacy
-- profile stores the same Philippine number in +63 form.
create or replace function public.canonical_customer_contact(p_value text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  raw_value text := trim(coalesce(p_value, ''));
  digits text;
begin
  if raw_value = '' or lower(raw_value) = 'not provided'
     or raw_value !~ '^\+?[0-9 ()-]+$' then
    return null;
  end if;

  digits := regexp_replace(raw_value, '[^0-9]', '', 'g');
  if length(digits) = 12 and left(digits, 2) = '63' then
    return '0' || substring(digits from 3);
  end if;
  if length(digits) = 11 then
    return digits;
  end if;
  return null;
end;
$$;

create or replace function public.link_sales_order_customer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.customer_id is null
     and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id
    into new.customer_id
    from public.customers c
    where c.customer_key =
        lower(trim(new.customer_name)) || '::' ||
        lower(trim(coalesce(nullif(trim(new.customer_contact), ''), 'Not provided')))
      or (
        regexp_replace(lower(split_part(c.customer_key, '::', 1)), '[[:space:]]+', ' ', 'g') =
          regexp_replace(lower(trim(new.customer_name)), '[[:space:]]+', ' ', 'g')
        and public.canonical_customer_contact(c.contact_number) is not null
        and public.canonical_customer_contact(c.contact_number) =
            public.canonical_customer_contact(new.customer_contact)
      )
    limit 1;
  end if;
  return new;
end;
$$;

create or replace function public.link_sales_transaction_customer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.customer_id is null
     and nullif(trim(coalesce(new.customer_name, '')), '') is not null then
    select c.id
    into new.customer_id
    from public.customers c
    where c.customer_key =
        lower(trim(new.customer_name)) || '::' ||
        lower(trim(coalesce(nullif(trim(new.customer_contact), ''), 'Not provided')))
      or (
        regexp_replace(lower(split_part(c.customer_key, '::', 1)), '[[:space:]]+', ' ', 'g') =
          regexp_replace(lower(trim(new.customer_name)), '[[:space:]]+', ' ', 'g')
        and public.canonical_customer_contact(c.contact_number) is not null
        and public.canonical_customer_contact(c.contact_number) =
            public.canonical_customer_contact(new.customer_contact)
      )
    limit 1;
  end if;
  return new;
end;
$$;
