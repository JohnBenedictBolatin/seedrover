create extension if not exists "pgcrypto";

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  role_name text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  email text not null,
  full_name text not null,
  role_id uuid not null references public.roles(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  permission_key text not null unique,
  module text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profile_permissions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_permissions_profile_permission_unique unique (
    profile_id,
    permission_id
  )
);

create table public.robot_status (
  id uuid primary key default gen_random_uuid(),
  battery_level integer not null default 0,
  seed_level integer not null default 0,
  rover_status text not null default 'Offline',
  wifi_connected boolean not null default false,
  bluetooth_connected boolean not null default false,
  camera_connected boolean not null default false,
  current_activity text not null default 'Idle',
  speed integer not null default 0,
  emergency_stop boolean not null default false,
  last_updated timestamptz not null default now(),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint robot_status_battery_level_range check (
    battery_level between 0 and 100
  ),
  constraint robot_status_seed_level_range check (
    seed_level between 0 and 100
  ),
  constraint robot_status_speed_range check (
    speed between 0 and 100
  ),
  constraint robot_status_rover_status_allowed check (
    rover_status in (
      'Online',
      'Offline',
      'Idle',
      'Moving',
      'Planting',
      'Monitoring',
      'Error'
    )
  )
);

create unique index robot_status_one_active_idx
  on public.robot_status(is_active)
  where is_active;

create table public.sensor_readings (
  id uuid primary key default gen_random_uuid(),
  soil_moisture numeric(5, 2) not null,
  soil_temperature numeric(5, 2) not null,
  humidity numeric(5, 2) not null,
  environmental_temperature numeric(5, 2) not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sensor_readings_soil_moisture_range check (
    soil_moisture between 0 and 100
  ),
  constraint sensor_readings_humidity_range check (
    humidity between 0 and 100
  )
);

create table public.planting_logs (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.profiles(id) on delete restrict,
  crop_name text not null,
  planting_date date not null,
  planting_time time not null,
  planting_status text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint planting_logs_status_allowed check (
    planting_status in (
      'Pending',
      'In Progress',
      'Completed',
      'Cancelled'
    )
  )
);

create table public.crops (
  id uuid primary key default gen_random_uuid(),
  planting_log_id uuid references public.planting_logs(id) on delete set null,
  crop_name text not null,
  assigned_manager uuid references public.profiles(id) on delete set null,
  planting_date date not null,
  estimated_harvest date,
  growth_stage text not null,
  maintenance_notes text,
  crop_status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crops_growth_stage_allowed check (
    growth_stage in (
      'Seeded',
      'Germinating',
      'Vegetative',
      'Flowering',
      'Harvest Ready',
      'Completed'
    )
  ),
  constraint crops_status_allowed check (
    crop_status in (
      'Active',
      'Needs Attention',
      'Harvest Ready',
      'Completed',
      'Cancelled'
    )
  )
);

create table public.inventory (
  id uuid primary key default gen_random_uuid(),
  item_name text not null,
  quantity numeric(12, 2) not null default 0,
  unit text not null,
  minimum_quantity numeric(12, 2) not null default 0,
  storage_location text,
  category text not null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_quantity_non_negative check (quantity >= 0),
  constraint inventory_minimum_quantity_non_negative check (
    minimum_quantity >= 0
  ),
  constraint inventory_category_allowed check (
    category in (
      'Seeds',
      'Tools',
      'Fertilizer',
      'Consumables',
      'Hardware'
    )
  )
);

create table public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.inventory(id) on delete cascade,
  transaction_type text not null,
  quantity numeric(12, 2) not null,
  remarks text,
  performed_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_transactions_quantity_positive check (quantity > 0),
  constraint inventory_transactions_type_allowed check (
    transaction_type in (
      'IN',
      'OUT',
      'ADJUSTMENT'
    )
  )
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  notification_type text not null,
  is_read boolean not null default false,
  action_route text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_type_allowed check (
    notification_type in (
      'Battery',
      'Seed Level',
      'Inventory',
      'Robot Status',
      'Crop Reminder',
      'System'
    )
  )
);

