-- Selective cleanup for the legacy rows audited on 2026-09-28.
-- Run manually in the Supabase SQL Editor after exporting/backing up the rows
-- listed below. The preview section is read-only. The execution section is
-- transactional and aborts if the audited rows or dependent counts changed.
-- It deliberately does not restore stock or modify crops/crop history.

-- ---------------------------------------------------------------------------
-- READ-ONLY PREVIEW
-- ---------------------------------------------------------------------------
with targets(id, receipt_number, expected_total) as (
  values
    ('059da5e2-7d3b-4a66-9068-c5347eb5dcbb'::uuid, 'SR-20260817-062C872A', 1950.00::numeric),
    ('b805f80d-6260-42a5-9285-097b7cfd37bc'::uuid, 'SR-20260923-2098B12A', 1200.00::numeric),
    ('8b864672-5ca6-4b3b-8fa0-5aa45297476d'::uuid, 'SR-20260923-F0CF6315', 1200.00::numeric),
    ('cbe14c5c-b95a-4403-a840-09aa979901a3'::uuid, 'SR-20260923-62980627', 3150.00::numeric),
    ('179d8e9d-b961-4fd3-bb7e-da2fff1addeb'::uuid, 'SR-20260927-04C28E9D', 250.00::numeric)
)
select t.receipt_number, o.id, o.customer_name, o.customer_contact,
       o.payment_method, o.total_amount, o.status, o.created_at
from targets t
join public.sales_orders o on o.id = t.id
order by o.created_at;

select id, customer_name, customer_contact, total_amount, status, sale_date
from public.sales_transactions
where id in (
  '76149bac-29e4-4b46-bc2b-8e951065f3fd',
  '34f9538a-6fea-4e07-af38-4b5ab4b958a5',
  '35fb6343-f053-4aac-9b54-59a0d6ffac6d'
)
order by sale_date;

select table_name, row_id, details
from (
  select 'sales_order_items'::text as table_name, i.id as row_id,
         jsonb_build_object('sales_order_id', i.sales_order_id,
                            'item', i.item_name_snapshot,
                            'quantity', i.quantity_sold,
                            'line_total', i.line_total) as details
  from public.sales_order_items i
  where i.sales_order_id in (
    '059da5e2-7d3b-4a66-9068-c5347eb5dcbb',
    'b805f80d-6260-42a5-9285-097b7cfd37bc',
    '8b864672-5ca6-4b3b-8fa0-5aa45297476d',
    'cbe14c5c-b95a-4403-a840-09aa979901a3',
    '179d8e9d-b961-4fd3-bb7e-da2fff1addeb'
  )
  union all
  select 'inventory_transactions', tx.id,
         jsonb_build_object('source', tx.source, 'source_id', tx.source_id,
                            'type', tx.transaction_type, 'quantity', tx.quantity,
                            'remarks', tx.remarks)
  from public.inventory_transactions tx
  where tx.id in (
    '6c9deaf8-f0d4-4996-ace7-887c1e8379f8',
    'c5957bea-6762-43b2-acc3-8bdd8dd46e06',
    '827408e0-4368-4958-9c8a-33c6d83c1b41',
    '3b5f228c-80dd-4a4b-9348-11ef0f2e6dde',
    'd85404e4-0148-4b82-9be7-116406ac44b7',
    'bde64fc8-7802-4cd2-9aa5-2acc5f6efaa5',
    'c5980330-a2cf-4e97-9acf-7c29259e16d7',
    'fc4779a1-9147-479f-9e33-d6723245e683',
    'ecffdc24-29ae-46d2-828d-a2974ad47ddf',
    'a9e3d354-ccdc-436c-8035-469437424c9e'
  )
) affected
order by table_name, row_id;

