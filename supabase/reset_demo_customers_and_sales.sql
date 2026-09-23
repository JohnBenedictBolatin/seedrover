-- DEMO RESET ONLY. Run in the Supabase SQL Editor after reviewing it.
-- Preserves users, roles, inventory, crops, and configuration.
begin;

-- Child records first because sales_order_items references sales_orders.
delete from public.customer_payments;
delete from public.customer_discounts;
delete from public.sales_order_items;
delete from public.sales_orders;
delete from public.sales_transactions;
delete from public.inventory_transactions;
delete from public.customers;

commit;

-- Verify the reset:
-- select count(*) as customers from public.customers;
-- select count(*) as sales_orders from public.sales_orders;
-- select count(*) as market_sales from public.sales_transactions;
