begin;

select plan(5);

select has_column('public'::name, 'robot_commands'::name, 'correlation_id'::name, 'rover commands store correlation IDs');
select has_column('public'::name, 'robot_commands'::name, 'expires_at'::name, 'rover commands expire');
select has_table('public'::name, 'rover_control_leases'::name);
select has_function('public'::name, 'acquire_rover_control_lease'::name, array['text', 'integer']::name[]);
select has_function('public'::name, 'release_rover_control_lease'::name, array['text']::name[]);

select * from finish();

rollback;
