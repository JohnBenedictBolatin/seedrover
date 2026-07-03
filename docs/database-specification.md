# SeedRover Database Specification

Version: 1.0

This document defines the official database architecture for the SeedRover mobile application.

All database structures, relationships, and constraints must follow this specification.

Generate the database using Supabase PostgreSQL.

The schema must be normalized to at least Third Normal Form (3NF).

Do not introduce additional tables unless explicitly approved.

---

# Database Design Principles

The database should be simple, scalable, and maintainable.

General Rules

- Use UUID as the primary key for every table.
- Use timestamptz for timestamps.
- Every table must contain:
  - id
  - created_at
  - updated_at
- Maintain proper foreign key relationships.
- Prevent unnecessary duplication of data.
- Follow PostgreSQL and Supabase best practices.
- Prepare the database for future expansion without implementing future features.

---

# Authentication

Authentication uses Supabase Auth.

Each authenticated account must have a corresponding profile record.

Application data should reference the profile table instead of auth.users whenever possible.

---

# Tables

## 1. profiles

Purpose

Stores user information for all authenticated users.

Fields

- id (UUID, references auth.users.id)
- username
- email
- full_name
- role_id
- is_active
- created_at
- updated_at

Relationships

- belongs to roles

Notes

Username must be unique.

---

## 2. roles

Purpose

Stores the official user roles.

Default Roles

- System Administrator
- Farm Planting Manager
- Farm Inventory Manager
- Farm Staff

Fields

- id
- role_name
- description
- created_at
- updated_at

Relationships

- one role
- many profiles

---

## 3. robot_status

Purpose

Stores the current operational status of the SeedRover prototype.

Since the project only supports one robotic unit, only one active record is required.

Fields

- id
- battery_level
- seed_level
- rover_status
- wifi_connected
- bluetooth_connected
- camera_connected
- current_activity
- speed
- emergency_stop
- last_updated

Examples

Battery Level

95%

Connection

Connected

Current Activity

Idle

Planting

Monitoring

Offline

---

## 4. sensor_readings

Purpose

Stores historical sensor readings collected by the robotic unit.

Fields

- id
- soil_moisture
- soil_temperature
- humidity
- environmental_temperature
- recorded_at
- created_at

Notes

Sensor values should be stored periodically for monitoring and historical reference.

---

## 5. planting_logs

Purpose

Stores every planting activity performed using SeedRover.

Fields

- id
- operator_id
- crop_name
- planting_date
- planting_time
- planting_status
- notes
- created_at
- updated_at

Relationships

- operator_id references profiles

Examples:

Pending

In Progress

Completed

Cancelled

---

## 6. crops

Purpose

Stores planted crop records for monitoring.

Fields

- id
- planting_log_id
- crop_name
- assigned_manager
- planting_date
- estimated_harvest
- growth_stage
- maintenance_notes
- crop_status
- created_at
- updated_at

Relationships

- planting_log_id references planting_logs
- references profiles

Examples

Growth Stage

Seeded

Germinating

Vegetative

Flowering

Harvest Ready

Completed

---

## 7. inventory

Purpose

Stores all available planting materials.

Fields

- id
- item_name
- quantity
- unit
- minimum_quantity
- storage_location
- updated_by
- created_at
- updated_at
- category

Relationships

- updated_by references profiles

Examples

Item

Peanut Seeds

Sitaw Seeds

Calamansi Seeds

Examples

Seeds

Tools

Fertilizer

Consumables

Hardware

---

## 8. inventory_transactions

Purpose

Stores inventory movement history.

Fields

- id
- inventory_id
- transaction_type
- quantity
- remarks
- performed_by
- created_at

Relationships

- inventory_id references inventory
- performed_by references profiles

Transaction Types

- IN
- OUT
- ADJUSTMENT

---

## 9. notifications

Purpose

Stores notifications displayed inside the application.

Fields

- id
- recipient_id
- title
- message
- notification_type
- is_read
- created_at
- action_route

Relationships

- recipient_id references profiles

Notification Types

- Battery
- Seed Level
- Inventory
- Robot Status
- Crop Reminder
- System

Example of action route:

/dashboard

/inventory

/robot

/profile
---

## 10. activity_logs

Purpose

Stores important user and system activities.

Fields

- id
- user_id
- activity
- description
- created_at
- module

Relationships

- user_id references profiles

Examples

User Login

Inventory Updated

Planting Completed

User Created

Password Reset

Robot Connected

Robot Disconnected

Example module:
Inventory

Robot

Authentication

Planting

Users

## 11. robot_commands

Purpose

Stores commands sent to the rover.

Fields

- id

- command

- issued_by

- status

- executed_at

- created_at

Examples

MOVE_FORWARD

TURN_LEFT

STOP

START_PLANTING

RETURN_HOME

---

# Database Relationships

roles (1)
    │
    └───────────< profiles (Many)

profiles (1)
    │
    └───────────< planting_logs (Many)

planting_logs (1)
    │
    └───────────< crops (Many)

inventory (1)
    │
    └───────────< inventory_transactions (Many)

profiles (1)
    │
    ├───────────< notifications
    ├───────────< activity_logs
    ├───────────< inventory_transactions
    └───────────< planting_logs

---

# User Role Responsibilities

## System Administrator

Permissions

- Full system access
- Create user accounts
- Generate usernames
- Generate temporary passwords
- Reset passwords
- Edit user information
- Activate or deactivate accounts
- Assign user roles
- View all modules
- Manage system settings

---

## Farm Planting Manager

Permissions

- Dashboard
- Plant Module
- Crop Monitoring
- Sensor Monitoring
- Planting Logs
- Notifications

---

## Farm Inventory Manager

Permissions

- Dashboard
- Inventory Management
- Inventory Transactions
- Notifications

---

## Farm Staff

Permissions

Farm Staff access depends on the role assigned by the System Administrator.

The application should restrict visible pages according to the assigned role.

Farm Staff should only access modules necessary for their assigned responsibilities.

---

# Row Level Security (RLS)

Implement Row Level Security for all tables.

Requirements

- Anonymous users cannot access data.
- Authenticated users must log in before accessing the application.
- Users may only access information permitted by their assigned role.
- System Administrators have unrestricted access.
- Managers should only access records related to their assigned module.
- Farm Staff should only access records required for their assigned permissions.
- Future permission expansion should not require restructuring the database.
---

# Constraints

Implement the following constraints.

Profiles

- Username must be unique.

Roles

- Role name must be unique.

Robot Status

- Battery level must be between 0 and 100.
- Seed level must be between 0 and 100.

Sensor Readings

- Soil moisture must be between 0 and 100.

Inventory

- Quantity cannot be negative.

Notifications

- is_read defaults to false.

---

# Database Indexes

Create indexes for the following fields.

profiles

- username
- role_id

sensor_readings

- recorded_at

planting_logs

- planting_date

crops

- crop_name

inventory

- item_name

notifications

- recipient_id

activity_logs

- user_id

---

# Future Expansion

The database architecture should be prepared for future features without implementing them now.

Future Features

- Multiple robotic units
- Communication history
- GPS location tracking
- ESP32 Camera recordings
- AI crop recommendations
- Weather API integration
- Predictive analytics

These features should NOT be implemented during the initial development.

---

# Instructions for Codex

Generate the following automatically.

- SQL migration files
- PostgreSQL schema
- Foreign key relationships
- Constraints
- Indexes
- Row Level Security policies
- Seed data for default roles

Use Supabase best practices.

Do not generate Flutter code until the database schema has been completed and reviewed.

Avoid unnecessary complexity.

Prioritize readability, maintainability, and scalability.