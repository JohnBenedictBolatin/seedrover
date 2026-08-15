begin;

select plan(18);

select has_table('public', 'crop_profiles');
select has_table('public', 'crop_profile_versions');
select has_table('public', 'crop_activities');
select has_table('public', 'crop_tasks');
select has_table('public', 'farm_weather_settings');
select has_table('public', 'weather_forecasts');
select has_table('public', 'push_device_tokens');
select has_table('public', 'rover_calibrations');
select has_column('public', 'planting_logs', 'client_session_id');
select has_column('public', 'planting_logs', 'completed_drop_cycles');
select has_column('public', 'crops', 'planting_source');
select has_column('public', 'crops', 'harvest_window_start');
select has_column('public', 'sensor_readings', 'calibrated_value');
select has_function('public', 'record_rover_planting_session');
select has_function('public', 'record_crop_activity');
select has_function('public', 'register_push_device_token');
select is((select count(*)::integer from public.crop_profiles where profile_key in ('calamansi','sitaw','peanut')), 3, 'three supported care profiles are seeded');
select ok((select drop_spacing_cm = 10 and row_spacing_cm = 40 from public.crop_profiles where profile_key = 'peanut'), 'peanut spacing defaults are stored');

select * from finish();

rollback;