create table public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  activity text not null,
  description text,
  module text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint activity_logs_module_allowed check (
    module in (
      'Authentication',
      'Dashboard',
      'Rover',
      'Crops',
      'Stocks',
      'Notifications',
      'Profile',
      'Users',
      'System'
    )
  )
);

create table public.robot_commands (
  id uuid primary key default gen_random_uuid(),
  command text not null,
  payload jsonb not null default '{}'::jsonb,
  issued_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'Pending',
  executed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint robot_commands_command_allowed check (
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
      'GET_SEED_LEVEL',
      'PING'
    )
  ),
  constraint robot_commands_status_allowed check (
    status in (
      'Pending',
      'Sent',
      'Success',
      'Failed',
      'Invalid Command',
      'Busy',
      'Disconnected'
    )
  )
);

create index profiles_username_idx on public.profiles(username);
create index profiles_role_id_idx on public.profiles(role_id);
create index permissions_permission_key_idx on public.permissions(permission_key);
create index permissions_module_idx on public.permissions(module);
create index profile_permissions_profile_id_idx
  on public.profile_permissions(profile_id);
create index profile_permissions_permission_id_idx
  on public.profile_permissions(permission_id);
create index sensor_readings_recorded_at_idx
  on public.sensor_readings(recorded_at);
create index planting_logs_operator_id_idx
  on public.planting_logs(operator_id);
create index planting_logs_planting_date_idx
  on public.planting_logs(planting_date);
create index crops_crop_name_idx on public.crops(crop_name);
create index crops_assigned_manager_idx on public.crops(assigned_manager);
create index inventory_item_name_idx on public.inventory(item_name);
create index inventory_category_idx on public.inventory(category);
create index inventory_transactions_inventory_id_idx
  on public.inventory_transactions(inventory_id);
create index inventory_transactions_performed_by_idx
  on public.inventory_transactions(performed_by);
create index notifications_recipient_id_idx
  on public.notifications(recipient_id);
create index notifications_is_read_idx on public.notifications(is_read);
create index activity_logs_user_id_idx on public.activity_logs(user_id);
create index activity_logs_module_idx on public.activity_logs(module);
create index robot_commands_issued_by_idx on public.robot_commands(issued_by);
create index robot_commands_status_idx on public.robot_commands(status);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger roles_set_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger permissions_set_updated_at
  before update on public.permissions
  for each row execute function public.set_updated_at();

create trigger profile_permissions_set_updated_at
  before update on public.profile_permissions
  for each row execute function public.set_updated_at();

create trigger robot_status_set_updated_at
  before update on public.robot_status
  for each row execute function public.set_updated_at();

create trigger sensor_readings_set_updated_at
  before update on public.sensor_readings
  for each row execute function public.set_updated_at();

create trigger planting_logs_set_updated_at
  before update on public.planting_logs
  for each row execute function public.set_updated_at();

create trigger crops_set_updated_at
  before update on public.crops
  for each row execute function public.set_updated_at();

create trigger inventory_set_updated_at
  before update on public.inventory
  for each row execute function public.set_updated_at();

create trigger inventory_transactions_set_updated_at
  before update on public.inventory_transactions
  for each row execute function public.set_updated_at();

create trigger notifications_set_updated_at
  before update on public.notifications
  for each row execute function public.set_updated_at();

create trigger activity_logs_set_updated_at
  before update on public.activity_logs
  for each row execute function public.set_updated_at();

create trigger robot_commands_set_updated_at
  before update on public.robot_commands
  for each row execute function public.set_updated_at();

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.role_id is distinct from old.role_id then
    raise exception 'Only administrators can change user roles.';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'Only administrators can change account status.';
  end if;

  return new;
end;
$$;

create trigger profiles_protect_security_fields
  before update on public.profiles
  for each row execute function public.protect_profile_security_fields();

