# SeedRover Database Schema

Version: 1.0

This document defines the official database schema for the SeedRover Supabase PostgreSQL database.

This schema is derived from:

- `database-specification.md`
- `feature-specification.md`
- `screen-specification.md`
- `hardware-protocol.md`

The schema must support the current application navigation:

- Dashboard
- Rover
- Crops
- Stocks
- Notifications
- Profile

The user-facing Stocks module maps to the database inventory tables.

---

# Schema Principles

- Use Supabase Auth for authentication.
- Store application user data in `profiles`.
- Reference `profiles.id` instead of `auth.users.id` from application tables.
- Use UUID primary keys.
- Use `timestamptz` for timestamps.
- Every application table must include `id`, `created_at`, and `updated_at`.
- Use Row Level Security on every application table.
- Use role-based access for managers and administrators.
- Use per-user permissions for Farm Staff.
- Keep the schema ready for future expansion without implementing future modules.

---

# Required Extensions

The database should enable:

```sql
create extension if not exists "pgcrypto";
```

`gen_random_uuid()` should be used for generated UUID primary keys.

---

# Shared Timestamp Rules

Every table should use:

- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

An `updated_at` trigger should update `updated_at` automatically before every row update.

---

# Roles

## `roles`

Stores the official user roles.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `role_name` | text | Required, unique |
| `description` | text | Optional |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Default rows:

- System Administrator
- Farm Planting Manager
- Farm Inventory Manager
- Farm Staff

---

# Profiles

## `profiles`

Stores application profile records for authenticated users.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, references `auth.users(id)` on delete cascade |
| `username` | text | Required, unique |
| `email` | text | Required |
| `full_name` | text | Required |
| `role_id` | uuid | Required, references `roles(id)` |
| `is_active` | boolean | Required, default `true` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Rules:

- Users cannot register themselves inside the application.
- Every authenticated user must have one profile.
- Inactive users must be blocked from application access.

---

# Permissions

Per-user permissions are required so Farm Staff accounts can receive configurable access.

## `permissions`

Defines all permission keys supported by the application.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `permission_key` | text | Required, unique |
| `module` | text | Required |
| `description` | text | Optional |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Default permission keys:

- `dashboard.view`
- `rover.view`
- `rover.control`
- `rover.camera.view`
- `rover.planting.control`
- `crops.view`
- `crops.manage`
- `stocks.view`
- `stocks.manage`
- `stocks.transactions.view`
- `notifications.view`
- `notifications.manage`
- `profile.view`
- `profile.manage_self`
- `users.view`
- `users.manage`
- `activity_logs.view`
- `settings.manage`

## `profile_permissions`

Assigns permissions directly to individual users.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `profile_id` | uuid | Required, references `profiles(id)` on delete cascade |
| `permission_id` | uuid | Required, references `permissions(id)` on delete cascade |
| `granted_by` | uuid | Optional, references `profiles(id)` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Constraints:

- Unique pair: `profile_id`, `permission_id`

Rules:

- System Administrator has full access by role and does not need explicit permission rows.
- Farm Planting Manager access is derived from role defaults.
- Farm Inventory Manager access is derived from role defaults.
- Farm Staff access is controlled through `profile_permissions`.
- The application should hide modules the user cannot access.

---

# Robot Status

## `robot_status`

Stores the current operational status of the SeedRover prototype.

The initial prototype supports one rover, so only one active status row should exist.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `battery_level` | integer | Required, 0 to 100 |
| `seed_level` | integer | Required, 0 to 100 |
| `rover_status` | text | Required |
| `wifi_connected` | boolean | Required, default `false` |
| `bluetooth_connected` | boolean | Required, default `false` |
| `camera_connected` | boolean | Required, default `false` |
| `current_activity` | text | Required, default `Idle` |
| `speed` | integer | Required, 0 to 100, default `0` |
| `emergency_stop` | boolean | Required, default `false` |
| `last_updated` | timestamptz | Required, default `now()` |
| `is_active` | boolean | Required, default `true` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Constraints:

- `battery_level between 0 and 100`
- `seed_level between 0 and 100`
- `speed between 0 and 100`
- Only one row may have `is_active = true`.

Recommended `rover_status` values:

