-- SeedRover official stock list.
-- Run after all migrations are applied.
-- This creates official inventory records without images.
-- Starting stock quantities are included so the inventory is ready for testing/operations.
-- Image uploads can be added later through the Inventory page; this seed intentionally leaves image_path untouched.

do $$
declare
  seed_actor uuid;
begin
  select id
    into seed_actor
  from public.profiles
  where is_active = true
  order by created_at
  limit 1;

  if seed_actor is null then
    raise notice 'SeedRover official stock seed skipped: create/sign in at least one active profile first.';
    return;
  end if;

  create temporary table official_stock_seed (
    stock_code text primary key,
    item_name text not null,
    category text not null,
    unit text not null,
    quantity numeric(12, 2) not null,
    minimum_quantity numeric(12, 2) not null,
    storage_location text not null,
    unit_cost numeric(12, 2),
    selling_price numeric(12, 2)
  ) on commit drop;

  insert into official_stock_seed (
    stock_code,
    item_name,
    category,
    unit,
    quantity,
    minimum_quantity,
    storage_location,
    unit_cost,
    selling_price
  )
  values
    -- Leafy Vegetables
    ('STK-LFY-001', 'Pechay', 'Leafy Vegetables', 'kg', 45, 10, 'Cold Storage A', 42, 70),
    ('STK-LFY-002', 'Mustasa', 'Leafy Vegetables', 'kg', 36, 8, 'Cold Storage A', 38, 65),
    ('STK-LFY-003', 'Kangkong', 'Leafy Vegetables', 'bundle', 80, 20, 'Cold Storage A', 8, 15),
    ('STK-LFY-004', 'Malunggay', 'Leafy Vegetables', 'bundle', 75, 20, 'Cold Storage A', 6, 12),
    ('STK-LFY-005', 'Lettuce', 'Leafy Vegetables', 'kg', 30, 8, 'Cold Storage B', 65, 100),

    -- Fruit Vegetables
    ('STK-FVG-001', 'Tomato', 'Fruit Vegetables', 'kg', 60, 15, 'Crate Rack B', 55, 85),
    ('STK-FVG-002', 'Eggplant', 'Fruit Vegetables', 'kg', 48, 12, 'Crate Rack B', 42, 70),
    ('STK-FVG-003', 'Okra', 'Fruit Vegetables', 'kg', 35, 8, 'Crate Rack B', 35, 60),
    ('STK-FVG-004', 'Ampalaya', 'Fruit Vegetables', 'kg', 32, 8, 'Crate Rack B', 50, 85),
    ('STK-FVG-005', 'Cucumber', 'Fruit Vegetables', 'kg', 50, 12, 'Crate Rack B', 38, 65),

    -- Legumes
    ('STK-LGM-001', 'Sitaw', 'Legumes', 'kg', 35, 8, 'Crate Rack C', 40, 70),
    ('STK-LGM-002', 'Baguio Beans', 'Legumes', 'kg', 30, 8, 'Crate Rack C', 55, 90),
    ('STK-LGM-003', 'Snow Peas', 'Legumes', 'kg', 20, 5, 'Cold Storage B', 110, 170),
    ('STK-LGM-004', 'Green Peas', 'Legumes', 'kg', 22, 5, 'Cold Storage B', 90, 145),
    ('STK-LGM-005', 'Winged Beans', 'Legumes', 'kg', 24, 6, 'Crate Rack C', 55, 90),

    -- Root Crops
    ('STK-RTC-001', 'Carrot', 'Root Crops', 'kg', 45, 12, 'Dry Storage B', 55, 90),
    ('STK-RTC-002', 'Radish', 'Root Crops', 'kg', 40, 10, 'Dry Storage B', 30, 55),
    ('STK-RTC-003', 'Sweet Potato', 'Root Crops', 'kg', 70, 18, 'Dry Storage B', 28, 50),
    ('STK-RTC-004', 'Cassava', 'Root Crops', 'kg', 65, 18, 'Dry Storage B', 25, 45),
    ('STK-RTC-005', 'Taro', 'Root Crops', 'kg', 42, 12, 'Dry Storage B', 45, 75),

    -- Fruits
    ('STK-FRT-001', 'Calamansi', 'Fruits', 'kg', 38, 10, 'Crate Rack D', 55, 90),
    ('STK-FRT-002', 'Green Papaya', 'Fruits', 'kg', 42, 10, 'Crate Rack D', 35, 60),
    ('STK-FRT-003', 'Ripe Papaya', 'Fruits', 'kg', 30, 8, 'Crate Rack D', 40, 70),
    ('STK-FRT-004', 'Banana', 'Fruits', 'kg', 70, 15, 'Crate Rack D', 35, 60),
    ('STK-FRT-005', 'Watermelon', 'Fruits', 'kg', 95, 20, 'Crate Rack D', 28, 50),

    -- Herbs
    ('STK-HRB-001', 'Basil', 'Herbs', 'bundle', 45, 10, 'Cold Storage C', 18, 35),
    ('STK-HRB-002', 'Mint', 'Herbs', 'bundle', 42, 10, 'Cold Storage C', 18, 35),
    ('STK-HRB-003', 'Parsley', 'Herbs', 'bundle', 32, 8, 'Cold Storage C', 20, 38),
    ('STK-HRB-004', 'Cilantro', 'Herbs', 'bundle', 34, 8, 'Cold Storage C', 20, 38),
    ('STK-HRB-005', 'Spring Onion', 'Herbs', 'bundle', 65, 15, 'Cold Storage C', 12, 24),

    -- Prepared Produce
    ('STK-PRP-001', 'Washed Lettuce Pack', 'Prepared Produce', 'pack', 35, 10, 'Packing Bay A', 45, 75),
    ('STK-PRP-002', 'Mixed Pinakbet Pack', 'Prepared Produce', 'pack', 32, 10, 'Packing Bay A', 70, 110),
    ('STK-PRP-003', 'Chopped Kangkong Pack', 'Prepared Produce', 'pack', 40, 10, 'Packing Bay A', 25, 45),
    ('STK-PRP-004', 'Peeled Garlic Pack', 'Prepared Produce', 'pack', 26, 8, 'Packing Bay A', 55, 90),
    ('STK-PRP-005', 'Sliced Tomato Pack', 'Prepared Produce', 'pack', 28, 8, 'Packing Bay A', 45, 75),

    -- Others
    ('STK-OTH-001', 'Mushroom', 'Others', 'kg', 24, 6, 'Cold Storage D', 120, 180),
    ('STK-OTH-002', 'Bamboo Shoots', 'Others', 'kg', 22, 6, 'Cold Storage D', 65, 100),
    ('STK-OTH-003', 'Banana Blossom', 'Others', 'piece', 30, 10, 'Cold Storage D', 25, 45),
    ('STK-OTH-004', 'Young Corn', 'Others', 'kg', 26, 6, 'Cold Storage D', 80, 125),
    ('STK-OTH-005', 'Corn', 'Others', 'piece', 100, 20, 'Crate Rack E', 15, 25);

  -- If the earlier 10-per-category seed was already run, remove unused official overflow rows.
  -- Rows with sales or stock movement history are preserved to avoid breaking records.
  delete from public.inventory target
  where target.stock_code in (
    'STK-LFY-006', 'STK-LFY-007', 'STK-LFY-008', 'STK-LFY-009', 'STK-LFY-010',
    'STK-FVG-006', 'STK-FVG-007', 'STK-FVG-008', 'STK-FVG-009', 'STK-FVG-010',
    'STK-LGM-006', 'STK-LGM-007', 'STK-LGM-008', 'STK-LGM-009', 'STK-LGM-010',
    'STK-RTC-006', 'STK-RTC-007', 'STK-RTC-008', 'STK-RTC-009', 'STK-RTC-010',
    'STK-FRT-006', 'STK-FRT-007', 'STK-FRT-008', 'STK-FRT-009', 'STK-FRT-010',
    'STK-HRB-006', 'STK-HRB-007', 'STK-HRB-008', 'STK-HRB-009', 'STK-HRB-010',
    'STK-PRP-006', 'STK-PRP-007', 'STK-PRP-008', 'STK-PRP-009', 'STK-PRP-010',
    'STK-OTH-006', 'STK-OTH-007', 'STK-OTH-008', 'STK-OTH-009', 'STK-OTH-010'
  )
  and not exists (
    select 1
    from public.inventory_transactions tx
    where tx.inventory_id = target.id
  )
  and not exists (
    select 1
    from public.sales_order_items item
    where item.inventory_id = target.id
  );

  update public.inventory target
  set
    item_name = seed.item_name,
    category = seed.category,
    quantity = seed.quantity,
    unit = seed.unit,
    minimum_quantity = seed.minimum_quantity,
    storage_location = seed.storage_location,
    unit_cost = seed.unit_cost,
    selling_price = seed.selling_price,
    updated_by = seed_actor,
    updated_at = now()
  from official_stock_seed seed
  where target.stock_code = seed.stock_code;

  insert into public.inventory (
    stock_code,
    item_name,
    quantity,
    unit,
    minimum_quantity,
    storage_location,
    category,
    unit_cost,
    selling_price,
    updated_by
  )
  select
    seed.stock_code,
    seed.item_name,
    seed.quantity,
    seed.unit,
    seed.minimum_quantity,
    seed.storage_location,
    seed.category,
    seed.unit_cost,
    seed.selling_price,
    seed_actor
  from official_stock_seed seed
  where not exists (
    select 1
    from public.inventory target
    where target.stock_code = seed.stock_code
  );

  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values (
    seed_actor,
    'Official Stock List Seeded',
    'SeedRover official vegetable stock list was prepared with 5 items per category and without images.',
    'Stocks'
  );
end;
$$;