create or replace function public.apply_inventory_transaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.transaction_type = 'IN' then
    update public.inventory
    set
      quantity = quantity + new.quantity,
      updated_by = new.performed_by
    where id = new.inventory_id;
  elsif new.transaction_type = 'OUT' then
    update public.inventory
    set
      quantity = quantity - new.quantity,
      updated_by = new.performed_by
    where id = new.inventory_id
      and quantity >= new.quantity;

    if not found then
      raise exception 'Insufficient stock for inventory transaction.';
    end if;
  elsif new.transaction_type = 'ADJUSTMENT' then
    update public.inventory
    set
      quantity = new.quantity,
      updated_by = new.performed_by
    where id = new.inventory_id;
  end if;

  return new;
end;
$$;

create trigger inventory_transactions_apply_quantity
  before insert on public.inventory_transactions
  for each row execute function public.apply_inventory_transaction();

insert into public.roles (role_name, description)
values
  ('System Administrator', 'Full system access and administration.'),
  ('Farm Planting Manager', 'Manages rover operation, planting, crops, and sensors.'),
  ('Farm Inventory Manager', 'Manages stocks, stock movement, and inventory reports.'),
  ('Farm Staff', 'Configurable per-user access assigned by administrators.')
on conflict (role_name) do update
set
  description = excluded.description,
  updated_at = now();

insert into public.permissions (permission_key, module, description)
values
  ('dashboard.view', 'Dashboard', 'View the dashboard.'),
  ('rover.view', 'Rover', 'View rover status and telemetry.'),
  ('rover.control', 'Rover', 'Control rover movement.'),
  ('rover.camera.view', 'Rover', 'View the rover camera.'),
  ('rover.planting.control', 'Rover', 'Control planting operations.'),
  ('crops.view', 'Crops', 'View crop records.'),
  ('crops.manage', 'Crops', 'Create and update crop records.'),
  ('stocks.view', 'Stocks', 'View stock records.'),
  ('stocks.manage', 'Stocks', 'Create and update stock records.'),
  ('stocks.transactions.view', 'Stocks', 'View stock transaction history.'),
  ('notifications.view', 'Notifications', 'View notifications.'),
  ('notifications.manage', 'Notifications', 'Create and manage notifications.'),
  ('profile.view', 'Profile', 'View own profile.'),
  ('profile.manage_self', 'Profile', 'Update own profile information.'),
  ('users.view', 'Users', 'View user accounts.'),
  ('users.manage', 'Users', 'Manage user accounts and permissions.'),
  ('activity_logs.view', 'System', 'View system activity logs.'),
  ('settings.manage', 'System', 'Manage application settings.')
on conflict (permission_key) do update
set
  module = excluded.module,
  description = excluded.description,
  updated_at = now();

insert into public.robot_status (
  battery_level,
  seed_level,
  rover_status,
  current_activity,
  is_active
)
values (0, 0, 'Offline', 'Idle', true)
on conflict do nothing;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  staff_role_id uuid;
begin
  select id into staff_role_id
  from public.roles
  where role_name = 'Farm Staff'
  limit 1;

  insert into public.profiles (
    id,
    username,
    email,
    full_name,
    role_id
  )
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'username', ''),
      'user_' || replace(left(new.id::text, 8), '-', '')
    ),
    coalesce(new.email, ''),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      'SeedRover User'
    ),
    staff_role_id
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select auth.uid();
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active
  );
$$;

create or replace function public.current_user_role_name()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select r.role_name
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.id = auth.uid()
    and p.is_active
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_user_role_name() = 'System Administrator';
$$;

