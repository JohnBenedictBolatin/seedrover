-- Installment is a sales payment method and does not require a transaction ID.
alter table public.sales_orders
  drop constraint if exists sales_orders_payment_method_allowed;

alter table public.sales_orders
  add constraint sales_orders_payment_method_allowed check (
    payment_method in ('Cash', 'GCash', 'Bank Transfer', 'Card', 'Installment', 'Other')
  );
