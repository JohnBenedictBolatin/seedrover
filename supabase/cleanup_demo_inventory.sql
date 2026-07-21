-- SeedRover inventory cleanup.
-- Run this after supabase/seed_official_stock.sql if old demo or overflow stock rows still appear.
--
-- What this removes:
-- 1. Old demo inventory rows with stock codes like STK-DEMO-%
-- 2. Extra official rows from the earlier 10-items-per-category seed, codes 006-010
--
-- Force behavior:
-- Related demo stock movement/history rows are removed first so the stock records can be deleted.
-- Receipts containing deleted demo/overflow stock are also removed to avoid inconsistent receipt totals.

do $$
declare
  removed_count integer := 0;
  skipped_count integer := 0;
begin
  create temporary table cleanup_inventory_targets (
    id uuid primary key,
    stock_code text not null,
    item_name text not null
  ) on commit drop;

  create temporary table cleanup_sales_orders (
    id uuid primary key
  ) on commit drop;

  insert into cleanup_inventory_targets (id, stock_code, item_name)
  select id, stock_code, item_name
  from public.inventory
  where stock_code like 'STK-DEMO-%'
     or stock_code in (
       'STK-LFY-006', 'STK-LFY-007', 'STK-LFY-008', 'STK-LFY-009', 'STK-LFY-010',
       'STK-FVG-006', 'STK-FVG-007', 'STK-FVG-008', 'STK-FVG-009', 'STK-FVG-010',
       'STK-LGM-006', 'STK-LGM-007', 'STK-LGM-008', 'STK-LGM-009', 'STK-LGM-010',
       'STK-RTC-006', 'STK-RTC-007', 'STK-RTC-008', 'STK-RTC-009', 'STK-RTC-010',
       'STK-FRT-006', 'STK-FRT-007', 'STK-FRT-008', 'STK-FRT-009', 'STK-FRT-010',
       'STK-HRB-006', 'STK-HRB-007', 'STK-HRB-008', 'STK-HRB-009', 'STK-HRB-010',
       'STK-PRP-006', 'STK-PRP-007', 'STK-PRP-008', 'STK-PRP-009', 'STK-PRP-010',
       'STK-OTH-006', 'STK-OTH-007', 'STK-OTH-008', 'STK-OTH-009', 'STK-OTH-010'
     );

  insert into cleanup_sales_orders (id)
  select distinct item.sales_order_id
  from public.sales_order_items item
  join cleanup_inventory_targets target
    on target.id = item.inventory_id;

  delete from public.sales_order_items item
  using cleanup_sales_orders sales_order
  where item.sales_order_id = sales_order.id;

  delete from public.sales_orders sales_order
  using cleanup_sales_orders target
  where sales_order.id = target.id;

  delete from public.sales_transactions sale
  using cleanup_inventory_targets target
  where sale.inventory_id = target.id;

  delete from public.crop_harvests harvest
  using cleanup_inventory_targets target
  where harvest.inventory_id = target.id;

  delete from public.inventory_transactions tx
  using cleanup_inventory_targets target
  where tx.inventory_id = target.id;

  delete from public.inventory inventory_row
  using cleanup_inventory_targets target
  where inventory_row.id = target.id
    and (
      inventory_row.stock_code like 'STK-DEMO-%'
      or inventory_row.stock_code in (
        'STK-LFY-006', 'STK-LFY-007', 'STK-LFY-008', 'STK-LFY-009', 'STK-LFY-010',
        'STK-FVG-006', 'STK-FVG-007', 'STK-FVG-008', 'STK-FVG-009', 'STK-FVG-010',
        'STK-LGM-006', 'STK-LGM-007', 'STK-LGM-008', 'STK-LGM-009', 'STK-LGM-010',
        'STK-RTC-006', 'STK-RTC-007', 'STK-RTC-008', 'STK-RTC-009', 'STK-RTC-010',
        'STK-FRT-006', 'STK-FRT-007', 'STK-FRT-008', 'STK-FRT-009', 'STK-FRT-010',
        'STK-HRB-006', 'STK-HRB-007', 'STK-HRB-008', 'STK-HRB-009', 'STK-HRB-010',
        'STK-PRP-006', 'STK-PRP-007', 'STK-PRP-008', 'STK-PRP-009', 'STK-PRP-010',
        'STK-OTH-006', 'STK-OTH-007', 'STK-OTH-008', 'STK-OTH-009', 'STK-OTH-010'
      )
    );

  get diagnostics removed_count = row_count;

  raise notice 'SeedRover inventory cleanup complete. Force removed % old demo/overflow stock rows.', removed_count;
end;
$$;