select id, source, source_id, transaction_type, quantity, remarks
from public.inventory_transactions
where id in (
  'd6dcca69-d4b6-4c49-a38e-a431c43266ce',
  '44118405-11e6-4d2a-8dd0-f13b4a7184c5',
  'abef0cc2-f341-46d5-8e7b-3d32c5db16cf',
  '2fd4ca97-ca43-4067-952b-4834ad2bc6c5',
  'fb38531d-8b00-46f9-935e-967f477b55a3',
  'b5d2aef4-d48d-45e4-bbe5-e015d10636dc',
  '75b49d98-d68f-4d44-901c-4f62285ef00a',
  'd1d43341-35a4-4e57-9800-c71bc3f5501a',
  'd79c617d-256f-4fc2-9595-2ed11b8fedff',
  '4e5944fe-7c11-4b0c-aaa1-11013fe41a7b',
  '7fcc56fe-ffc1-4a0f-8d96-598f352d3e1c',
  '8090010f-e29a-4f33-b4a8-773fe2ef70e9',
  '4c3ac401-cba5-4385-b953-4d7d687e09ff'
)
order by created_at, id;

select 'installment_plan' as record_type, to_jsonb(p) as record
from public.installment_plans p
where p.id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8'
union all
select 'legacy_customer_payment', to_jsonb(p)
from public.customer_payments p
where p.id = 'eacec761-222c-4a36-8964-3bee91496a60'
union all
select 'discount', to_jsonb(d)
from public.customer_discounts d
where d.id = '66492f2c-9eeb-4c40-839c-2faa6cfb3b9a'
union all
select 'sample_expense', to_jsonb(e)
from public.farm_expenses e
where e.id = 'f0910378-ea78-4f0c-a97e-9d60914342dd'
union all
select 'demo_command', to_jsonb(c)
from public.robot_commands c
where c.id in (
  '19c3d7f6-bfda-4138-9666-48db043340aa',
  'f229dbd2-354d-4ef8-98d3-04156dc4d921'
)
union all
select 'demo_notification', to_jsonb(n)
from public.notifications n
where n.id = 'ead24036-73e0-4608-9a79-75991f8d1ace'
union all
select 'demo_activity_log', to_jsonb(a)
from public.activity_logs a
where a.id in (
  '1453a5cd-d423-45de-b28a-af9116ac6a0a',
  'd3109c20-924b-40c3-ad67-3f14d3dfabaa'
);

-- ---------------------------------------------------------------------------
-- DESTRUCTIVE EXECUTION: run only after verifying the preview and backup.
-- ---------------------------------------------------------------------------
begin;
set local lock_timeout = '10s';
set local statement_timeout = '2min';

-- SHARE locks prevent concurrent DML while targets/counts are checked and
-- deleted. Existing rows remain readable to other sessions.
lock table public.sales_orders, public.sales_order_items,
  public.sales_transactions, public.inventory_transactions,
  public.installment_plans, public.installment_schedule,
  public.installment_payments, public.customer_payments,
  public.customer_discounts, public.robot_commands,
  public.notifications, public.activity_logs, public.farm_expenses,
  public.inventory, public.crops, public.crop_activities,
  public.crop_harvests, public.crop_outcomes, public.planting_logs,
  public.sensor_readings
in share mode;