- `Online`
- `Offline`
- `Idle`
- `Moving`
- `Planting`
- `Monitoring`
- `Error`

---

# Sensor Readings

## `sensor_readings`

Stores historical sensor readings from the rover.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `soil_moisture` | numeric(5,2) | Required, 0 to 100 |
| `soil_temperature` | numeric(5,2) | Required |
| `humidity` | numeric(5,2) | Required, 0 to 100 |
| `environmental_temperature` | numeric(5,2) | Required |
| `recorded_at` | timestamptz | Required, default `now()` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Constraints:

- `soil_moisture between 0 and 100`
- `humidity between 0 and 100`

---

# Planting Logs

## `planting_logs`

Stores every planting activity performed through SeedRover.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `operator_id` | uuid | Required, references `profiles(id)` |
| `crop_name` | text | Required |
| `planting_date` | date | Required |
| `planting_time` | time | Required |
| `planting_status` | text | Required |
| `notes` | text | Optional |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Allowed `planting_status` values:

- `Pending`
- `In Progress`
- `Completed`
- `Cancelled`

---

# Crops

## `crops`

Stores planted crop records for monitoring.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `planting_log_id` | uuid | Optional, references `planting_logs(id)` |
| `crop_name` | text | Required |
| `assigned_manager` | uuid | Optional, references `profiles(id)` |
| `planting_date` | date | Required |
| `estimated_harvest` | date | Optional |
| `growth_stage` | text | Required |
| `maintenance_notes` | text | Optional |
| `crop_status` | text | Required |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Allowed `growth_stage` values:

- `Seeded`
- `Germinating`
- `Vegetative`
- `Flowering`
- `Harvest Ready`
- `Completed`

Allowed `crop_status` values:

- `Active`
- `Needs Attention`
- `Harvest Ready`
- `Completed`
- `Cancelled`

---

# Stocks

The user-facing Stocks module is stored in the `inventory` and `inventory_transactions` tables.

## `inventory`

Stores available seeds, materials, tools, and supplies.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `item_name` | text | Required |
| `quantity` | numeric(12,2) | Required, default `0` |
| `unit` | text | Required |
| `minimum_quantity` | numeric(12,2) | Required, default `0` |
| `storage_location` | text | Optional |
| `category` | text | Required |
| `updated_by` | uuid | Optional, references `profiles(id)` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Constraints:

- `quantity >= 0`
- `minimum_quantity >= 0`

Allowed `category` values:

- `Seeds`
- `Tools`
- `Fertilizer`
- `Consumables`
- `Hardware`

## `inventory_transactions`

Stores stock movement history.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `inventory_id` | uuid | Required, references `inventory(id)` on delete cascade |
| `transaction_type` | text | Required |
| `quantity` | numeric(12,2) | Required |
| `remarks` | text | Optional |
| `performed_by` | uuid | Required, references `profiles(id)` |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Allowed `transaction_type` values:

- `IN`
- `OUT`
- `ADJUSTMENT`

Rules:

- `quantity` must be greater than 0.
- Every stock change must create an inventory transaction.
- Inventory quantity must never become negative.

---

# Notifications

## `notifications`

Stores application notifications.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `recipient_id` | uuid | Required, references `profiles(id)` on delete cascade |
| `title` | text | Required |
| `message` | text | Required |
| `notification_type` | text | Required |
| `is_read` | boolean | Required, default `false` |
| `action_route` | text | Optional |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Allowed `notification_type` values:

- `Battery`
- `Seed Level`
- `Inventory`
- `Robot Status`
- `Crop Reminder`
- `System`

Allowed route examples:

- `/dashboard`
- `/rover`
- `/crops`
- `/stocks`
- `/notifications`
- `/profile`

---

# Activity Logs

## `activity_logs`

Stores important system and user activities.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `user_id` | uuid | Optional, references `profiles(id)` |
| `activity` | text | Required |
| `description` | text | Optional |
| `module` | text | Required |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Rules:

- Logs are append-only from the application.
- Logs should be visible only to System Administrators.

Allowed `module` examples:

- `Authentication`
- `Dashboard`
- `Rover`
- `Crops`
- `Stocks`
- `Notifications`
- `Profile`
- `Users`
- `System`

---

# Robot Commands

## `robot_commands`

