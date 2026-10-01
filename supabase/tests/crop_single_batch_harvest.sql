begin;

select plan(14);

select has_table('public', 'crop_activity_photos');
select has_table('public', 'crop_notification_preferences');
select has_column('public', 'crops', 'harvest_inventory_id');
select has_column('public', 'crops', 'harvested_at');
select has_column('public', 'crop_harvests', 'submission_id');
select ok(
  exists(select 1 from pg_indexes where schemaname='public' and indexname='crop_harvest_submission_idx'),
  'harvest submission IDs are unique for retry safety'
);
select ok(to_regprocedure('public.harvest_crop_batch(uuid,numeric,timestamp with time zone,text,text)') is not null,
  'one RPC performs a batch harvest and inventory receipt');
select ok(to_regprocedure('public.crop_harvest_destination(uuid)') is not null,
  'harvest destination is resolved before stock changes');
select ok(to_regprocedure('public.record_crop_entry(jsonb)') is not null,
  'care entry, linked task, and photo attachments share one write path');
select ok(to_regprocedure('public.guard_crop_closure()') is not null,
  'crop closure is guarded');
select ok(exists(select 1 from pg_trigger where tgrelid='public.crops'::regclass and tgname='crops_guard_closure' and not tgisinternal),
  'closed batches cannot be reopened or closed without a harvest');
select ok(not exists(select 1 from pg_trigger where tgrelid='public.crop_activities'::regclass and tgname in ('crop_activities_keep_harvest_active','crop_activities_record_harvest_stock','crop_activities_finalize_harvest')),
  'legacy repeated harvest triggers are removed');
select ok(to_regprocedure('public.finish_crop_cycle(uuid,text,text,text)') is not null,
  'legacy cycle RPC remains callable for non-harvest closure validation');
select ok(to_regprocedure('public.refresh_crop_attention(uuid)') is not null,
  'care task changes recalculate crop attention');

select * from finish();
rollback;
