# SeedRover Development Roadmap

Version: 1.0

This document defines the official development roadmap of the SeedRover mobile application.

All development should strictly follow the order outlined below.

Do not skip phases unless explicitly instructed by the project owner.

Each phase must be completed, tested, documented, and reviewed before proceeding to the next phase.

---

# Current Development Status

Current Phase

Phase 1 — Project Foundation

Completed

✓ Flutter project initialized

✓ Git repository initialized

✓ Project architecture planned

✓ UI Design System completed

✓ Roadmap completed

✓ Supabase project created

✓ Android emulator configured

✓ Development environment configured

Currently Working On

• Finalizing project specifications
• Designing the Supabase database schema
• Preparing development documentation for AI-assisted implementation

Next Tasks

• Finalize database schema
• Configure Supabase authentication
• Establish project architecture
• Begin Phase 1 implementation

---

# Phase 1 — Project Foundation

Goal

Establish a scalable, maintainable Flutter project architecture.

Tasks

- Configure Flutter project.
- Configure Riverpod.
- Configure GoRouter.
- Configure Supabase.
- Configure environment variables.
- Configure application themes.
- Configure typography.
- Configure global color palette.
- Configure reusable widgets.
- Configure routing.
- Establish folder structure.
- Configure dependency injection.
- Prepare project documentation.
- Configure communication layer abstraction.
- Configure service layer.
- Configure repository layer.
- Configure global error handling.
- Configure application logging.

Deliverables

✓ Clean project architecture

✓ Build succeeds

✓ No business logic yet

---

# Phase 2 — Authentication & Role-Based Access Control

Goal

Implement secure authentication and dynamic role-based access control.

Tasks

- Login page.
- Username/password authentication.
- Session persistence.
- Logout.
- Retrieve authenticated user.
- Retrieve assigned role.
- Redirect users according to role.
- Restrict access based on permissions.

System Roles

## System Administrator

Responsibilities

- Full system access.
- Create user accounts.
- Generate usernames.
- Generate temporary passwords.
- Reset passwords.
- Edit user information.
- Activate or deactivate accounts.
- Assign user roles.
- Manage permissions.
- Access all modules.
- Manage application settings.
- View system logs.

---

## Farm Planting Manager

Responsibilities

- Access planting module.
- Operate the robotic unit.
- Monitor robot status.
- View sensor data.
- Monitor crops.
- Manage planting schedules.
- Review planting logs.
- Generate planting reports.
- Supervise planting staff.

---

## Farm Inventory Manager

Responsibilities

- Access inventory module.
- Manage seed inventory.
- Update stock quantities.
- Record stock movement.
- Monitor inventory history.
- Receive low-stock alerts.
- Generate inventory reports.
- Supervise inventory staff.

---

## Farm Staff

Responsibilities

Farm Staff permissions are configurable.

Access is determined by the System Administrator and the assigned manager.

Possible permissions include:

- Operate the rover
- View sensor readings
- Record planting logs
- Update inventory
- View assigned crops
- Receive notifications
- Complete assigned tasks

Farm Staff should only see features that have been explicitly assigned to them.

Deliverables

✓ Secure authentication

✓ Dynamic role-based navigation

✓ Permission-based access control

---

# Phase 3 — Dashboard

Goal

Develop the application's operational dashboard.

Tasks

- Personalized greeting.
- Rover status overview.
- Battery status.
- Seed level.
- Wi-Fi/Bluetooth connection status.
- Camera connection status.
- Live sensor summary.
- Current rover activity.
- Quick actions.
- Recent activities.
- Notification preview.
- Assigned tasks.

Initially use mock data.

Deliverables

✓ Dashboard UI completed

✓ Responsive layout

---

# Phase 4 — Plant Module

Goal

Develop the rover operation interface.

Tasks

- Manual rover movement controls.
- Virtual joystick.
- Directional buttons.
- Speed control.
- Emergency stop.
- Live battery monitoring.
- Live seed level monitoring.
- Live soil moisture readings.
- Live soil temperature.
- Live environmental temperature.
- Live humidity.
- Robot activity status.
- Wi-Fi/Bluetooth connection management.
- Camera preview widget.
- Navigation to live camera screen.

Initially use simulated data.

Deliverables

✓ Complete rover control interface

---

# Phase 5 — Crop Monitoring

Goal

Develop crop management features.

Tasks

- Crop list.
- Crop details.
- Growth stages.
- Estimated harvest.
- Maintenance reminders.
- Crop history.
- Calendar integration.
- Search.
- Filtering.
- Planting history.
- Crop progress timeline.

Deliverables

✓ Crop monitoring module completed

---

# Phase 6 — Inventory Management

Goal

Develop inventory and storage management.

Tasks

