begin;

select plan(5);

select has_column('public', 'robot_commands', 'correlation_id');
select has_column('public', 'robot_commands', 'expires_at');
select has_table('public', 'rover_control_leases');
select has_function('public', 'acquire_rover_control_lease', array['text', 'integer']);
select has_function('public', 'release_rover_control_lease', array['text']);

select * from finish();

rollback;
