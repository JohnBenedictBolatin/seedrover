# SeedRover Feature Specification

Version: 1.0

This document defines the official functional specifications of every feature within the SeedRover mobile application.

Each feature describes:

- Purpose
- Authorized Roles
- Responsibilities
- Functional Requirements

No feature should be implemented outside this specification unless explicitly approved.

---

# Feature Development Principles

Every feature must:

- Follow Clean Architecture.
- Follow the UI Design System.
- Be modular.
- Be reusable.
- Support role-based permissions.
- Be scalable for future expansion.

Business logic should never exist inside UI widgets.

---

# Feature 1 — Authentication

Purpose

Provide secure access to the SeedRover system.

Authorized Roles

- System Administrator
- Farm Planting Manager
- Farm Inventory Manager
- Farm Staff

Functions

- Login
- Logout
- Session persistence
- Authentication validation
- Role retrieval
- Permission retrieval
- Automatic redirection
- Change password

Requirements

- Username/password authentication
- Supabase Auth
- Secure session management
- Role-based navigation

---

# Feature 2 — Dashboard

Purpose

Provide an overview of the rover and farm operations.

Authorized Roles

- All authenticated users

Functions

- Personalized greeting
- Rover overview
- Battery level
- Seed level
- Wi-Fi status
- Bluetooth status
- Camera status
- Current activity
- Live sensor summary
- Quick actions
- Recent activities
- Notifications preview

Requirements

- Dashboard should load within a few seconds.
- Display mock data until database integration.
- Update automatically when live data becomes available.

---

# Feature 3 — Rover Control

Purpose

Allow operators to manually control the SeedRover.

Authorized Roles

- System Administrator
- Farm Planting Manager
- Farm Staff (if permitted)

Functions

- Move forward
- Move backward
- Rotate left
- Rotate right
- Stop
- Speed indicator
- Emergency stop

Requirements

- Commands must be sent through the communication service.
- Controls must disable when the rover disconnects.

---

# Feature 4 — Planting Control

Purpose

Operate the automated seed planting mechanism.

Authorized Roles

- System Administrator
- Farm Planting Manager
- Farm Staff (if permitted)

Functions

- Start planting
- Pause planting
- Resume planting
- Stop planting
- View planting progress
- View planting status

Requirements

- Planting commands should never bypass the communication layer.
- Current planting status should always be visible.

---

# Feature 5 — Live Camera

Purpose

Provide live visual monitoring of the rover.

Authorized Roles

- System Administrator
- Farm Planting Manager
- Farm Staff (if permitted)

Functions

- Live video stream
- Fullscreen viewing
- Refresh stream
- Snapshot capture
- Connection recovery

Requirements

- Camera should reconnect automatically.
- Camera state should always be visible.

---

# Feature 6 — Sensor Monitoring

Purpose

Display environmental information collected by the rover.

Authorized Roles

- All authenticated users

Functions

- Soil moisture
- Soil temperature
- Environmental temperature
- Humidity
- Live updates

Requirements

- Sensor values should update independently.
- Use smooth animations for changing values.

---

# Feature 7 — Crop Monitoring

Purpose

Monitor planted crops throughout their lifecycle.

Authorized Roles

- System Administrator
- Farm Planting Manager
- Farm Staff (if permitted)

Functions

- View crop list
- View crop details
- Search crops
- Filter crops
- Growth stages
- Estimated harvest
- Maintenance notes
- Crop history

Requirements

- Display crop status clearly.
- Support future expansion.

---

# Feature 8 — Inventory Management

Purpose

Manage available seeds and farm inventory.

Authorized Roles

- System Administrator
- Farm Inventory Manager
- Farm Staff (if permitted)

Functions

- View inventory
- Add inventory
- Edit inventory
- Delete inventory
- Update quantities
- Set unit cost
- Set selling price
- View sales summary
- Search
- Filter
- Low-stock monitoring

Requirements

- Prevent negative inventory values.
- Log every inventory change.
- Pricing values must be optional but never negative when provided.

---

# Feature 9 — Inventory Transactions

Purpose

Track inventory movement.

Authorized Roles

- System Administrator
- Farm Inventory Manager

Functions

- Stock In
- Stock Out
- Adjustment
- Record Sale
- View history
- Search history

Requirements

- Every transaction must record the responsible user.
- Inventory should update automatically.
- Sales must deduct stock only through the approved database transaction flow.
- Sales must record quantity sold, unit price, total amount, sale date, optional customer name, optional remarks, and the responsible user.
- Sale recording must prevent negative inventory.

---

# Feature 10 — Notifications

Purpose

Provide system-wide notifications.

Authorized Roles

- All authenticated users

Functions

- View notifications
- Mark as read
- Notification history

Notification Types

- Battery
- Seed Level
- Robot Status
- Inventory
- Crop Reminder
- System Announcement

Requirements

- Notifications should support deep linking.
- Unread notifications should be clearly indicated.

---

# Feature 11 — User Management

Purpose

Manage user accounts.

Authorized Roles

- System Administrator

Functions

- Create accounts
- Generate usernames
- Generate temporary passwords
- Assign roles
- Reset passwords
- Activate accounts
- Deactivate accounts
- Edit user information

Requirements

- Username must remain unique.
- Password reset should require confirmation.

---

# Feature 12 — User Profile

Purpose

Allow users to manage their own account.

Authorized Roles

- All authenticated users

Functions

- View profile
- Edit profile
- Change password
- Logout

Requirements

- Users may only edit their own profile.

---

# Feature 13 — Activity Logs

Purpose

Record important system activities.

Authorized Roles

- System Administrator

Functions

- View logs
- Search logs
- Filter logs

Tracked Activities

- Login
- Logout
- Inventory updates
- Planting operations
- User management
- Communication events

Requirements

- Logs must be read-only.

---

# Feature 14 — Communication

Purpose

Manage communication between the application and the rover.

Authorized Roles

- Internal System

Current Communication

- Wi-Fi
- Bluetooth

Future Communication

- LoRa

Functions

- Connect
- Disconnect
- Heartbeat
- Send command
- Receive response
- Reconnect automatically

Requirements

- Communication should remain abstracted.
- Widgets must never communicate directly with the ESP32.

---

# Feature 15 — System Administration

Purpose

Provide application-wide management tools.

Authorized Roles

- System Administrator

Functions

- Manage users
- View activity logs
- Manage permissions
- Manage application settings

Requirements

- Restricted to administrators only.

---

# Role Permissions

## System Administrator

Full application access.

May access every feature.

---

## Farm Planting Manager

May access

- Dashboard
- Rover Control
- Planting Control
- Live Camera
- Sensor Monitoring
- Crop Monitoring
- Notifications
- Profile

---

## Farm Inventory Manager

May access

- Dashboard
- Inventory Management
- Inventory Transactions
- Notifications
- Profile

---

## Farm Staff

Access is configurable.

Permissions are assigned by the System Administrator.

Only assigned features should be visible.

---

# Future Features

The following features are intentionally excluded from the initial implementation.

- LoRa communication
- Multiple rover support
- GPS tracking
- Interactive farm map
- OTA firmware updates
- AI crop recommendations
- Weather integration
- Cloud analytics
- Predictive maintenance

The current architecture should support future implementation without requiring major restructuring.

---

# Development Rules for Codex

Implement only the features defined in this document.

Do not invent additional modules.

Do not merge unrelated features.

Every feature should remain modular.

Every feature should support role-based access.

Business logic must remain independent from the user interface.

Communication with the rover must always pass through the communication layer.

Follow the Roadmap before implementing features.

If this document conflicts with another specification, ask for clarification before proceeding.
