-- Battery percentage and onboard seed quantity are not measurable by the
-- current rover hardware. Remove them from the persisted status model and
-- from the notification type contract.
alter table public.robot_status
  drop column if exists battery_level,
  drop column if exists seed_level;

delete from public.notifications
where notification_type in ('Battery', 'Seed Level');

alter table public.notifications
  drop constraint if exists notifications_type_allowed;

alter table public.notifications
  add constraint notifications_type_allowed check (
    notification_type in (
      'Inventory',
      'Robot Status',
      'Crop Reminder',
      'System'
    )
  );

delete from public.robot_commands
where command = 'GET_SEED_LEVEL';

alter table public.robot_commands
  drop constraint if exists robot_commands_command_allowed;

alter table public.robot_commands
  add constraint robot_commands_command_allowed check (
    command in (
      'MOVE_FORWARD',
      'MOVE_BACKWARD',
      'TURN_LEFT',
      'TURN_RIGHT',
      'STOP',
      'EMERGENCY_STOP',
      'START_PLANTING',
      'PAUSE_PLANTING',
      'RESUME_PLANTING',
      'STOP_PLANTING',
      'START_CAMERA',
      'STOP_CAMERA',
      'REFRESH_CAMERA',
      'GET_SENSOR_DATA',
      'GET_ROBOT_STATUS',
      'PING'
    )
  );