do $cleanup$
declare
  expected_order_ids uuid[] := array[
    '059da5e2-7d3b-4a66-9068-c5347eb5dcbb',
    'b805f80d-6260-42a5-9285-097b7cfd37bc',
    '8b864672-5ca6-4b3b-8fa0-5aa45297476d',
    'cbe14c5c-b95a-4403-a840-09aa979901a3',
    '179d8e9d-b961-4fd3-bb7e-da2fff1addeb'
  ]::uuid[];
  expected_market_ids uuid[] := array[
    '76149bac-29e4-4b46-bc2b-8e951065f3fd',
    '34f9538a-6fea-4e07-af38-4b5ab4b958a5',
    '35fb6343-f053-4aac-9b54-59a0d6ffac6d'
  ]::uuid[];
  expected_stock_tx_ids uuid[] := array[
    '6c9deaf8-f0d4-4996-ace7-887c1e8379f8',
    'c5957bea-6762-43b2-acc3-8bdd8dd46e06',
    '827408e0-4368-4958-9c8a-33c6d83c1b41',
    '3b5f228c-80dd-4a4b-9348-11ef0f2e6dde',
    'd85404e4-0148-4b82-9be7-116406ac44b7',
    'bde64fc8-7802-4cd2-9aa5-2acc5f6efaa5',
    'c5980330-a2cf-4e97-9acf-7c29259e16d7',
    'fc4779a1-9147-479f-9e33-d6723245e683',
    'ecffdc24-29ae-46d2-828d-a2974ad47ddf',
    'a9e3d354-ccdc-436c-8035-469437424c9e'
  ]::uuid[];
  expected_orphan_tx_ids uuid[] := array[
    'd6dcca69-d4b6-4c49-a38e-a431c43266ce',
    '44118405-11e6-4d2a-8dd0-f13b4a7184c5',
    'abef0cc2-f341-46d5-8e7b-3d32c5db16cf',
    '2fd4ca97-ca43-4067-952b-4834ad2bc6c5',
    'fb38531d-8b00-46f9-935e-967f477b55a3',
    'b5d2aef4-d48d-45e4-bbe5-e015d10636dc',
    '75b49d98-d68f-4d44-901c-4f62285ef00a',
    'd1d43341-35a4-4e57-9800-c71bc3f5501a',
    'd79c617d-256f-4fc2-9595-2ed11b8fedff',
    '4e5944fe-7c11-4b0c-aaa1-11013fe41a7b',
    '7fcc56fe-ffc1-4a0f-8d96-598f352d3e1c',
    '8090010f-e29a-4f33-b4a8-773fe2ef70e9',
    '4c3ac401-cba5-4385-b953-4d7d687e09ff'
  ]::uuid[];
  before_inventory jsonb;
  before_crops jsonb;
  before_crop_history jsonb;
  v_deleted_items integer;
