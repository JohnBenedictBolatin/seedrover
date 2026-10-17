begin;

select plan(18);

select has_table('public', 'crop_closures');
select has_column('public', 'crop_profiles', 'harvest_mode');
select has_column('public', 'crops', 'harvest_mode');
select has_column('public', 'crop_harvests', 'submission_payload');
select ok(exists(
  select 1 from pg_constraint where conrelid='public.crop_closures'::regclass
    and contype='u' and conkey=array[(select attnum from pg_attribute where attrelid='public.crop_closures'::regclass and attname='crop_id')]::smallint[]
), 'a crop can have one closure record');
select is((select harvest_mode from public.crop_profiles where profile_key='sitaw'), 'repeat', 'Sitaw supports repeat harvests');
select is((select harvest_mode from public.crop_profiles where profile_key='calamansi'), 'repeat', 'Calamansi supports repeat harvests');
select is((select harvest_mode from public.crop_profiles where profile_key='peanut'), 'single', 'Peanut keeps its single final harvest');
select ok(to_regprocedure('public.record_crop_harvest(jsonb)') is not null, 'the versioned repeat harvest entry point exists');
select ok(to_regprocedure('public.end_crop(jsonb)') is not null, 'crop ending has its own entry point');
select ok(to_regprocedure('public.get_crop_harvest_summaries(uuid[])') is not null, 'crop summaries can be loaded in one query');
select ok(to_regprocedure('public.get_crop_harvest_history(uuid,integer,integer)') is not null, 'harvest history is paginated');
select ok(to_regprocedure('public.get_crop_harvest_submission(text)') is not null, 'offline retries can reconcile by submission ID');
select ok(exists(select 1 from pg_trigger where tgrelid='public.crops'::regclass and tgname='crops_harvest_mode_immutable' and not tgisinternal), 'planted crop harvest mode cannot be changed');
select ok(exists(select 1 from pg_trigger where tgrelid='public.crops'::regclass and tgname='crops_guard_closure' and not tgisinternal), 'crop status changes remain guarded');
select ok(exists(select 1 from pg_trigger where tgrelid='public.crop_tasks'::regclass and tgname='crop_tasks_reject_after_closure' and not tgisinternal), 'background care cannot recreate tasks after closure');
select ok(position('Update the app to record repeat harvests' in pg_get_functiondef('public.harvest_crop_batch(uuid,numeric,timestamp with time zone,text,text)'::regprocedure)) > 0, 'legacy final harvest calls cannot silently adopt repeat semantics');
select ok(position('submission_payload' in pg_get_functiondef('public._record_crop_harvest_v2(jsonb)'::regprocedure)) > 0, 'retry payloads are compared before replay');

select * from finish();
rollback;