- Seed inventory.
- Stock movement.
- Inventory history.
- Quantity updates.
- Search.
- Filters.
- Low-stock alerts.
- Storage records.
- Seed usage history.
- Inventory analytics.
- Export inventory records.

Deliverables

✓ Inventory management completed

---

# Phase 7 — Notifications

Goal

Centralize all system notifications.

Tasks

- Battery alerts.
- Seed level alerts.
- Robot status alerts.
- Inventory alerts.
- Planting reminders.
- System announcements.
- Notification history.
- Connection alerts.
- Camera connection alerts.

Deliverables

✓ Notification center completed

---

# Phase 8 — Profile & User Management

Goal

Develop user profile management.

Tasks

All Users

- View profile.
- Edit profile.
- Change password.
- Logout.

System Administrator

- User management.
- Role assignment.
- Account activation.
- Account deactivation.
- Password reset.

Deliverables

✓ User management completed

---

# Phase 9 — Supabase Integration

Goal

Replace all mock data with live database functionality.

Tasks

- Authentication integration.
- Dashboard integration.
- Inventory integration.
- Crop monitoring integration.
- Notification integration.
- User management integration.
- Database validation.
- Error handling.
- Planting history.
- Crop progress timeline.

Deliverables

✓ Entire application connected to Supabase

---

# Phase 10 — ESP32 Hardware Integration

Goal
Establish real-time communication between the mobile application and the SeedRover hardware.

Tasks

Tasks

- Wi-Fi communication.
- Bluetooth communication.
- Connection management.
- Automatic reconnection.
- Send movement commands.
- Send planting commands.
- Receive sensor data.
- Receive battery status.
- Receive seed level.
- Receive rover status.
- Receive system diagnostics.
- Communication testing.

The initial implementation shall support both Wi-Fi and Bluetooth communication.

The communication architecture shall remain modular to allow future LoRa integration without modifying application features.

Deliverables

✓ Mobile application communicates with the prototype.

---

# Phase 11 — ESP32 Camera Integration

Goal

Integrate live camera streaming.

Tasks

- ESP32-CAM integration.
- Live video streaming.
- Fullscreen camera.
- Camera preview.
- Camera loading state.
- Camera reconnection.
- Camera latency indicator.
- Snapshot capture.

Deliverables

✓ Live rover camera available

---

# Phase 12 — System Testing & Validation

Goal

Validate the complete SeedRover ecosystem before presentation.

Tasks

- User acceptance testing
- Hardware integration testing
- Sensor validation
- Communication stress testing
- Battery endurance testing
- Camera performance testing
- Permission testing
- Database validation
- Error recovery testing
- Offline recovery testing

Deliverables

✓ Complete system tested

✓ Critical bugs resolved

✓ Performance validated

# Phase 13 — Final Polish

Goal

Prepare the application for deployment and presentation.

Tasks

- Improve animations.
- Improve transitions.
- Improve loading states.
- Empty states.
- Error handling.
- Performance optimization.
- Accessibility improvements.
- Responsive layout improvements.
- Final UI consistency.
- Bug fixing.
- Code cleanup.
- Documentation updates.
- Haptic feedback.
- Animation optimization.
- Micro-interactions.
- Skeleton loading animations.
- Hero transitions.

Deliverables

✓ Presentation-ready application

✓ Stable build

✓ Production-quality UI

---

# Future Development (Post-Capstone)

These features are intentionally excluded from the initial prototype but should be supported by the application's architecture.

Future Features

- Long-range LoRa communication
- Live telemetry charts
- GPS tracking
- Interactive farm map
- Multiple rover support
- AI planting recommendations
- Weather integration
- Predictive maintenance
- Cloud analytics
- Harvest forecasting
- Voice assistant
- Offline synchronization
- Web dashboard
- Remote firmware updates
- AI-assisted disease detection
- Multi-camera support

---

# Development Guidelines

Every feature must follow the official UI Design System.

Do not hardcode colors.

Do not hardcode typography.

Create reusable widgets whenever possible.

Avoid duplicated code.

Follow Clean Architecture principles.

Keep widgets small and modular.

Business logic should never exist inside UI widgets.

All API calls should be abstracted into services.

Use Riverpod for state management.

Every completed feature should be documented in `/docs/activity-log.md`.

Never refactor unrelated code unless requested.

Never introduce external packages unless necessary.

Maintain consistent coding style throughout the project.

Always prioritize readability, maintainability, and scalability over quick solutions.

Communication services must remain independent of application features.

The ESP32 communication layer shall be abstracted to allow future replacement or extension.

All communication payloads shall use JSON.

Avoid placing communication logic inside UI widgets.

Business logic shall reside in controllers, services, and repositories only.

Animations should prioritize smoothness over complexity and maintain consistent motion throughout the application.

Every screen should gracefully handle loading, empty, error, and offline states.

All new features should support dark mode by default.

The application should remain scalable for future web and desktop expansion.