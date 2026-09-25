-- Customer records are derived from completed sales. Remove optional profile
-- enrichment that is not needed for customer tracking or purchase history.
alter table public.customers
  drop constraint if exists customers_type_allowed;

alter table public.customers
  drop column if exists first_name,
  drop column if exists middle_initial,
  drop column if exists last_name,
  drop column if exists alternate_contact,
  drop column if exists customer_type,
  drop column if exists tags,
  drop column if exists notes,
  drop column if exists location;