Stores commands sent to the rover.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | uuid | Primary key, default `gen_random_uuid()` |
| `command` | text | Required |
| `payload` | jsonb | Required, default `'{}'::jsonb` |
| `issued_by` | uuid | Required, references `profiles(id)` |
| `status` | text | Required |
| `executed_at` | timestamptz | Optional |
| `created_at` | timestamptz | Required |
| `updated_at` | timestamptz | Required |

Allowed `command` examples:

- `MOVE_FORWARD`
- `MOVE_BACKWARD`
- `TURN_LEFT`
- `TURN_RIGHT`
- `STOP`
- `EMERGENCY_STOP`
- `START_PLANTING`
- `PAUSE_PLANTING`
- `RESUME_PLANTING`
- `STOP_PLANTING`
- `START_CAMERA`
- `STOP_CAMERA`
- `REFRESH_CAMERA`
- `GET_SENSOR_DATA`
- `GET_ROBOT_STATUS`
- `GET_SEED_LEVEL`
- `PING`

Allowed `status` values:

- `Pending`
- `Sent`
- `Success`
- `Failed`
- `Invalid Command`
- `Busy`
- `Disconnected`

---

# Indexes

Required indexes:

- `profiles.username`
- `profiles.role_id`
- `permissions.permission_key`
- `permissions.module`
- `profile_permissions.profile_id`
- `profile_permissions.permission_id`
- `sensor_readings.recorded_at`
- `planting_logs.operator_id`
- `planting_logs.planting_date`
- `crops.crop_name`
- `crops.assigned_manager`
- `inventory.item_name`
- `inventory.category`
- `inventory_transactions.inventory_id`
- `inventory_transactions.performed_by`
- `notifications.recipient_id`
- `notifications.is_read`
- `activity_logs.user_id`
- `activity_logs.module`
- `robot_commands.issued_by`
- `robot_commands.status`

---

# Role Access Defaults

These defaults should be enforced in application logic and mirrored in RLS helper functions.

## System Administrator

Full access to all modules and all data.

## Farm Planting Manager

Default access:

- `dashboard.view`
- `rover.view`
- `rover.control`
- `rover.camera.view`
- `rover.planting.control`
- `crops.view`
- `crops.manage`
- `notifications.view`
- `profile.view`
- `profile.manage_self`

## Farm Inventory Manager

Default access:

- `dashboard.view`
- `stocks.view`
- `stocks.manage`
- `stocks.transactions.view`
- `notifications.view`
- `profile.view`
- `profile.manage_self`

## Farm Staff

No broad default module access except:

- `profile.view`
- `profile.manage_self`

All other Farm Staff access must come from `profile_permissions`.

---

# RLS Strategy

All application tables must have Row Level Security enabled.

Recommended helper functions:

- `current_profile_id()`
- `current_user_role_name()`
- `is_admin()`
- `has_permission(permission_key text)`

Rules:

- Anonymous users cannot access application data.
- Inactive users cannot access application data.
- System Administrators can access all data.
- Managers can access data for their assigned modules.
- Farm Staff can only access data allowed by their explicit per-user permissions.
- Users can view and update their own profile fields where appropriate.
- Users can view their own notifications.
- System Administrators can manage users, roles, permissions, and activity logs.

RLS implementation should avoid recursive policies by using `security definer` helper functions.

---

# Data Integrity Rules

- Create a profile row for each Supabase Auth user.
- Do not delete roles that are assigned to profiles.
- Do not delete permissions that are assigned to profiles.
- Do not allow negative stock quantities.
- Do not allow invalid battery, seed, humidity, speed, or soil moisture percentages.
- Do not expose raw hardware errors directly to users.
- Store raw command payloads in `robot_commands.payload` only when useful for auditing.
- Keep activity logs append-only from the application.

---

# Future Expansion Notes

This schema intentionally does not implement future modules, but it is prepared for:

- Multiple rovers
- LoRa communication
- GPS tracking
- Camera recordings
- Weather integration
- AI recommendations
- Predictive analytics

When multiple rover support is approved, add a `rovers` table and connect `robot_status`, `sensor_readings`, `robot_commands`, and camera-related records to `rovers.id`.

---

# Approval Rule

This schema document must be reviewed and approved before generating Supabase SQL migration files.