begin
  select coalesce(jsonb_agg(to_jsonb(i) order by i.id), '[]'::jsonb)
    into before_inventory from public.inventory i;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb)
    into before_crops from public.crops c;
  select jsonb_build_object(
    'crop_activities', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.crop_activities x),
    'crop_harvests', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.crop_harvests x),
    'crop_outcomes', (select coalesce(jsonb_agg(to_jsonb(x) order by x.crop_name, x.recorded_at), '[]'::jsonb) from public.crop_outcomes x),
    'planting_logs', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.planting_logs x),
    'sensor_readings', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.sensor_readings x)
  ) into before_crop_history;

  -- A complete prior run is a successful no-op. This makes reruns safe while
  -- still allowing the partial-state checks below to abort unexpected drift.
  if not exists (select 1 from public.sales_orders where id = any(expected_order_ids))
     and not exists (select 1 from public.sales_order_items where sales_order_id = any(expected_order_ids))
     and not exists (select 1 from public.sales_transactions where id = any(expected_market_ids))
     and not exists (select 1 from public.inventory_transactions where id = any(expected_stock_tx_ids))
     and not exists (select 1 from public.inventory_transactions where id = any(expected_orphan_tx_ids))
     and not exists (select 1 from public.installment_plans where id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8')
     and not exists (select 1 from public.installment_schedule where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8')
     and not exists (select 1 from public.installment_payments where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8')
     and not exists (select 1 from public.customer_payments where id = 'eacec761-222c-4a36-8964-3bee91496a60')
     and not exists (select 1 from public.customer_discounts where id = '66492f2c-9eeb-4c40-839c-2faa6cfb3b9a')
     and not exists (select 1 from public.robot_commands where id in (
       '19c3d7f6-bfda-4138-9666-48db043340aa',
       'f229dbd2-354d-4ef8-98d3-04156dc4d921'
     ))
     and not exists (select 1 from public.notifications where id = 'ead24036-73e0-4608-9a79-75991f8d1ace')
     and not exists (select 1 from public.activity_logs where id in (
       '1453a5cd-d423-45de-b28a-af9116ac6a0a',
       'd3109c20-924b-40c3-ad67-3f14d3dfabaa'
     ))
     and not exists (select 1 from public.farm_expenses where id = 'f0910378-ea78-4f0c-a97e-9d60914342dd') then
    raise notice 'Legacy cleanup was already applied; no changes made.';
    return;
  end if;

  if (select count(*) from public.sales_orders where id = any(expected_order_ids)) <> 5
     or exists (
       select 1 from (values
         ('059da5e2-7d3b-4a66-9068-c5347eb5dcbb'::uuid, 'SR-20260817-062C872A', 1950.00::numeric),
         ('b805f80d-6260-42a5-9285-097b7cfd37bc'::uuid, 'SR-20260923-2098B12A', 1200.00::numeric),
         ('8b864672-5ca6-4b3b-8fa0-5aa45297476d'::uuid, 'SR-20260923-F0CF6315', 1200.00::numeric),
         ('cbe14c5c-b95a-4403-a840-09aa979901a3'::uuid, 'SR-20260923-62980627', 3150.00::numeric),
         ('179d8e9d-b961-4fd3-bb7e-da2fff1addeb'::uuid, 'SR-20260927-04C28E9D', 250.00::numeric)
       ) expected(id, receipt, total)
       left join public.sales_orders o on o.id = expected.id
       where o.id is null or o.receipt_number <> expected.receipt or o.total_amount <> expected.total
     ) then
    raise exception 'Receipt targets changed; cleanup aborted.';
  end if;

  if (select count(*) from public.sales_transactions where id = any(expected_market_ids)) <> 3
     or (select count(*) from public.sales_transactions where id = expected_market_ids[3] and status = 'Voided' and void_reason = 'Legacy sales transaction.') <> 1 then
    raise exception 'Market sale targets changed; cleanup aborted.';
  end if;

  if (select count(*) from public.inventory_transactions where id = any(expected_stock_tx_ids)) <> 10
     or (select count(*) from public.inventory_transactions where id = any(expected_orphan_tx_ids)) <> 13
     or exists (
       select 1 from public.inventory_transactions tx
       where id = any(expected_orphan_tx_ids)
         and (tx.source not in ('sale', 'void_sale') or exists (
           select 1 from public.sales_orders o where o.id = tx.source_id
           union all
           select 1 from public.sales_transactions s where s.id = tx.source_id
         ))
     ) then
    raise exception 'Sale-linked or orphan stock movement targets changed; cleanup aborted.';
  end if;

  if (select count(*) from public.customer_payments
      where id = 'eacec761-222c-4a36-8964-3bee91496a60'
        and sale_reference = 'SR-20260923-F0CF6315' and amount = 1000.00 and status = 'Pending') <> 1
     or (select count(*) from public.installment_plans
         where id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8' and sales_order_id = expected_order_ids[4]) <> 1
     or (select count(*) from public.customer_discounts
         where id = '66492f2c-9eeb-4c40-839c-2faa6cfb3b9a' and discount_code = 'SR-XYD357') <> 1
     or (select count(*) from public.farm_expenses
         where id = 'f0910378-ea78-4f0c-a97e-9d60914342dd' and amount = 1111.00 and notes = 'sAMPLE') <> 1
     or (select count(*) from public.robot_commands
         where id in ('19c3d7f6-bfda-4138-9666-48db043340aa', 'f229dbd2-354d-4ef8-98d3-04156dc4d921')) <> 2
     or (select count(*) from public.notifications
         where id = 'ead24036-73e0-4608-9a79-75991f8d1ace'
           and title = 'Rover monitor updated' and message = 'Demo rover status is online and ready for monitoring.') <> 1
     or (select count(*) from public.activity_logs
         where id in ('1453a5cd-d423-45de-b28a-af9116ac6a0a', 'd3109c20-924b-40c3-ad67-3f14d3dfabaa')) <> 2 then
    raise exception 'A dependent or ancillary target changed; cleanup aborted.';
  end if;

  if (select count(*) from public.installment_schedule where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8') <> 7
     or (select count(*) from public.installment_payments where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8') <> 3
     or (select coalesce(sum(amount), 0) from public.installment_payments where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8') <> 1500.00
     or (select count(*) from public.customer_discounts where id <> '66492f2c-9eeb-4c40-839c-2faa6cfb3b9a') <> 3 then
    raise exception 'Installment or discount counts changed; cleanup aborted.';
  end if;

  delete from public.sales_order_items where sales_order_id = any(expected_order_ids);
  get diagnostics v_deleted_items = row_count;
  raise notice 'Removed % receipt line items.', v_deleted_items;

  delete from public.installment_payments where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8';
  delete from public.installment_schedule where plan_id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8';
  delete from public.installment_plans where id = '55b8ac68-5fe7-45e8-b274-c4e5372b72b8';
  delete from public.customer_payments where id = 'eacec761-222c-4a36-8964-3bee91496a60';
  delete from public.customer_discounts where id = '66492f2c-9eeb-4c40-839c-2faa6cfb3b9a';

  delete from public.inventory_transactions where id = any(expected_stock_tx_ids);
  delete from public.inventory_transactions where id = any(expected_orphan_tx_ids);
  delete from public.sales_orders where id = any(expected_order_ids);
  delete from public.sales_transactions where id = any(expected_market_ids);

  delete from public.robot_commands where id in (
    '19c3d7f6-bfda-4138-9666-48db043340aa',
    'f229dbd2-354d-4ef8-98d3-04156dc4d921'
  );
  delete from public.notifications where id = 'ead24036-73e0-4608-9a79-75991f8d1ace';
  delete from public.activity_logs where id in (
    '1453a5cd-d423-45de-b28a-af9116ac6a0a',
    'd3109c20-924b-40c3-ad67-3f14d3dfabaa'
  );
  delete from public.farm_expenses where id = 'f0910378-ea78-4f0c-a97e-9d60914342dd';

  if (select coalesce(jsonb_agg(to_jsonb(i) order by i.id), '[]'::jsonb) from public.inventory i) <> before_inventory
     or (select coalesce(jsonb_agg(to_jsonb(c) order by c.id), '[]'::jsonb) from public.crops c) <> before_crops
     or (select jsonb_build_object(
       'crop_activities', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.crop_activities x),
       'crop_harvests', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.crop_harvests x),
       'crop_outcomes', (select coalesce(jsonb_agg(to_jsonb(x) order by x.crop_name, x.recorded_at), '[]'::jsonb) from public.crop_outcomes x),
       'planting_logs', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.planting_logs x),
       'sensor_readings', (select coalesce(jsonb_agg(to_jsonb(x) order by x.id), '[]'::jsonb) from public.sensor_readings x)
     )) <> before_crop_history then
    raise exception 'Protected inventory or crop data changed; cleanup aborted.';
  end if;

  if (select count(*) from public.sales_orders) <> 11
     or (select count(*) from public.sales_transactions) <> 0
     or (select count(*) from public.installment_plans) <> 2
     or (select count(*) from public.installment_schedule) <> 9
     or (select count(*) from public.installment_payments) <> 2
     or (select count(*) from public.customer_discounts) <> 3
     or (select count(*) from public.inventory_transactions) <> 41 then
    raise exception 'Post-cleanup counts differ from the audited expected state; cleanup aborted.';
  end if;
end;
$cleanup$;

commit;

-- Post-run read-only checks:
-- select count(*) from public.sales_orders;             -- 11
-- select count(*) from public.sales_transactions;       -- 0
-- select count(*) from public.installment_plans;        -- 2
-- select count(*) from public.installment_schedule;     -- 9
-- select count(*) from public.installment_payments;     -- 2
-- select count(*) from public.customer_discounts;       -- 3
-- select count(*) from public.inventory_transactions;  -- 41
-- select count(*) from public.inventory;               -- 26
-- select count(*) from public.crops;                   -- 13
