-- SeedRover demo data for staging/testing.
-- Run after all migrations are applied.
-- This does not create Supabase Auth users. It uses the first active profile
-- as the demo actor for records that require a user reference.

do $$
declare
  demo_actor uuid;
  malunggay_id uuid;
  pechay_id uuid;
  tomato_id uuid;
  okra_id uuid;
  sitaw_id uuid;
  lettuce_id uuid;
  order_id uuid;
begin
  select id
    into demo_actor
  from public.profiles
  where is_active = true
  order by created_at
  limit 1;

  if demo_actor is null then
    raise notice 'SeedRover demo seed skipped: create/sign in at least one admin profile first.';
    return;
  end if;

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
  values
    ('STK-DEMO-001', 'Malunggay', 0, 'bundle', 10, 'Cold Storage A', 'Leafy Vegetables', 6, 10, demo_actor),
    ('STK-DEMO-002', 'Pechay', 0, 'kg', 8, 'Cold Storage A', 'Leafy Vegetables', 45, 70, demo_actor),
    ('STK-DEMO-003', 'Tomato', 0, 'kg', 12, 'Crate Rack B', 'Fruit Vegetables', 55, 85, demo_actor),
    ('STK-DEMO-004', 'Okra', 0, 'kg', 6, 'Crate Rack B', 'Fruit Vegetables', 35, 60, demo_actor),
    ('STK-DEMO-005', 'Sitaw', 0, 'kg', 5, 'Crate Rack C', 'Legumes', 40, 65, demo_actor),
    ('STK-DEMO-006', 'Lettuce', 0, 'kg', 7, 'Cold Storage B', 'Leafy Vegetables', 65, 95, demo_actor)
  on conflict do nothing;

  select id into malunggay_id from public.inventory where stock_code = 'STK-DEMO-001';
  select id into pechay_id from public.inventory where stock_code = 'STK-DEMO-002';
  select id into tomato_id from public.inventory where stock_code = 'STK-DEMO-003';
  select id into okra_id from public.inventory where stock_code = 'STK-DEMO-004';
  select id into sitaw_id from public.inventory where stock_code = 'STK-DEMO-005';
  select id into lettuce_id from public.inventory where stock_code = 'STK-DEMO-006';

  insert into public.inventory_transactions (
    inventory_id,
    transaction_type,
    quantity,
    remarks,
    performed_by,
    source
  )
  select *
  from (
    values
      (malunggay_id, 'IN', 80::numeric, 'Demo opening balance - Malunggay', demo_actor, 'manual'),
      (pechay_id, 'IN', 45::numeric, 'Demo opening balance - Pechay', demo_actor, 'manual'),
      (tomato_id, 'IN', 60::numeric, 'Demo opening balance - Tomato', demo_actor, 'manual'),
      (okra_id, 'IN', 34::numeric, 'Demo opening balance - Okra', demo_actor, 'manual'),
      (sitaw_id, 'IN', 28::numeric, 'Demo opening balance - Sitaw', demo_actor, 'manual'),
      (lettuce_id, 'IN', 22::numeric, 'Demo opening balance - Lettuce', demo_actor, 'manual')
  ) as seed(inventory_id, transaction_type, quantity, remarks, performed_by, source)
  where not exists (
    select 1
    from public.inventory_transactions existing
    where existing.inventory_id = seed.inventory_id
      and existing.remarks = seed.remarks
  );

  insert into public.customers (
    customer_key,
    display_name,
    contact_number,
    customer_type,
    tags,
    notes,
    location,
    created_by,
    updated_by
  )
  values
    ('jason eludo::09171234567', 'Jason Eludo', '09171234567', 'Market Buyer', array['Market Buyer', 'Repeat Buyer'], 'Buys mixed vegetables for stall supply.', 'Public Market', demo_actor, demo_actor),
    ('maria santos::09181234567', 'Maria Santos', '09181234567', 'Restaurant', array['Priority', 'Wholesale'], 'Restaurant buyer for leafy vegetables.', 'Local Restaurant', demo_actor, demo_actor),
    ('walk-in customer::not provided', 'Walk-in customer', 'Not provided', 'Retail', array['Walk-in'], 'Default walk-in buyer record.', 'Farm Gate', demo_actor, demo_actor)
  on conflict (customer_key) do update
  set
    display_name = excluded.display_name,
    contact_number = excluded.contact_number,
    customer_type = excluded.customer_type,
    tags = excluded.tags,
    notes = excluded.notes,
    location = excluded.location,
    updated_by = excluded.updated_by;

  insert into public.customer_discounts (
    discount_code,
    customer_key,
    customer_name,
    customer_contact,
    discount_type,
    discount_value,
    valid_until,
    notes,
    status,
    released_by
  )
  values (
    'DEMOHARVEST10',
    'jason eludo::09171234567',
    'Jason Eludo',
    '09171234567',
    'Percent',
    10,
    current_date + interval '30 days',
    'Demo discount for repeat market buyer.',
    'Released',
    demo_actor
  )
  on conflict (discount_code) do update
  set
    customer_key = excluded.customer_key,
    customer_name = excluded.customer_name,
    customer_contact = excluded.customer_contact,
    discount_type = excluded.discount_type,
    discount_value = excluded.discount_value,
    valid_until = excluded.valid_until,
    notes = excluded.notes,
    status = excluded.status,
    released_by = excluded.released_by;

  if not exists (
    select 1 from public.sales_orders where receipt_number = 'SR-DEMO-0001'
  ) then
    insert into public.sales_orders (
      receipt_number,
      sale_date,
      customer_name,
      customer_contact,
      payment_method,
      subtotal,
      discount_type,
      discount_value,
      discount_amount,
      total_amount,
      amount_paid,
      change_amount,
      remarks,
      recorded_by,
      status
    )
    values (
      'SR-DEMO-0001',
      now() - interval '2 days',
      'Jason Eludo',
      '09171234567',
      'GCash',
      215,
      'Amount',
      15,
      15,
      200,
      200,
      0,
      'Demo multi-item farm sale.',
      demo_actor,
      'Completed'
    )
    returning id into order_id;

    insert into public.sales_order_items (
      sales_order_id,
      inventory_id,
      item_name_snapshot,
      unit_snapshot,
      quantity_sold,
      unit_price,
      line_total
    )
    values
      (order_id, malunggay_id, 'Malunggay', 'bundle', 5, 10, 50),
      (order_id, tomato_id, 'Tomato', 'kg', 1, 85, 85),
      (order_id, pechay_id, 'Pechay', 'kg', 1.142857, 70, 80);

    insert into public.inventory_transactions (
      inventory_id,
      transaction_type,
      quantity,
      remarks,
      performed_by,
      source,
      source_id
    )
    values
      (malunggay_id, 'OUT', 5, 'Demo receipt SR-DEMO-0001 sale deduction.', demo_actor, 'sale', order_id),
      (tomato_id, 'OUT', 1, 'Demo receipt SR-DEMO-0001 sale deduction.', demo_actor, 'sale', order_id),
      (pechay_id, 'OUT', 1.142857, 'Demo receipt SR-DEMO-0001 sale deduction.', demo_actor, 'sale', order_id);
  end if;

  insert into public.sales_transactions (
    inventory_id,
    quantity_sold,
    unit_price,
    total_amount,
    sale_date,
    customer_name,
    remarks,
    payment_method,
    transaction_reference,
    recorded_by,
    status
  )
  select
    okra_id,
    2,
    60,
    120,
    now() - interval '1 day',
    'Maria Santos',
    'Demo market distribution stock-out.',
    'GCash',
    'GCASH-DEMO-000124',
    demo_actor,
    'Completed'
  where not exists (
    select 1
    from public.sales_transactions
    where remarks = 'Demo market distribution stock-out.'
  );

  insert into public.inventory_transactions (
    inventory_id,
    transaction_type,
    quantity,
    remarks,
    performed_by,
    source
  )
  select
    okra_id,
    'OUT',
    2,
    'Demo market distribution stock-out.',
    demo_actor,
    'sale'
  where not exists (
    select 1
    from public.inventory_transactions
    where inventory_id = okra_id
      and remarks = 'Demo market distribution stock-out.'
  );

  insert into public.crops (
    crop_name,
    assigned_manager,
    planting_date,
    estimated_harvest,
    growth_stage,
    crop_status,
    maintenance_notes
  )
  select *
  from (
    values
      ('Pechay', demo_actor, current_date - 18, current_date + 22, 'Vegetative', 'Active', 'Demo crop: monitor moisture every morning.'),
      ('Tomato', demo_actor, current_date - 42, current_date + 28, 'Flowering', 'Needs Attention', 'Demo crop: check supports and pest signs.'),
      ('Lettuce', demo_actor, current_date - 31, current_date + 7, 'Harvest Ready', 'Harvest Ready', 'Demo crop: schedule harvest preparation.')
  ) as seed(crop_name, assigned_manager, planting_date, estimated_harvest, growth_stage, crop_status, maintenance_notes)
  where not exists (
    select 1
    from public.crops existing
    where existing.crop_name = seed.crop_name
      and existing.maintenance_notes = seed.maintenance_notes
  );

  insert into public.sensor_readings (
    soil_moisture,
    soil_temperature,
    humidity,
    environmental_temperature,
    recorded_at
  )
  values
    (63.5, 26.2, 74.1, 30.4, now() - interval '3 hours'),
    (60.8, 26.8, 71.3, 31.2, now() - interval '1 hour')
  on conflict do nothing;

  update public.robot_status
  set
    battery_level = 86,
    seed_level = 68,
    rover_status = 'Online',
    wifi_connected = true,
    bluetooth_connected = false,
    camera_connected = true,
    current_activity = 'Monitoring',
    speed = 0,
    emergency_stop = false,
    last_updated = now(),
    is_active = true
  where is_active = true;

  insert into public.robot_commands (
    command,
    payload,
    issued_by,
    status,
    executed_at
  )
  select *
  from (
    values
      ('GET_SENSOR_DATA', '{"source":"demo"}'::jsonb, demo_actor, 'Success', now() - interval '3 hours'),
      ('GET_ROBOT_STATUS', '{"source":"demo"}'::jsonb, demo_actor, 'Success', now() - interval '1 hour')
  ) as seed(command, payload, issued_by, status, executed_at)
  where not exists (
    select 1
    from public.robot_commands existing
    where existing.command = seed.command
      and existing.payload = seed.payload
  );

  insert into public.notifications (
    recipient_id,
    title,
    message,
    notification_type,
    is_read,
    action_route
  )
  select *
  from (
    values
      (demo_actor, 'Low stock watch', 'Tomato stock is being monitored for upcoming replenishment.', 'Inventory', false, '/inventory'),
      (demo_actor, 'Crop needs attention', 'Tomato crop needs inspection in the next farm round.', 'Crop Reminder', false, '/crops'),
      (demo_actor, 'Rover monitor updated', 'Demo rover status is online and ready for monitoring.', 'Robot Status', true, '/rover-monitor')
  ) as seed(recipient_id, title, message, notification_type, is_read, action_route)
  where not exists (
    select 1
    from public.notifications existing
    where existing.recipient_id = seed.recipient_id
      and existing.title = seed.title
  );

  insert into public.activity_logs (
    user_id,
    activity,
    description,
    module
  )
  values
    (demo_actor, 'Demo Data Seeded', 'SeedRover staging/demo data was inserted for web admin testing.', 'System'),
    (demo_actor, 'Demo Inventory Prepared', 'Vegetable stock records and movements are ready for testing.', 'Stocks')
  on conflict do nothing;
end;
$$;
