begin;

select plan(12);

select has_column('public', 'sensor_readings', 'provenance_status');
select has_column('public', 'sensor_readings', 'soil_moisture_calibrated');
select has_column('public', 'sensor_readings', 'calibration_version');
select has_column('public', 'sensor_readings', 'firmware_version');
select has_column('public', 'sensor_readings', 'soil_raw');
select ok(
  exists(select 1 from pg_constraint where conrelid='public.sensor_readings'::regclass and conname='sensor_readings_provenance_status_allowed'),
  'sensor provenance is constrained to known classifications'
);
select ok(
  exists(select 1 from pg_constraint where conrelid='public.sensor_readings'::regclass and conname='sensor_readings_verified_origin_check'),
  'verified readings require the hardware source and a rover capture identifier'
);
select ok(
  exists(select 1 from pg_constraint where conrelid='public.sensor_readings'::regclass and conname='sensor_readings_calibrated_moisture_metadata_check'),
  'calibrated moisture requires a calibration version and value'
);
select ok(
  exists(select 1 from pg_indexes where schemaname='public' and tablename='sensor_readings' and indexname='sensor_readings_verified_recent_idx'),
  'verified sensor readings have a recency index'
);
select ok(
  to_regprocedure('public.record_crop_sensor_check(uuid,uuid,integer,numeric,numeric,numeric,numeric,text,timestamp with time zone,boolean,text,text)') is not null,
  'crop sensor capture accepts timestamp, calibration, and firmware provenance'
);
select ok(
  position('soil_moisture_calibrated' in pg_get_functiondef('public.capture_rover_planting_sensor_snapshot()'::regprocedure)) > 0,
  'planting sensor snapshots retain calibration metadata'
);
select ok(
  position('pl.firmware_version is not null' in pg_get_functiondef('public.capture_rover_planting_sensor_snapshot()'::regprocedure)) > 0,
  'planting sensor snapshots distinguish firmware-backed reads'
);

select * from finish();
rollback;
