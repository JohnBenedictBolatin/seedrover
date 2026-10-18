begin;

select plan(24);

select has_table('public'::name, 'crop_profiles'::name);
select has_table('public'::name, 'crop_profile_versions'::name);
select has_table('public'::name, 'crop_activities'::name);
select has_table('public'::name, 'crop_tasks'::name);
select has_table('public'::name, 'farm_weather_settings'::name);
select has_table('public'::name, 'weather_forecasts'::name);
select has_table('public'::name, 'push_device_tokens'::name);
select has_table('public'::name, 'rover_calibrations'::name);
select has_column('public'::name, 'planting_logs'::name, 'client_session_id'::name, 'planting session identity is stored');
select has_column('public'::name, 'planting_logs'::name, 'completed_drop_cycles'::name, 'completed planting cycles are stored');
select has_column('public'::name, 'planting_logs'::name, 'distance_is_estimated'::name, 'estimated travel distance is labeled');
select has_column('public'::name, 'crops'::name, 'planting_source'::name, 'crop planting source is stored');
select has_column('public'::name, 'crops'::name, 'harvest_window_start'::name, 'crop harvest window is stored');
select has_column('public'::name, 'crops'::name, 'field_area_is_estimated'::name, 'estimated field area is labeled');
select has_column('public'::name, 'crops'::name, 'batch_code'::name, 'crop batch code is stored');
select has_column('public'::name, 'sensor_readings'::name, 'calibrated_value'::name, 'calibrated sensor reading is stored');
select has_column('public'::name, 'rover_calibrations'::name, 'seconds_per_meter'::name, 'rover speed calibration is stored');
select has_function('public'::name, 'record_rover_planting_session'::name);
select has_function('public'::name, 'record_crop_activity'::name);
select has_function('public'::name, 'register_push_device_token'::name);
select has_function('public'::name, 'next_crop_batch_code'::name);
select has_function('public'::name, 'record_manual_crop_planting_activity'::name);
select is((select count(*)::integer from public.crop_profiles where profile_key in ('calamansi','sitaw','peanut')), 3, 'three supported care profiles are seeded');
select ok((select drop_spacing_cm = 10 and row_spacing_cm = 40 from public.crop_profiles where profile_key = 'peanut'), 'peanut spacing defaults are stored');

select * from finish();

rollback;