create or replace function public.has_permission(requested_permission text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  with current_user_context as (
    select p.id, r.role_name
    from public.profiles p
    join public.roles r on r.id = p.role_id
    where p.id = auth.uid()
      and p.is_active
    limit 1
  )
  select exists (
    select 1
    from current_user_context c
    where c.role_name = 'System Administrator'
      or (
        c.role_name = 'Farm Planting Manager'
        and requested_permission = any(array[
          'dashboard.view',
          'rover.view',
          'rover.control',
          'rover.camera.view',
          'rover.planting.control',
          'crops.view',
          'crops.manage',
          'notifications.view',
          'profile.view',
          'profile.manage_self'
        ])
      )
      or (
        c.role_name = 'Farm Inventory Manager'
        and requested_permission = any(array[
          'dashboard.view',
          'stocks.view',
          'stocks.manage',
          'stocks.transactions.view',
          'notifications.view',
          'profile.view',
          'profile.manage_self'
        ])
      )
      or requested_permission = any(array[
        'profile.view',
        'profile.manage_self'
      ])
      or exists (
        select 1
        from public.profile_permissions pp
        join public.permissions perm on perm.id = pp.permission_id
        where pp.profile_id = c.id
          and perm.permission_key = requested_permission
      )
  );
$$;

alter table public.roles enable row level security;
alter table public.profiles enable row level security;
alter table public.permissions enable row level security;
alter table public.profile_permissions enable row level security;
alter table public.robot_status enable row level security;
alter table public.sensor_readings enable row level security;
alter table public.planting_logs enable row level security;
alter table public.crops enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.notifications enable row level security;
alter table public.activity_logs enable row level security;
alter table public.robot_commands enable row level security;

create policy roles_select_authenticated
  on public.roles
  for select
  to authenticated
  using (public.is_active_user());

create policy roles_admin_write
  on public.roles
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy profiles_select_own_or_allowed
  on public.profiles
  for select
  to authenticated
  using (
    public.is_admin()
    or id = auth.uid()
    or public.has_permission('users.view')
  );

create policy profiles_update_own_or_admin
  on public.profiles
  for update
  to authenticated
  using (
    public.is_admin()
    or id = auth.uid()
  )
  with check (
    public.is_admin()
    or id = auth.uid()
  );

create policy profiles_admin_insert
  on public.profiles
  for insert
  to authenticated
  with check (public.is_admin());

create policy profiles_admin_delete
  on public.profiles
  for delete
  to authenticated
  using (public.is_admin());

create policy permissions_select_authenticated
  on public.permissions
  for select
  to authenticated
  using (public.is_active_user());

create policy permissions_admin_write
  on public.permissions
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy profile_permissions_select_own_or_admin
  on public.profile_permissions
  for select
  to authenticated
  using (
    public.is_admin()
    or profile_id = auth.uid()
    or public.has_permission('users.view')
  );

create policy profile_permissions_admin_insert
  on public.profile_permissions
  for insert
  to authenticated
  with check (public.is_admin());

create policy profile_permissions_admin_update
  on public.profile_permissions
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy profile_permissions_admin_delete
  on public.profile_permissions
  for delete
  to authenticated
  using (public.is_admin());

create policy robot_status_select_allowed
  on public.robot_status
  for select
  to authenticated
  using (
    public.has_permission('dashboard.view')
    or public.has_permission('rover.view')
  );

create policy robot_status_write_allowed
  on public.robot_status
  for all
  to authenticated
  using (
    public.is_admin()
    or public.has_permission('rover.control')
  )
  with check (
    public.is_admin()
    or public.has_permission('rover.control')
  );

create policy sensor_readings_select_allowed
  on public.sensor_readings
  for select
  to authenticated
  using (
    public.has_permission('dashboard.view')
    or public.has_permission('rover.view')
    or public.has_permission('crops.view')
  );

create policy sensor_readings_insert_allowed
  on public.sensor_readings
  for insert
  to authenticated
  with check (
    public.is_admin()
    or public.has_permission('rover.control')
  );

create policy planting_logs_select_allowed
  on public.planting_logs
  for select
  to authenticated
  using (
    public.has_permission('rover.planting.control')
    or public.has_permission('crops.view')
  );

create policy planting_logs_insert_allowed
  on public.planting_logs
  for insert
  to authenticated
  with check (
    operator_id = auth.uid()
    and public.has_permission('rover.planting.control')
  );

create policy planting_logs_update_allowed
  on public.planting_logs
  for update
  to authenticated
  using (
    public.is_admin()
    or public.has_permission('rover.planting.control')
  )
  with check (
    public.is_admin()
    or public.has_permission('rover.planting.control')
  );

create policy planting_logs_delete_admin
  on public.planting_logs
  for delete
  to authenticated
  using (public.is_admin());

create policy crops_select_allowed
  on public.crops
  for select
  to authenticated
  using (public.has_permission('crops.view'));

create policy crops_insert_allowed
  on public.crops
  for insert
  to authenticated
  with check (public.has_permission('crops.manage'));

create policy crops_update_allowed
  on public.crops
  for update
  to authenticated
  using (public.has_permission('crops.manage'))
  with check (public.has_permission('crops.manage'));

create policy crops_delete_admin
  on public.crops
  for delete
  to authenticated
  using (public.is_admin());

create policy inventory_select_allowed
  on public.inventory
  for select
  to authenticated
  using (public.has_permission('stocks.view'));

create policy inventory_insert_allowed
  on public.inventory
  for insert
  to authenticated
  with check (public.has_permission('stocks.manage'));

create policy inventory_update_allowed
  on public.inventory
  for update
  to authenticated
  using (public.has_permission('stocks.manage'))
  with check (public.has_permission('stocks.manage'));

create policy inventory_delete_admin
  on public.inventory
  for delete
  to authenticated
  using (public.is_admin());

create policy inventory_transactions_select_allowed
  on public.inventory_transactions
  for select
  to authenticated
  using (
    public.has_permission('stocks.transactions.view')
    or public.has_permission('stocks.view')
  );

create policy inventory_transactions_insert_allowed
  on public.inventory_transactions
  for insert
  to authenticated
  with check (
    performed_by = auth.uid()
    and public.has_permission('stocks.manage')
  );

create policy inventory_transactions_update_admin
  on public.inventory_transactions
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy inventory_transactions_delete_admin
  on public.inventory_transactions
  for delete
  to authenticated
  using (public.is_admin());

create policy notifications_select_own_or_admin
  on public.notifications
  for select
  to authenticated
  using (
    public.is_admin()
    or recipient_id = auth.uid()
  );

create policy notifications_insert_allowed
  on public.notifications
  for insert
  to authenticated
  with check (
    public.is_admin()
    or public.has_permission('notifications.manage')
  );

create policy notifications_update_own_or_admin
  on public.notifications
  for update
  to authenticated
  using (
    public.is_admin()
    or recipient_id = auth.uid()
  )
  with check (
    public.is_admin()
    or recipient_id = auth.uid()
  );

create policy notifications_delete_admin
  on public.notifications
  for delete
  to authenticated
  using (public.is_admin());

create policy activity_logs_select_admin
  on public.activity_logs
  for select
  to authenticated
  using (
    public.is_admin()
    or public.has_permission('activity_logs.view')
  );

create policy activity_logs_insert_authenticated
  on public.activity_logs
  for insert
  to authenticated
  with check (
    public.is_active_user()
    and (
      user_id is null
      or user_id = auth.uid()
      or public.is_admin()
    )
  );

create policy robot_commands_select_allowed
  on public.robot_commands
  for select
  to authenticated
  using (
    public.is_admin()
    or issued_by = auth.uid()
    or public.has_permission('rover.view')
  );

create policy robot_commands_insert_allowed
  on public.robot_commands
  for insert
  to authenticated
  with check (
    issued_by = auth.uid()
    and public.has_permission('rover.control')
  );

create policy robot_commands_update_allowed
  on public.robot_commands
  for update
  to authenticated
  using (
    public.is_admin()
    or public.has_permission('rover.control')
  )
  with check (
    public.is_admin()
    or public.has_permission('rover.control')
  );

create policy robot_commands_delete_admin
  on public.robot_commands
  for delete
  to authenticated
  using (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
