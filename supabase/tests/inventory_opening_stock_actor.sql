begin;

select plan(5);

select has_column(
  'public'::name,
  'inventory_stock_batches'::name,
  'recorded_by'::name,
  'opening stock batches retain the user who recorded them'
);

select ok(
  position('new.updated_by' in pg_get_functiondef('public.initialize_inventory_spoilage_batch()'::regprocedure)) > 0,
  'new opening stock snapshots the creating user'
);

select ok(
  position('batch.recorded_by' in pg_get_viewdef('public.inventory_movement_batch_details'::regclass)) > 0,
  'the shared movement history exposes the opening stock actor'
);

select ok(
  position('Stocked today' in pg_get_viewdef('public.inventory_movement_batch_details'::regclass)) > 0,
  'the updated history view preserves the historical stock date label'
);

select ok(
  position('origin_recorded_at' in pg_get_viewdef('public.inventory_movement_batch_details'::regclass)) > 0,
  'historical events preserve their latest recorded-time fallback'
);

select * from finish();
rollback;
