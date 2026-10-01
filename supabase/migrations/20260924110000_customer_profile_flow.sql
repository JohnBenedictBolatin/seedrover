-- Customer records are created from completed sales. Profile enrichment is
-- optional, so an unclassified customer must remain a valid profile state.
alter table public.customers
  drop constraint if exists customers_type_allowed;

alter table public.customers
  add constraint customers_type_allowed check (
    customer_type in (
      'Not classified',
      'Farm Buyer',
      'Market Buyer',
      'Wholesale',
      'Restaurant',
      'Retail',
      'Other'
    )
  );
