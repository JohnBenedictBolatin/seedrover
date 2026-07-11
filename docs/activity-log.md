# Activity Log

## 2026-07-03 - Phase 1 Foundation Setup

Feature completed:

- Began Phase 1 project foundation setup.

Files modified:

- `.gitignore`
- `pubspec.yaml`
- `pubspec.lock`
- `lib/main.dart`
- `docs/activity-log.md`

Files created:

- `lib/core/config/app_bootstrap.dart`
- `lib/core/config/app_environment.dart`
- `lib/core/config/app_router.dart`
- `lib/core/config/seedrover_app.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/constants/app_routes.dart`
- `lib/core/constants/database_tables.dart`
- `lib/core/constants/permission_keys.dart`
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_durations.dart`
- `lib/core/theme/app_radius.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_typography.dart`
- `lib/core/errors/app_exception.dart`
- `lib/core/errors/failure.dart`
- `lib/core/extensions/build_context_extensions.dart`
- `lib/core/utils/date_time_formatter.dart`
- `lib/core/services/app_logger.dart`
- `lib/core/services/supabase_service.dart`
- `lib/core/communication/shared/communication_message.dart`
- `lib/core/communication/shared/communication_response.dart`
- `lib/core/communication/shared/communication_service.dart`
- `lib/core/communication/wifi/wifi_communication_service.dart`
- `lib/core/communication/bluetooth/bluetooth_communication_service.dart`
- `lib/shared/models/empty_state_model.dart`
- `lib/shared/widgets/app_card.dart`
- `lib/shared/widgets/loading_indicator.dart`
- `lib/shared/widgets/primary_button.dart`
- `lib/shared/widgets/status_badge.dart`

Summary:

- Cleaned the malformed dependency configuration.
- Pinned `google_fonts` to a version compatible with Dart 3.6.1.
- Added environment loading through `flutter_dotenv`.
- Added Supabase initialization during app bootstrap.
- Added Riverpod `ProviderScope`.
- Added centralized GoRouter setup.
- Added global route and database table constants.
- Added global color, typography, spacing, radius, duration, and theme configuration.
- Added base dependency providers for Supabase.
- Added communication service abstractions for future Wi-Fi and Bluetooth integration.
- Added reusable foundation widgets.
- Created the architecture-defined folder structure for core, shared, and feature modules.

Known issues:

- Feature screens and business logic are intentionally not implemented in Phase 1.
- Wi-Fi and Bluetooth services are abstracted but intentionally not implemented until hardware integration.
- Only the minimum foundation route exists so the app can compile.
- `dart format` and `flutter analyze --no-pub` timed out because local Dart processes repeatedly hung after dependency resolution.

Verification:

- `flutter pub get` completed successfully after correcting the SDK-compatible `google_fonts` version.
- Formatter and analyzer could not complete in the current shell session due to Dart tool timeout.

Next steps:

- Rerun formatter and analyzer once the local Dart toolchain responds normally.
- Generate Supabase migrations only after database schema approval.

## 2026-07-03 - Supabase Database Migration

Feature completed:

- Implemented the initial Supabase PostgreSQL database migration.

Files created:

- `supabase/migrations/20260703150000_initial_seedrover_schema.sql`

Files modified:

- `docs/activity-log.md`

Summary:

- Added normalized database tables for roles, profiles, permissions, robot status, sensor readings, planting logs, crops, stocks, notifications, activity logs, and robot commands.
- Added per-user permission support through `permissions` and `profile_permissions`.
- Added foreign keys, check constraints, unique constraints, and indexes.
- Added automatic `updated_at` triggers.
- Added default role and permission seed data.
- Added a default inactive/offline robot status row.
- Added a Supabase Auth trigger that creates a Farm Staff profile for new auth users.
- Added RLS helper functions for active-user checks, role checks, admin checks, and permission checks.
- Added Row Level Security policies for all application tables.
- Added a stock transaction trigger that updates inventory quantities atomically.
- Added profile protection so non-admin users cannot change their own role or active status.

Known issues:

- The Supabase CLI and `psql` are not installed in the local shell, so the migration could not be executed locally.
- Flutter code was intentionally not generated or modified for this database step.

Next steps:

- Review and approve the SQL migration.
- Apply the migration to Supabase after approval.

Approval:

- Approved by project owner on 2026-07-03.

## 2026-07-03 - Feature 1 Authentication

Feature completed:

- Implemented username/password authentication foundation.

Files created:

- `supabase/migrations/20260703161000_auth_username_lookup.sql`
- `lib/features/authentication/data/models/auth_permission_model.dart`
- `lib/features/authentication/data/models/auth_profile_model.dart`
- `lib/features/authentication/data/repositories/auth_repository.dart`
- `lib/features/authentication/controllers/auth_controller.dart`
- `lib/features/authentication/controllers/auth_state.dart`
- `lib/features/authentication/providers/auth_providers.dart`
- `lib/features/authentication/presentation/screens/login_screen.dart`
- `lib/features/authentication/presentation/screens/authenticated_home_screen.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/core/constants/app_routes.dart`
- `docs/activity-log.md`

Summary:

- Added username-to-email lookup RPC migration for Supabase Auth sign-in.
- Added authentication repository for username/password login, logout, session restore, profile retrieval, role retrieval, and permission retrieval.
- Added Riverpod auth controller and auth state.
- Added login screen with username/password validation and friendly error handling.
- Added authenticated shell with profile details and logout.
- Added GoRouter auth redirects for authenticated and unauthenticated sessions.
- Added permission-aware initial navigation between Dashboard and Profile routes without implementing Dashboard.
- Added role-default permission handling for System Administrator, Farm Planting Manager, Farm Inventory Manager, and Farm Staff.

Known issues:

- The new `20260703161000_auth_username_lookup.sql` migration must be applied to Supabase before username login works.
- Dashboard remains intentionally unimplemented.
- Password change is not implemented in this step because it was not included in the requested requirements list.

Verification:

- Source files were reviewed manually for obvious syntax and architecture issues.
- `dart format lib supabase` timed out in the local shell.
- `flutter analyze --no-pub` timed out in the local shell.
- Stale Dart processes from timed-out commands were stopped.

## 2026-07-04 - Authentication Error Messages

Feature completed:

- Improved login error messages for username and password failures.

Files modified:

- `lib/features/authentication/data/repositories/auth_repository.dart`
- `docs/activity-log.md`

Summary:

- Username lookup failures now show that the username was not found or the account is inactive.
- Supabase password authentication failures now show an incorrect password message.

Known issues:

- Password reset is still handled manually through Supabase until the profile/password management feature is implemented.

## 2026-07-04 - Login Polish And Password Reset

Feature completed:

- Added forgot-password action to the login screen.
- Corrected primary button text contrast.

Files modified:

- `lib/features/authentication/controllers/auth_controller.dart`
- `lib/features/authentication/controllers/auth_state.dart`
- `lib/features/authentication/data/repositories/auth_repository.dart`
- `lib/features/authentication/presentation/screens/login_screen.dart`
- `lib/shared/widgets/primary_button.dart`
- `docs/activity-log.md`

Summary:

- Added username-based password reset email support through Supabase Auth.
- Added success message support to authentication state.
- Added a `Forgot password?` action below the login button.
- Updated primary button foreground text to white on the green gradient.

Known issues:

- Supabase email settings must be configured for password reset emails to arrive.

## 2026-07-04 - Asset Folder Setup

Feature completed:

- Added the Flutter image assets folder for the official SeedRover logo.

Files created:

- `assets/images/.gitkeep`

Files modified:

- `pubspec.yaml`
- `docs/activity-log.md`

Summary:

- Created `assets/images/`.
- Registered `assets/images/` in Flutter assets.
- Added `.gitkeep` so the empty assets folder remains available in Git.

Next steps:

- Add the official logo PNG to `assets/images/`.
- Replace login title text with the official logo once the PNG is available.

## 2026-07-04 - Login Logo Update

Feature completed:

- Replaced the login screen text title with the official SeedRover logo.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Assets added:

- `assets/images/SeedRover Logo.png`

Summary:

- Centered the official logo above the login subtitle.
- Centered the sign-in subtitle below the logo.

## 2026-07-04 - Feature 2 Dashboard

Feature completed:

- Implemented the Dashboard with mock data only.

Files created:

- `lib/features/dashboard/data/models/dashboard_model.dart`
- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `lib/features/dashboard/providers/dashboard_providers.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/connection_status_row.dart`
- `lib/features/dashboard/presentation/widgets/current_activity_card.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_metric_tile.dart`
- `lib/features/dashboard/presentation/widgets/notification_preview_panel.dart`
- `lib/features/dashboard/presentation/widgets/quick_actions_panel.dart`
- `lib/features/dashboard/presentation/widgets/recent_activity_panel.dart`
- `lib/features/dashboard/presentation/widgets/rover_overview_card.dart`
- `lib/features/dashboard/presentation/widgets/section_title.dart`
- `lib/features/dashboard/presentation/widgets/sensor_summary_grid.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `docs/activity-log.md`

Summary:

- Added mock rover overview data, battery level, seed level, connection status, sensor summary, current activity, quick actions, recent activities, and notification preview.
- Added reusable dashboard widgets for cards, status rows, metric tiles, sensor summaries, quick actions, activity previews, and notification previews.
- Replaced the temporary authenticated dashboard shell with the Dashboard screen.
- Kept Dashboard data mock-only and did not connect to Supabase.
- Kept Rover Control unimplemented; quick actions show mock availability messaging only.

Known issues:

- Floating bottom navigation is not implemented yet.
- Dashboard values are static mock data until the approved Supabase integration phase.
- Quick actions do not navigate to unimplemented modules.

Verification:

- Source files were manually reviewed for obvious syntax and line-length issues.
- `dart format lib/features/dashboard lib/core/config/app_router.dart` timed out in the local shell.
- `flutter analyze --no-pub` timed out in the local shell.
- Stale Dart processes from timed-out commands were stopped.

## 2026-07-04 - Dashboard Rover Image Placeholder

Feature completed:

- Added a rover image placeholder and mock usage details to the Dashboard.

Files created:

- `lib/features/dashboard/presentation/widgets/rover_image_placeholder.dart`

Files modified:

- `lib/features/dashboard/data/models/dashboard_model.dart`
- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `lib/features/dashboard/presentation/widgets/rover_overview_card.dart`
- `docs/activity-log.md`

Summary:

- Added mock `isInUse` and `usageDuration` fields to the rover overview model.
- Added a reusable rover image placeholder widget.
- Displayed whether the rover is in use or idle.
- Displayed mock runtime in hours and minutes.

Known issues:

- The placeholder does not use a real rover image yet.

## 2026-07-04 - Dashboard Navigation Cleanup

Feature completed:

- Removed redundant Dashboard sections and added floating bottom navigation.

Files created:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `lib/shared/widgets/feature_unavailable_screen.dart`

Files deleted:

- `lib/features/dashboard/presentation/widgets/quick_actions_panel.dart`
- `lib/features/dashboard/presentation/widgets/notification_preview_panel.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/features/authentication/presentation/screens/authenticated_home_screen.dart`
- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `lib/features/dashboard/data/models/dashboard_model.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed Notification Preview from the Dashboard because Notifications has its own module.
- Removed Quick Actions from the Dashboard to avoid duplicating module navigation.
- Added a reusable authenticated scaffold with floating bottom navigation.
- Added permission-aware navigation items for Dashboard, Rover, Crops, Stocks, Notifications, and Profile.
- Added minimal unavailable-module shells for routes whose features are not implemented yet.
- Kept Rover Control, Crops, Stocks, and Notifications unimplemented.

Known issues:

- Bottom navigation destinations for future modules show unavailable-module messages until their phases are approved.

## 2026-07-04 - Supabase Profile Role Edit Fix

Feature completed:

- Fixed Supabase-side profile role/status editing.

Files created:

- `supabase/migrations/20260704113000_allow_admin_profile_role_updates.sql`

Files modified:

- `docs/activity-log.md`

Summary:

- Updated the profile security trigger so Supabase SQL Editor/Table Editor admin operations can change `role_id` and `is_active`.
- App users are still prevented from changing their own role or active status.

Next steps:

- Apply the new migration in Supabase SQL Editor.

## 2026-07-04 - Dashboard Header And Navigation Polish

Feature completed:

- Polished Dashboard greeting and floating navigation styling.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Updated the Dashboard greeting to use the project green gradient.
- Reduced the greeting size while keeping it prominent.
- Reduced floating navigation label size to improve readability.
- Changed the Rover navigation icon to a wheel-style icon.
- Changed the Crops navigation icon to a seed/plant-style icon.
- Removed the low-opacity selected navigation background.
- Updated selected navigation state so the icon and label use the green gradient.

## 2026-07-04 - Floating Navigation Icon Update

Feature completed:

- Simplified the floating navigation to icon-only buttons.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Removed visible floating navigation text labels.
- Increased navigation icon sizes.
- Preserved tooltip labels for accessibility.
- Kept the existing selected-state gradient animation.

## 2026-07-04 - Floating Navigation Size Fix

Feature completed:

- Fixed the floating navigation container sizing.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Added a fixed height to the floating navigation container.
- Changed icon buttons from minimum-height sizing to fixed square sizing.
- Reduced Dashboard bottom padding to match the compact icon-only navigation.

## 2026-07-04 - Floating Navigation Glass Polish

Feature completed:

- Refined the floating navigation appearance and Dashboard header metadata layout.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `docs/activity-log.md`

Summary:

- Reduced the floating navigation background opacity for a smoother glass effect.
- Added subtle outer floating shadows to the navigation bar.
- Softened the navigation border.
- Swapped the Dashboard role badge and date/time positions.

## 2026-07-04 - Floating Navigation Shadow Cleanup

Feature completed:

- Removed the green glow behind the floating navigation bar.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Kept the glass-style floating navigation.
- Removed the green-tinted outer shadow.
- Preserved the neutral depth shadow behind the navigation bar.

## 2026-07-04 - Dashboard Connection Badge Fix

Feature completed:

- Fixed Dashboard connection status badge layout.

Files modified:

- `lib/features/dashboard/presentation/widgets/connection_status_row.dart`
- `docs/activity-log.md`

Summary:

- Moved Wi-Fi, Bluetooth, and Camera icons inside their outlined badges.
- Kept connected statuses green and offline statuses muted.
- Preserved the existing Dashboard mock connection data.

## 2026-07-04 - Dashboard Current Activity Removal

Feature completed:

- Removed Current Activity from the Dashboard.

Files deleted:

- `lib/features/dashboard/presentation/widgets/current_activity_card.dart`

Files modified:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/rover_overview_card.dart`
- `lib/features/dashboard/data/models/dashboard_model.dart`
- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `docs/activity-log.md`

Summary:

- Removed the standalone Current Activity card.
- Removed the activity text from the Rover Overview card.
- Removed unused current activity mock data and model fields.

## 2026-07-04 - Dashboard Mono Typography Update

Feature completed:

- Applied Roboto Mono styling to selected Dashboard text.

Files modified:

- `lib/core/theme/app_typography.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/features/dashboard/presentation/widgets/rover_overview_card.dart`
- `lib/features/dashboard/presentation/widgets/section_title.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_metric_tile.dart`
- `lib/features/dashboard/presentation/widgets/sensor_summary_grid.dart`
- `lib/features/dashboard/presentation/widgets/recent_activity_panel.dart`
- `docs/activity-log.md`

Summary:

- Added reusable Roboto Mono typography styles.
- Applied mono styling to Dashboard date/time text.
- Applied mono styling to the SeedRover unit name.
- Applied mono styling across the Sensor Summary title and tile text.
- Applied mono styling to recent activity module/time metadata.

## 2026-07-04 - Global Roboto Mono Typography Trial

Feature completed:

- Switched visible app typography to Roboto Mono for review.

Files modified:

- `lib/core/theme/app_typography.dart`
- `lib/core/theme/app_theme.dart`
- `docs/activity-log.md`

Summary:

- Changed primary heading, title, body, small, and caption styles to Roboto Mono.
- Updated the global Material text theme to Roboto Mono.
- Preserved text hierarchy through font size and weight differences.

## 2026-07-04 - Features 3-6 Rover Operations

Feature completed:

- Implemented simulated Rover Control, Planting Control, Live Camera, and Sensor Monitoring.

Files created:

- `lib/features/rover/data/models/rover_command_model.dart`
- `lib/features/rover/data/models/rover_control_model.dart`
- `lib/features/rover/data/repositories/rover_repository.dart`
- `lib/features/rover/data/services/simulated_rover_communication_service.dart`
- `lib/features/rover/controllers/rover_control_controller.dart`
- `lib/features/rover/controllers/rover_control_state.dart`
- `lib/features/rover/providers/rover_providers.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/camera_preview_panel.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `lib/features/rover/presentation/widgets/rover_panel_title.dart`
- `lib/features/rover/presentation/widgets/rover_sensor_card.dart`
- `lib/features/rover/presentation/widgets/rover_status_card.dart`
- `lib/features/rover/presentation/widgets/rover_status_grid.dart`
- `lib/features/rover/presentation/widgets/sensor_monitoring_grid.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `docs/activity-log.md`

Summary:

- Replaced the Rover placeholder route with the simulated Rover Control screen.
- Added movement controls for forward, backward, rotate left, rotate right, and stop.
- Added planting controls for start, pause, resume, and stop.
- Added simulated camera placeholder, loading state, fullscreen UI, refresh action, and connection badge.
- Added sensor cards for soil moisture, soil temperature, environmental temperature, and humidity.
- Added status cards for battery, seed level, Wi-Fi, Bluetooth, and camera.
- Kept rover communication abstracted through a simulated `CommunicationService`.
- Kept all data simulated and did not connect to hardware or Supabase.

Known issues:

- Hardware communication remains intentionally disabled until the approved communication integration phase.
- Camera stream is a placeholder grid, not a real ESP32-CAM stream.
- `dart format` timed out again due to the local Dart toolchain hanging.
- `flutter analyze --no-pub` timed out due to the same local Dart toolchain issue.

## 2026-07-04 - Rover Control Simplified Process

Feature completed:

- Simplified the Rover Control workflow into a soil-check gate and planting run.

Files modified:

- `lib/features/rover/controllers/rover_control_controller.dart`
- `lib/features/rover/controllers/rover_control_state.dart`
- `lib/features/rover/data/models/rover_control_model.dart`
- `lib/features/rover/data/repositories/rover_repository.dart`
- `lib/features/rover/data/services/simulated_rover_communication_service.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Locked the Rover Control screen to landscape while the module is open.
- Simplified movement controls to arrow-only buttons with a center stop button and speed slider.
- Changed planting into a two-step process with `Check Soil State` and `Start Planting`.
- Added a soil-check result message before planting can begin.
- Disabled rover movement while planting is active until `Emergency Stop` is used.
- Kept the rover communication layer abstracted through the simulated service.

## 2026-07-04 - Rover Control Landscape Layout Polish

Feature completed:

- Reworked the Rover Control screen into a no-scroll landscape control layout.

Files modified:

- `lib/core/config/app_router.dart`
- `lib/shared/widgets/authenticated_scaffold.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `lib/features/rover/presentation/widgets/rover_status_grid.dart`
- `lib/features/rover/presentation/widgets/rover_sensor_card.dart`
- `lib/features/rover/presentation/widgets/sensor_monitoring_grid.dart`
- `docs/activity-log.md`

Summary:

- Hid the floating bottom navigation while the Rover Control module is open.
- Arranged the Rover screen from left to right: movement and speed, camera feedback, sensors and planting controls.
- Removed vertical scrolling from the active Rover Control screen.
- Reduced camera footprint while keeping the full placeholder stream visible.
- Added compact status pills below the camera feed.
- Added compact sensor cards and shortened planting action labels.
- Kept movement and planting controls in separate screen columns.

## 2026-07-04 - Rover Control Sensor Overflow Fix

Feature completed:

- Fixed the Rover Control right-side sensor and planting column overflow.

Files modified:

- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `lib/features/rover/presentation/widgets/rover_sensor_card.dart`
- `lib/features/rover/presentation/widgets/sensor_monitoring_grid.dart`
- `docs/activity-log.md`

Summary:

- Removed the visible `Sensors` and `Planting Control` section labels to save vertical space.
- Converted compact sensor cards into shorter row-style telemetry tiles.
- Shortened compact sensor labels while keeping the full sensor set visible.
- Reduced planting panel padding and spacing.
- Increased the compact sensor grid aspect ratio to avoid bottom overflow in landscape.

## 2026-07-04 - Rover Control Navigation Restore

Feature completed:

- Restored bottom navigation on the Rover Control screen and tightened the right-side layout.

Files modified:

- `lib/core/config/app_router.dart`
- `lib/shared/widgets/authenticated_scaffold.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/sensor_monitoring_grid.dart`
- `docs/activity-log.md`

Summary:

- Restored the authenticated floating bottom navigation for the Rover module.
- Added compact floating navigation sizing when the app is in landscape orientation.
- Changed the right-side sensor grid to shrink to its content instead of stretching vertically.
- Moved the planting controls directly below the sensor data to remove the wide empty gap.

## 2026-07-04 - Rover Control Compact Controls Polish

Feature completed:

- Reduced Rover movement control footprint and softened control panel outlines.

Files modified:

- `lib/shared/widgets/app_card.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Added an optional `borderColor` override to the reusable `AppCard`.
- Removed the visible `Movement` heading from the Rover movement panel.
- Reduced movement control padding, button height, and directional pad width.
- Changed the movement and planting panel borders from green to the neutral inactive border.

## 2026-07-04 - Rover Control Speed UI Removal

Feature completed:

- Removed the visible movement speed setting from the Rover Control screen.

Files modified:

- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Removed the speed slider and speed percentage text from the movement panel.
- Removed speed-related constructor inputs from `MovementControlPanel`.
- Kept the compact directional movement buttons unchanged.
- Left the simulated command speed value in the controller/model layer unchanged for compatibility.

## 2026-07-04 - Rover Movement Control Resize

Feature completed:

- Enlarged the Rover movement controls after removing the speed setting.

Files modified:

- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Changed the directional pad to size itself from the available movement panel space.
- Increased the maximum directional pad size while preserving the existing button design.
- Scaled movement icons modestly with button size.
- Kept the movement panel border, colors, and arrow-only control behavior unchanged.

## 2026-07-04 - Rover Control Panel Surface Match

Feature completed:

- Matched Rover movement and planting panel surfaces to the darker sensor tile background.

Files modified:

- `lib/shared/widgets/app_card.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Added an optional `backgroundColor` override to the reusable `AppCard`.
- Set the movement control panel background to `AppColors.secondaryBackground`.
- Set the planting control panel background to `AppColors.secondaryBackground`.
- Preserved the default `AppCard` background for all existing cards that do not override it.

## 2026-07-04 - Feature 7 Crop Monitoring

Feature completed:

- Implemented Crop Monitoring with mock data only.

Files created:

- `lib/features/crops/data/models/crop_model.dart`
- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/controllers/crop_monitoring_controller.dart`
- `lib/features/crops/controllers/crop_monitoring_state.dart`
- `lib/features/crops/providers/crop_providers.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_card.dart`
- `lib/features/crops/presentation/widgets/crop_detail_metric.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `lib/features/crops/presentation/widgets/crop_maintenance_note.dart`
- `lib/features/crops/presentation/widgets/crop_summary_row.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `docs/activity-log.md`

Summary:

- Added mock crop records with crop name, variety, location, planting date, growth stage, estimated harvest, status, manager, progress, and maintenance notes.
- Added controller-owned search and filtering logic for crop text search, crop status, and growth stage.
- Added crop summary cards for total crops, active crops, and harvest-ready crops.
- Added responsive crop cards and a crop detail panel.
- Replaced the Crops placeholder route with the Crop Monitoring screen.
- Kept all data local and did not connect to Supabase.

Known issues:

- Crop Monitoring uses mock data until the approved Supabase integration phase.
- Crop history, planting history, sensor history, timelines, and calendar integration remain future roadmap items outside this requested scope.
- `dart format` and `flutter analyze --no-pub` timed out due to the local Dart/Flutter toolchain hanging.

## 2026-07-04 - Crop Monitoring Compile Fix

Fix completed:

- Resolved Crop Monitoring compile errors reported during Flutter build.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_summary_row.dart`
- `docs/activity-log.md`

Summary:

- Promoted the nullable selected crop through a local variable before passing it to `CropDetailPanel`.
- Replaced the remaining `CupertinoIcons.check_mark_circled` reference in `crop_summary_row.dart` with `Icons.check_circle_outline`.

## 2026-07-04 - Crop Monitoring Layout Reorganization

Feature updated:

- Reorganized Crop Monitoring content based on the project owner's Figma concept while preserving SeedRover visual identity.

Files created:

- `lib/features/crops/presentation/widgets/crop_plot_preview.dart`
- `lib/features/crops/presentation/widgets/crop_screen_header.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `lib/features/crops/presentation/widgets/planted_today_card.dart`
- `lib/features/crops/presentation/widgets/planting_location_selector.dart`

Files modified:

- `lib/features/crops/data/models/crop_model.dart`
- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `docs/activity-log.md`

Summary:

- Added a Crops header with a history action and search indicator.
- Added a planting location selector-style panel.
- Added a stylized planting plot preview using SeedRover theme colors.
- Added a `Planted Today` callout using mock Calamansi planting data.
- Reorganized planted crop cards into groups by planting date.
- Added seed counts to mock crop records for planted-seed card content.
- Kept search, filters, crop details, and mock-only data flow intact.

## 2026-07-04 - Crop Seed Count Runtime Fix

Fix completed:

- Prevented a nullable seed count runtime crash after the Crop Monitoring layout update.

Files modified:

- `lib/features/crops/data/models/crop_model.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `lib/features/crops/presentation/widgets/planted_today_card.dart`
- `docs/activity-log.md`

Summary:

- Changed `CropModel.seedCount` to nullable to tolerate stale hot-reload model instances.
- Added `safeSeedCount` to display a fallback value when seed count is missing.
- Updated planted crop cards and planted-today card to use `safeSeedCount`.

Note:

- A full hot restart is recommended because the `CropModel` shape changed.

## 2026-07-04 - Crop Monitoring Scope And Header Polish

Feature updated:

- Refined Crop Monitoring to better match the SeedRover seed-tracking workflow.

Files deleted:

- `lib/features/crops/presentation/widgets/planting_location_selector.dart`

Files modified:

- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_screen_header.dart`
- `docs/activity-log.md`

Summary:

- Removed the planting location selector section.
- Changed `View history` into a compact icon action so it fits the SeedRover header style.
- Limited mock crop records to the current supported seed types: Calamansi, Peanut, and Sitaw.
- Added copy explaining that Crop Monitoring records rover-planted seed activity for farmer tracking.

## 2026-07-04 - Crop Monitoring Header And Plot Cleanup

Feature updated:

- Removed the remaining history action and seed-location style visual container from Crop Monitoring.

Files deleted:

- `lib/features/crops/presentation/widgets/crop_plot_preview.dart`

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_screen_header.dart`
- `docs/activity-log.md`

Summary:

- Removed the `View history` icon action from the Crops header.
- Removed the plot preview container from the Crop Monitoring screen.
- Kept the screen focused on rover-recorded planted seed activity.

## 2026-07-04 - Crop Monitoring Dropdown Filters

Feature updated:

- Reworked Crop Monitoring filters for cleaner seed tracking.

Files modified:

- `lib/features/crops/controllers/crop_monitoring_controller.dart`
- `lib/features/crops/controllers/crop_monitoring_state.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Added a planted-date dropdown directly below the crop search field.
- Replaced chip-style crop suggestions with dropdown filter controls.
- Added crop category filtering by seed type.
- Kept crop category options derived from the current mock seed records.
- Kept filtering logic inside the Crop Monitoring controller.

## 2026-07-05 - Crop Action Dialog Styling

Feature updated:

- Standardized Crop action popup windows with the Growth Timeline dialog style.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Replaced plain Water, Fertilize, Harvest, Edit, and Delete dialogs with a shared dark SeedRover dialog shell.
- Added consistent white dialog titles, close icons, dark card surfaces, and inactive-border window outlines.
- Restyled dialog actions as quiet outlined controls with matching action colors.
- Added consistent vertical spacing between fields inside Water, Fertilize, and Edit dialogs.
- Made dialog action icons explicitly match their action color, including the red Delete icon.
- Kept all existing mock action fields and behavior unchanged.

Fix:

- Removed an extra comma in the Crop Details edit dialog method signature that caused `Expected ')' before this` during debug build.
- Normalized the edit dialog method signature after the build fix.

## 2026-07-05 - Crop Environmental Info Popup

Feature updated:

- Moved Crop Details environmental information into a header info action.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the always-visible Environmental Information section from Crop Details.
- Added a white info icon beside the crop name and ID in the Crop Details header.
- Opened the environmental sensor snapshot in the existing styled Crop popup window.
- Renamed the Crop Details header to the compact `Details/crop002` format.
- Changed the Crop Progress growth-timeline info icon to white.

## 2026-07-05 - Crop Filter Simplification

Feature updated:

- Reduced the main Crop Monitoring filter row to three filters.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Kept only Plant, Date, and Stages filters visible on the main Crops screen.
- Removed Harvest Date, Status, and Sort controls from the visible filter bar.
- Preserved existing search and clear-filter behavior.

## 2026-07-05 - Crop Board Layout And Mock Data Expansion

Feature updated:

- Improved the main Crop Monitoring presentation and expanded mock data.

Files modified:

- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `docs/activity-log.md`

Summary:

- Centered the Plant, Date, and Stages filters.
- Reworked the crop list into a `Crop Board` grouped by plant type instead of date.
- Added group summary badges showing crop count and latest planted date.
- Centered crop tiles inside each plant group.
- Expanded mock crop records from 4 to 12 using only Calamansi, Peanut, and Sitaw.

Polish:

- Removed the `Crop Board` heading.
- Simplified each seed-type summary to crop count only.
- Removed the summary badge background.
- Increased spacing between each seed-type label and its crop cards.
- Moved crop count directly beside the seed-type label.
- Removed repeated `seeds` wording from individual crop card names.

## 2026-07-05 - Stocks Inventory Module

Feature completed:

- Implemented the mock-only Stocks / Inventory module.

Files created:

- `lib/features/inventory/data/models/stock_model.dart`
- `lib/features/inventory/data/repositories/stock_repository.dart`
- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/controllers/stock_inventory_state.dart`
- `lib/features/inventory/providers/stock_providers.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_action_buttons.dart`
- `lib/features/inventory/presentation/widgets/stock_card.dart`
- `lib/features/inventory/presentation/widgets/stock_detail_metric.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `lib/features/inventory/presentation/widgets/stock_filter_bar.dart`
- `lib/features/inventory/presentation/widgets/stock_transaction_timeline.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/core/constants/app_routes.dart`
- `docs/activity-log.md`

Summary:

- Replaced the Stocks placeholder route with a functional inventory list screen.
- Added stock details navigation and route constants.
- Added mock stock records across Seeds, Fertilizers, Soil Amendments, Pesticides, Tools, Hardware, Consumables, and Others.
- Added search, category filtering, status filtering, sorting, pull-to-refresh, loading state, and empty state.
- Added stock details with metrics, notes, transaction history, and status chips.
- Added Stock In, Stock Out, Adjust Stock, Edit Item, and permission-aware Delete Item actions.
- Added transaction creation and automatic status calculation for stock movements.
- Kept all inventory data mock-only and did not connect to Supabase.

Consistency:

- Matched Crop Monitoring dark card surfaces, compact filters, outlined action buttons, styled dialogs, spacing, status badges, and detail metric layout.

Known issues:

- `dart format` timed out locally due to the Dart toolchain hang observed in previous steps.

## 2026-07-05 - Crop Growth Timeline Info Action

Feature updated:

- Moved the Growth Timeline into a compact info action.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `docs/activity-log.md`

Summary:

- Removed the standalone Growth Timeline card from Crop Details.
- Added an info icon beside `Crop Progress`.
- Opened the growth timeline, crop age, and remaining harvest days in a dialog from that info icon.
- Redesigned the timeline dialog with SeedRover card styling, stage tiles, progress state labels, and compact age/remaining metric chips.
- Removed the green outer dialog outline and changed the dialog title to white.

## 2026-07-05 - Crop Action Button Styling

Feature updated:

- Softened Crop Details action button styling.

Files modified:

- `lib/features/crops/presentation/widgets/crop_action_buttons.dart`
- `docs/activity-log.md`

Summary:

- Changed Water, Fertilize, Harvest, Edit, and Delete buttons from filled colors to dark outlined controls.
- Kept action color on the icon, text, and border only.
- Matched the quieter Crop Detail card styling.
- Matched action icons to each button outline color.
- Changed action buttons to a two-by-two layout.
- Moved Delete into the Edit dialog for users with delete permission.
- Changed the Edit action button to use danger/red styling.
- Removed outlines from compact Crop Detail metric cards.
- Added a larger crop image above the Crop Progress section.

## 2026-07-05 - Crop Detail Metric Compacting

Feature updated:

- Reduced Crop Detail metric card height and label length.

Files modified:

- `lib/features/crops/presentation/widgets/crop_detail_metric.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `docs/activity-log.md`

Summary:

- Reduced metric card padding, icon size, and corner radius.
- Shortened long labels: `Planting Date` to `Plant Date`, `Growth Stage` to `Stage`, and `Assigned Staff` to `Staff`.
- Forced the metric layout to keep three cards per row.
- Tightened metric spacing so the three-card row fits in the available Crop Details card width.
- Changed Crop Detail metric dates to `MM/DD/YY` format and shortened `Est. Harvest` to `Est. Harv`.
- Moved metric icons beside their labels to reduce vertical space.

## 2026-07-05 - Crop Details Action Placement

Feature updated:

- Repositioned Crop Details actions and removed the Notifications section.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `docs/activity-log.md`

Summary:

- Removed the standalone Notifications card from Crop Details.
- Moved Water, Fertilize, Harvest, Edit, and Delete actions into the main Crop Detail card directly before Notes.
- Preserved the existing Crop Details visual style.

## 2026-07-05 - Crop Details Metric Grid

Feature updated:

- Reorganized Crop Details planting information into a compact grid.

Files modified:

- `lib/features/crops/presentation/widgets/crop_detail_metric.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `docs/activity-log.md`

Summary:

- Changed crop detail metrics to support responsive widths.
- Arranged Crop ID, Quantity, Planting Date, Growth Stage, Estimated Harvest, and Assigned Staff into a three-column layout when space allows.
- Preserved the existing metric card styling and SeedRover visual identity.

## 2026-07-05 - Crop Details Header Gradient

Feature updated:

- Refined the Crop Details header.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Applied the project green gradient to the back icon and Crop Details header text.
- Changed the header to show the crop name and crop ID above the `Crop Details` label.

## 2026-07-05 - Feature 7 Crop Monitoring Completion

Feature updated:

- Completed the mock-only Crop Monitoring management workflow while preserving the approved UI design.

Files created:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/crops/presentation/widgets/crop_action_buttons.dart`
- `lib/features/crops/presentation/widgets/crop_growth_timeline.dart`
- `lib/features/crops/presentation/widgets/crop_maintenance_timeline.dart`
- `lib/features/crops/presentation/widgets/crop_sensor_snapshot_grid.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/core/constants/app_routes.dart`
- `lib/features/crops/controllers/crop_monitoring_controller.dart`
- `lib/features/crops/controllers/crop_monitoring_state.dart`
- `lib/features/crops/data/models/crop_model.dart`
- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `docs/activity-log.md`

Summary:

- Added a dedicated crop details route and screen opened from existing crop `View` buttons.
- Kept the crop list visually consistent while adding status, planting date, refresh, sort, and additional filters.
- Added mock crop detail data for sensors, reminders, notes, maintenance history, staff assignment, crop age, and remaining harvest days.
- Added mock Water, Fertilize, Harvest, Edit, and role-aware Delete actions.
- Added maintenance history updates, harvest lifecycle updates, and success feedback using local state only.
- Kept all data mock-only and did not connect Crop Monitoring to Supabase.

Verification:

- Manual reference scans found and removed old crop status enum references.
- `flutter analyze --no-pub` timed out locally.
- `dart analyze lib/features/crops` timed out locally.

## 2026-07-05 - Crop Detail Modal Close Button

Feature updated:

- Added a top-right close button to the crop detail modal.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `docs/activity-log.md`

Summary:

- Replaced `MediaQuery.sizeOf` with `MediaQuery.of(context).size` for broader Flutter runtime compatibility.
- Moved the close icon button outside the crop detail card window.
- Added spacing between the external close button and the detail window.
- Kept the existing crop detail panel design unchanged.

## 2026-07-05 - Crop Detail Modal

Feature updated:

- Moved full crop details into a modal while keeping the existing detail design.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `docs/activity-log.md`

Summary:

- Removed the always-visible crop detail panel from the Crop Monitoring screen.
- Reused the existing `CropDetailPanel` inside a popup dialog.
- Opened crop details only from planted crop `View` actions.
- Kept the crop cards, plant images, filters, and SeedRover visual styling intact.

## 2026-07-04 - Crop Monitoring Plant Image Assets

Feature updated:

- Replaced generic seed icons in Crop Monitoring with plant image assets.

Files modified:

- `lib/features/crops/presentation/widgets/crop_plant_image.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `lib/features/crops/presentation/widgets/planted_today_card.dart`
- `pubspec.yaml`
- `docs/activity-log.md`

Summary:

- Added a reusable crop plant image widget for Calamansi, Peanut, and Sitaw.
- Replaced crop tile and planted-today seed icons with transparent plant PNG assets.
- Registered the crop image asset directory for Flutter bundling.

## 2026-07-04 - Crop Monitoring Compact Filter Layout

Feature updated:

- Compactly repositioned Crop Monitoring filters above the planted-today section.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `lib/features/crops/presentation/widgets/crop_screen_header.dart`
- `docs/activity-log.md`

Summary:

- Removed the descriptive text under the `Crops` title.
- Removed the search icon from the upper-right header area.
- Moved the search bar and filters above `Planted Today`.
- Arranged the Date, Seed Type, and Growth Stage dropdowns side by side on wider screens.
- Kept the filter row responsive so it wraps cleanly on smaller screens.

## 2026-07-04 - Crop Monitoring Compact Filter Buttons

Feature updated:

- Reduced Crop Monitoring filters into compact icon-label controls.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Replaced large dropdown form fields with compact popup filter buttons.
- Displayed filters as `calendar icon + date`, `seed icon + seeds`, and `stages icon + stages`.
- Kept all three filter buttons on one row.
- Removed the `Planted crops (Grouped by date planted)` heading.

## 2026-07-04 - Crop Monitoring Control Styling Fix

Feature updated:

- Aligned Crop Monitoring filter and view controls with the SeedRover visual standard.

Files modified:

- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `lib/features/crops/presentation/widgets/planted_today_card.dart`
- `docs/activity-log.md`

Summary:

- Reduced filter and View button corner radius.
- Changed filter icons to white.
- Added dropdown chevrons to compact filter controls.
- Restyled crop `View` buttons from rounded green filled buttons to darker outlined controls with green text.

## 2026-07-05 - Stocks And Crops Header Filter Polish

Feature updated:

- Aligned Stocks and Crops visual presentation.

Files modified:

- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/crops/presentation/widgets/crop_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Updated the Stocks page title to match the Crops page screen-title size and green color.
- Adjusted Crop Monitoring filter slots to match the Stocks filter positioning and width.

## 2026-07-05 - Stocks Produce Inventory Rework

Feature updated:

- Reframed Stocks as harvested produce inventory for market and farm-table tracking.

Files modified:

- `lib/features/inventory/data/models/stock_model.dart`
- `lib/features/inventory/data/repositories/stock_repository.dart`
- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Replaced farm-input stock categories with produce-oriented categories.
- Replaced mock farm supply records with vegetable and harvested crop stock records.
- Added market distribution and farm-table usage examples to transaction history.
- Updated visible form labels from supplier-oriented wording to harvest-source wording.
- Preserved existing mock-only stock movement behavior, status logic, and UI structure.

## 2026-07-05 - Horizontal Crop And Stock Cards

Feature updated:

- Changed crop and stock card presentation to grouped horizontal rows.

Files modified:

- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `docs/activity-log.md`

Summary:

- Grouped Stocks by produce category.
- Displayed each Stocks group as a horizontally scrollable card row.
- Changed Crop Monitoring plant groups to horizontally scrollable card rows.
- Preserved the existing card styling, filters, and View actions.

## 2026-07-05 - Stock Card Produce Image Placeholders

Feature updated:

- Added produce image placeholders to Stocks cards.

Files created:

- `assets/images/stocks/.gitkeep`
- `lib/features/inventory/presentation/widgets/stock_produce_image.dart`

Files modified:

- `lib/features/inventory/presentation/widgets/stock_card.dart`
- `pubspec.yaml`
- `docs/activity-log.md`

Summary:

- Registered `assets/images/stocks/` for future produce images.
- Added a reusable produce image widget with mapped placeholder asset paths.
- Added an image area to each stock card.
- Kept a green produce icon fallback when an image has not been added yet.

## 2026-07-05 - Stock Details Image And Action Refinement

Feature updated:

- Refined the mock Stocks / Inventory details workflow.

Files modified:

- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_action_buttons.dart`
- `docs/activity-log.md`

Summary:

- Added a large produce image area to the Stock Details screen using the existing stock image placeholder mapping.
- Removed the standalone Delete action button from the Stock Details action grid.
- Moved permission-aware Delete Item access into the Edit Item dialog.
- Changed Stock In location/source selection from free text to a dropdown.
- Changed Stock Out reason selection from free text to a dropdown.
- Kept transaction updates mock-only and did not connect Stocks to Supabase.

## 2026-07-05 - Feature 10 Notifications

Feature completed:

- Implemented the mock-only Notifications module with context-aware routing.

Files created:

- `lib/features/notifications/data/models/notification_model.dart`
- `lib/features/notifications/data/repositories/notification_repository.dart`
- `lib/features/notifications/controllers/notification_controller.dart`
- `lib/features/notifications/controllers/notification_state.dart`
- `lib/features/notifications/providers/notification_providers.dart`
- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `lib/features/notifications/presentation/screens/notification_details_screen.dart`
- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `lib/features/notifications/presentation/widgets/notification_filter_bar.dart`
- `lib/features/notifications/presentation/widgets/notification_empty_state.dart`
- `lib/features/notifications/presentation/widgets/notification_loading_list.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/core/constants/app_routes.dart`
- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Replaced the Notifications placeholder with a complete notification center using mock data only.
- Added notification categories, priorities, read/unread state, date filters, sorting, search, loading state, error state, and empty state.
- Added bulk actions for marking all as read, deleting read notifications, and clearing all notifications with confirmation before deletion.
- Added notification detail routing and a detail screen for full notification information.
- Added unread notification badge support to the floating bottom navigation.
- Added routing metadata to each mock notification: `relatedModule`, `relatedId`, and `actionRoute`.
- Routed notification taps and View actions through the notification controller instead of hardcoding navigation in the card widget.
- Added context-aware routes for inventory item details, crop details, Rover Control, planting log placeholders, user management placeholders, and notification details.

Consistency:

- Matched the Crop Monitoring and Inventory module title styling, compact filters, dark card surfaces, outlined action controls, status badges, spacing, and confirmation dialog styling.

Known issues:

- Planting Log and User Management destinations intentionally use unavailable-module placeholders until those modules are approved.

## 2026-07-05 - Notification Card And Filter Simplification

Feature updated:

- Simplified the Notifications list presentation.

Files modified:

- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `lib/features/notifications/presentation/widgets/notification_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Removed the visible Read/Unread and View buttons from each notification card.
- Replaced the card action row with a compact arrow icon affordance.
- Preserved card tap behavior through controller-resolved context-aware routing.
- Reduced visible notification filters from five to three core filters: Category, Priority, and Status.

## 2026-07-05 - Notification Card Alignment Polish

Feature updated:

- Refined notification card visual alignment.

Files modified:

- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `docs/activity-log.md`

Summary:

- Moved the priority chip into the same row as the timestamp.
- Changed the notification arrow affordance to white.
- Lowered the arrow placement so it no longer sits vertically aligned with the notification icon.

## 2026-07-05 - Notification Arrow Affordance Update

Feature updated:

- Refined the notification card arrow indicator.

Files modified:

- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `docs/activity-log.md`

Summary:

- Replaced the circled arrow indicator with a plain right-arrow icon.
- Lowered the arrow placement further within the notification card.

## 2026-07-05 - Cross-Module Skeleton Loading States

Feature updated:

- Added content placeholder loading states across core app modules.

Files created:

- `lib/shared/widgets/content_skeleton.dart`

Files modified:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Added reusable skeleton line, block, and card widgets using the existing SeedRover dark card styling.
- Added Dashboard skeleton placeholders during initial display and pull-to-refresh.
- Replaced Rover Control initial loading spinner with a landscape skeleton layout.
- Replaced Crop Monitoring loading and refresh spinner behavior with skeleton placeholders.
- Replaced Stocks loading and refresh spinner behavior with skeleton placeholders.

## 2026-07-05 - Notification Bulk Action Removal

Feature updated:

- Simplified the Notifications list controls.

Files modified:

- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the Mark All Read, Delete Read, and Clear All buttons from the Notifications screen.
- Removed the unused confirmation dialog helper tied to those bulk actions.

## 2026-07-05 - Feature 11 Profile And User Management

Feature completed:

- Implemented the mock-only Profile and User Management module.

Files created:

- `lib/features/profile/data/models/profile_user_model.dart`
- `lib/features/profile/data/repositories/profile_repository.dart`
- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/profile/controllers/profile_state.dart`
- `lib/features/profile/providers/profile_providers.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/profile/presentation/widgets/profile_avatar.dart`
- `lib/features/profile/presentation/widgets/profile_detail_tile.dart`
- `lib/features/profile/presentation/widgets/profile_action_button.dart`
- `lib/features/profile/presentation/widgets/profile_filter_bar.dart`
- `lib/features/profile/presentation/widgets/user_management_card.dart`

Files modified:

- `lib/core/config/app_router.dart`
- `docs/activity-log.md`

Summary:

- Replaced the old Profile placeholder with a full personal workspace.
- Added profile header, mock profile picture actions, personal information, account settings, quick stats, activity filtering, profile settings, and logout confirmation.
- Added role-adaptive quick stat content based on the authenticated user's assigned role.
- Added System Administrator-only User Management with mock users, search, filters, create user, view user, edit user, reset password, account activation/deactivation, and delete actions.
- Added a dedicated User Details screen for admin user review and edits.
- Kept all profile and user management behavior local/mock-only and did not connect to Supabase.

Role rendering:

- System Administrators see the User Management section and user details actions.
- Non-admin users see the same profile layout without management-only controls.

Consistency:

- Reused SeedRover dark cards, compact filters, outlined action buttons, status badges, skeleton loading, Roboto Mono text styles, and dialog styling used by Crop Monitoring, Inventory, and Notifications.

## 2026-07-06 - Profile Header Polish

Feature updated:

- Refined the Profile screen header and admin stat labels.

Files modified:

- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Enlarged the profile picture in the Profile header.
- Shortened the administrator quick stat label from `Pending Accounts` to `Pending Accs`.
- Moved Account Settings actions into an Edit menu in the upper-right of the Profile card.
- Removed the standalone Account Settings card from the Profile screen.

## 2026-07-06 - Profile Edit Menu Placement

Feature updated:

- Moved the Profile edit menu to the screen header.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the Edit menu from inside the Profile card.
- Added the Edit menu inline with the top `Profile` screen label.
- Kept the Profile card focused on profile identity details only.

## 2026-07-06 - Profile Indicators And Stats Icons

Feature updated:

- Refined the Profile header and quick stat cards.

Files modified:

- `lib/features/profile/data/models/profile_user_model.dart`
- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the online/status indicator and employee number from the Profile header.
- Added stat icons beside the values for Total Users, Active Users, and Pending Accs.
- Added icon metadata to role-based quick stats so the UI can render consistent stat icons without hardcoding labels.
- Reworded the active-user stat context so the Profile screen no longer displays an online indicator.

## 2026-07-06 - Profile Personal Information Cleanup

Feature updated:

- Simplified the Profile personal information card.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/widgets/profile_detail_tile.dart`
- `docs/activity-log.md`

Summary:

- Removed the duplicate Edit button from the Personal Information section.
- Removed Status from the Personal Information details.
- Matched the Personal Information field backgrounds to the section background.

## 2026-07-06 - Profile Activity Filter Restyle

Feature updated:

- Refined the My Activity filter presentation.

Files modified:

- `lib/features/profile/presentation/widgets/profile_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Replaced the Today / This Week / This Month choice-chip layout with a compact dropdown filter.
- Matched the filter surface, icon, chevron, border, and spacing style used by the Notifications filters.

## 2026-07-06 - Profile Activity Header Layout

Feature updated:

- Refined the My Activity section header.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/widgets/profile_filter_bar.dart`
- `docs/activity-log.md`

Summary:

- Moved the activity date filter beside the `My Activity` title.
- Removed the extra row of vertical spacing previously used by the activity filter.

## 2026-07-06 - Profile User Management Entry

Feature updated:

- Changed how administrators access User Management.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the Profile Settings section from the Profile screen.
- Added an admin-only Manage Users entry card in its place.
- Changed User Management so it appears only after an administrator taps Manage Users.

## 2026-07-06 - Profile User Management Modal

Feature updated:

- Changed the Manage Users interaction into a modal workflow.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Updated the Manage Users button so it opens User Management in a popup modal.
- Styled the modal to follow the Stocks action dialog pattern with a dark card surface, close icon, constrained scrollable content, and compact outlined controls.
- Removed the inline User Management expansion from the Profile screen.

## 2026-07-06 - User Management Action Menu

Feature updated:

- Simplified user cards inside the User Management modal.

Files modified:

- `lib/features/profile/presentation/widgets/user_management_card.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Moved View, Edit, Reset, Activate/Deactivate, and Delete into a single modify icon menu on each user card.
- Removed the multi-button action strip from user cards.
- Moved the Create button below the search and filter controls inside the User Management modal.

## 2026-07-06 - User Management Control Alignment

Feature updated:

- Refined User Management modal controls.

Files modified:

- `lib/features/profile/presentation/widgets/profile_filter_bar.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Placed the Create button and user filter on the same control row.
- Kept Create on the left side and the filter dropdown on the right side under the search field.

## 2026-07-06 - Admin Manage Users Placement

Feature updated:

- Refined the System Administrator profile layout.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Moved the admin-only Manage Users card directly below the quick stats section.
- Kept the Manage Users modal behavior unchanged.

## 2026-07-06 - User Management Dialog Action Styling

Feature updated:

- Refined User Management dialog action buttons.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Matched Profile/User Management dialog action button corner radius to the Crop module dialog action style.
- Updated Cancel actions to use white text and a white outline.
- Kept Save/Confirm actions compact with the same corner radius and spacing.

## 2026-07-06 - Cross-Module Confirmation Coverage

Feature updated:

- Added confirmation prompts for important actions across active modules.

Files modified:

- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Added rover confirmations for Start Planting and Emergency Stop.
- Added profile confirmations for profile picture changes/removal, password reset, profile saves, password changes, user creation, and user edits.
- Added User Details save confirmation.
- Added Crop Details edit-save confirmation.
- Added Stock Details edit-save confirmation.
- Kept existing confirmations for crop harvest/delete, stock movement/delete, profile logout, user status changes, and user deletion.

## 2026-07-06 - Rover Movement Panel Background

Feature updated:

- Refined the Rover Control movement joystick presentation.

Files modified:

- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Removed the card background and border around the movement control panel.
- Kept joystick buttons and spacing intact so the controls blend with the Rover Control screen background.

## 2026-07-06 - Rover Planting Button Text

Feature updated:

- Refined Rover Control planting action button text.

Files modified:

- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `docs/activity-log.md`

Summary:

- Reduced planting action button text size.
- Kept `Check Soil` on one line with ellipsis handling for tight screen widths.

## 2026-07-06 - History Section Icons

Feature updated:

- Refined history section headers in Crops and Stocks.

Files modified:

- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Added a green history icon to the right side of the Crop Maintenance History header.
- Added a green history icon to the right side of the Stock Transaction History header.

## 2026-07-06 - Maintenance History Timeline Styling

Feature updated:

- Refined crop maintenance history and history actions.

Files modified:

- `lib/features/crops/presentation/widgets/crop_maintenance_timeline.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Restyled Crop Maintenance History to match Stock Transaction History tile structure.
- Added color-coded maintenance icons for planted, watered, fertilized, inspected, and harvested records.
- Made the Crop Maintenance History icon open a full-history modal.
- Made the Stock Transaction History icon open a full-history modal.

## 2026-07-06 - Notification Read Priority Ordering

Feature updated:

- Refined notification ordering and read grouping.

Files modified:

- `lib/features/notifications/controllers/notification_controller.dart`
- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Sorted unread notifications above read notifications.
- Sorted notifications by priority within each read/unread group.
- Added an `Already read` divider before read notifications in the notification list.

## 2026-07-06 - Notification Icon Background Removal

Feature updated:

- Refined notification card icon presentation.

Files modified:

- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `docs/activity-log.md`

Summary:

- Removed the filled background container behind notification category icons.
- Kept icon alignment stable with a fixed-width icon slot.

## 2026-07-06 - SeedRover Mascot Identity

Feature updated:

- Added the first official SeedRover mascot integration.

Files created:

- `assets/images/mascot/seedrover_mascot_chroma.png`
- `assets/images/mascot/seedrover_mascot.png`
- `lib/shared/widgets/seedrover_mascot.dart`

Files modified:

- `pubspec.yaml`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `lib/features/notifications/presentation/widgets/notification_empty_state.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Generated a friendly rover mascot concept named `Rovie` with SeedRover green accents and a sprout antenna.
- Saved the transparent mascot asset for app use and registered it in Flutter assets.
- Added reusable `SeedRoverMascot` and `MascotMessage` widgets.
- Added the mascot to Crop, Stock, and Notification empty states.
- Added mascot-assisted messages to important confirmation dialogs.
- Added a small dashboard personality line: `Rovie is ready to roll.`

## 2026-07-06 - Mascot Integration Reverted

Feature updated:

- Reverted the visual SeedRover mascot integration.
- Kept app personality improvements text-only.

Files removed:

- `assets/images/mascot/seedrover_mascot_chroma.png`
- `assets/images/mascot/seedrover_mascot.png`
- `lib/shared/widgets/seedrover_mascot.dart`

Files modified:

- `pubspec.yaml`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `lib/features/notifications/presentation/widgets/notification_empty_state.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed mascot asset registration and reusable mascot widgets.
- Restored icon-based empty states for Crops, Stocks, and Notifications.
- Restored standard confirmation dialog message text without mascot visuals.
- Replaced the dashboard mascot line with a friendly text-only greeting subtitle.
- Softened key confirmation messages using text only.

## 2026-07-06 - Dashboard Greeting Subtitle Removal

Feature updated:

- Removed the extra dashboard greeting subtitle.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `docs/activity-log.md`

Summary:

- Removed the `Everything is lined up. Let's keep the farm moving.` line from the Dashboard header.
- Kept the existing greeting, role badge, date, and time layout unchanged.

## 2026-07-06 - Login Screen Personality Polish

Feature updated:

- Refined the Login screen presentation and copy.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Added a compact field-link status strip above the logo.
- Replaced `Sign in to operate your farming system.` with friendlier welcome copy.
- Added a `Remember me` checkbox beside the Forgot Password action.
- Wrapped the login fields and primary action in a darker SeedRover-styled panel.
- Kept authentication behavior connected to the existing Riverpod and Supabase Auth flow.

## 2026-07-06 - Login Screen Signal Strip Removal

Feature updated:

- Refined the Login screen after review.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `lib/shared/widgets/primary_button.dart`
- `docs/activity-log.md`

Summary:

- Removed the `FIELD LINK READY` status strip from the Login screen.
- Updated the reusable primary button text style to use SeedRover typography.
- Kept the Login button label white on the existing green gradient background.

## 2026-07-06 - Login Pixel Farm Animation

Feature updated:

- Added a lightweight animated pixel-art farm strip to the Login screen.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Added an 8-bit inspired moving grass, sapling, and tree strip at the bottom of the Login screen.
- Used existing SeedRover theme greens instead of new image assets.
- Kept the animation decorative only by ignoring pointer events and leaving authentication behavior unchanged.

## 2026-07-07 - Login Pixel Animation Controller Fix

Bug fixed:

- Fixed a `LateInitializationError` from the Login screen pixel farm animation.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Replaced the `late final` animation controller with a nullable lazily initialized controller.
- Kept controller disposal safe for hot reload and normal screen teardown.
- Preserved the bottom pixel farm animation behavior.

## 2026-07-07 - Login Pixel Farm Height Polish

Feature updated:

- Increased the height and visual weight of the Login screen pixel farm strip.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Increased the bottom pixel-art canvas height.
- Made grass, saplings, and trees taller while keeping the same theme green palette.
- Added more bottom scroll padding so the animation does not crowd the login form.

## 2026-07-07 - Login Pixel Farm Keyboard Behavior

Bug fixed:

- Hid the Login screen pixel farm animation while the keyboard is open.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Detected keyboard visibility from `MediaQuery.viewInsets`.
- Rendered the bottom pixel farm strip only when the keyboard is closed.
- Prevented the decorative animation from moving upward above the keyboard.

## 2026-07-07 - Official Mascot Asset Integration

Feature updated:

- Integrated the user-provided SeedRover mascot expression assets.

Files created:

- `lib/shared/widgets/seedrover_mascot.dart`

Files modified:

- `pubspec.yaml`
- `lib/features/authentication/presentation/screens/login_screen.dart`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `lib/features/notifications/presentation/widgets/notification_empty_state.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `docs/activity-log.md`

Summary:

- Registered `assets/images/mascot/` in Flutter assets.
- Added reusable mascot expression and mascot message widgets.
- Placed the happy/error mascot as a small peeking element on the Login form.
- Replaced Crop, Stock, and Notification empty-state icons with the curious mascot expression.
- Added thinking and warning mascot expressions to important confirmation dialogs.

## 2026-07-07 - Dashboard Mascot Header Placement

Feature updated:

- Moved the mascot personality placement from Login to Dashboard.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `docs/activity-log.md`

Summary:

- Removed the mascot from the Login form.
- Reorganized the Dashboard header into greeting, first name, date/time, and role.
- Placed the happy mascot in the open right side of the Dashboard header.
- Preserved the existing SeedRover green gradient treatment for the greeting text.

## 2026-07-07 - Dashboard Mascot Asset Update

Feature updated:

- Replaced the Dashboard header mascot expression with the dedicated dashboard asset.

Files modified:

- `lib/shared/widgets/seedrover_mascot.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `docs/activity-log.md`

Summary:

- Added `dashboard.png` as a reusable mascot expression.
- Updated the Dashboard header to render `SeedRoverMascotExpression.dashboard`.
- Kept the Dashboard header layout unchanged.

## 2026-07-07 - Floating AI Assistant With Gemini Edge Function

Feature added:

- Added a floating SeedRover AI Assistant with Gemini Edge Function support.

Files created:

- `lib/features/assistant/data/models/assistant_message_model.dart`
- `lib/features/assistant/data/repositories/assistant_repository.dart`
- `lib/features/assistant/controllers/assistant_controller.dart`
- `lib/features/assistant/controllers/assistant_state.dart`
- `lib/features/assistant/providers/assistant_providers.dart`
- `lib/features/assistant/presentation/widgets/assistant_floating_button.dart`
- `lib/features/assistant/presentation/widgets/assistant_chat_sheet.dart`
- `lib/features/assistant/presentation/widgets/assistant_chat_widgets.dart`
- `supabase/functions/assistant/index.ts`

Files modified:

- `lib/core/config/app_router.dart`
- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Added a floating assistant button to authenticated pages without adding a bottom navigation item.
- Added a SeedRover-styled assistant chat sheet with message history, suggested prompts, loading state, and fallback notice.
- Added Riverpod assistant state and controller.
- Added a repository that calls the Supabase `assistant` Edge Function.
- Added a local fallback response so the assistant remains usable before the Edge Function is deployed.
- Added a Supabase Edge Function that reads `GEMINI_API_KEY`, calls Gemini, and uses a SeedRover + planting system prompt.

Deployment note:

- Deployed with `npx supabase functions deploy assistant`.
- Verified the `assistant` function is active with JWT verification enabled.

## 2026-07-07 - Assistant Gemini Model Update

Bug fixed:

- Updated the assistant Edge Function default Gemini model.

Files modified:

- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Changed the default model from `gemini-2.0-flash-lite` to `gemini-2.5-flash-lite`.
- Added server-side error logging for failed or empty Gemini responses.
- Kept `GEMINI_MODEL` override support through Supabase secrets/environment variables.

## 2026-07-07 - Assistant Gemini History Normalization

Bug fixed:

- Fixed Gemini fallback caused by invalid chat history ordering.

Files modified:

- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Dropped leading assistant/model messages before sending history to Gemini.
- Merged consecutive messages from the same role to preserve valid user/model alternation.
- Kept the welcome message visible in the app without sending it as an invalid first Gemini turn.

## 2026-07-07 - Assistant Current App Data Context

Feature updated:

- Made the AI Assistant aware of current mock app data.

Files created:

- `lib/features/assistant/data/models/assistant_context_model.dart`
- `lib/features/assistant/data/repositories/assistant_context_repository.dart`

Files modified:

- `lib/features/assistant/data/repositories/assistant_repository.dart`
- `lib/features/assistant/controllers/assistant_controller.dart`
- `lib/features/assistant/controllers/assistant_state.dart`
- `lib/features/assistant/providers/assistant_providers.dart`
- `lib/features/assistant/presentation/widgets/assistant_chat_widgets.dart`
- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Added a compact assistant context snapshot from current Crop, Stock, Dashboard, Rover, and Recent Activity mock data.
- Sent the context snapshot with each assistant question.
- Updated the Edge Function to include current app context in the Gemini system instruction.
- Added guardrails so the assistant identifies context as current app/mock data, not live Supabase crop or stock tables.
- Updated assistant welcome/header copy to mention crops, stocks, and current app data.

## 2026-07-07 - Assistant App-Side Diagnostics

Issue addressed:

- The assistant still showed the local fallback message in the Flutter app even though the deployed Supabase Edge Function responded correctly when tested directly.

Files modified:

- `lib/features/assistant/data/repositories/assistant_repository.dart`
- `lib/features/assistant/controllers/assistant_controller.dart`
- `docs/activity-log.md`

Summary:

- Preserved Supabase Edge Function error status and response details when `functions.invoke` fails.
- Added readable assistant request diagnostics for generic network or runtime failures.
- Updated the fallback chat message and banner to show the actual connection detail instead of only the generic Gemini secret/logs message.

## 2026-07-07 - Assistant Context Reader Fix

Bug fixed:

- Fixed a Flutter-side assistant fallback caused by the app context reader being treated as null at runtime.

Files modified:

- `lib/features/assistant/controllers/assistant_controller.dart`
- `lib/features/assistant/providers/assistant_providers.dart`
- `lib/features/assistant/data/models/assistant_context_model.dart`
- `docs/activity-log.md`

Summary:

- Changed the assistant controller context-reader dependency to a named required constructor argument.
- Added an empty assistant context fallback so Gemini can still answer if current app data context cannot be read.
- Kept the assistant connected to current mock crop, stock, rover, dashboard, and activity data when the context provider is available.

## 2026-07-07 - Rovie Assistant Identity

Feature updated:

- Renamed the visible SeedRover assistant identity to Rovie.

Files modified:

- `lib/shared/widgets/seedrover_mascot.dart`
- `lib/features/assistant/presentation/widgets/assistant_floating_button.dart`
- `lib/features/assistant/presentation/widgets/assistant_chat_widgets.dart`
- `lib/features/assistant/controllers/assistant_state.dart`
- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Added an `assistant` mascot expression that uses `assets/images/mascot/assistant.png`.
- Updated the floating assistant button mascot to use the assistant expression.
- Changed visible assistant labels, tooltip, input hint, and welcome message to Rovie.
- Updated the Gemini Edge Function system prompt so the assistant identifies as Rovie.

## 2026-07-07 - Rovie Ask Button Shadow Removal

Feature updated:

- Refined the floating Rovie ask button.

Files modified:

- `lib/features/assistant/presentation/widgets/assistant_floating_button.dart`
- `docs/activity-log.md`

Summary:

- Removed the green glow shadow from the floating Ask button.
- Kept the gradient fill, mascot, label, and chat behavior unchanged.

## 2026-07-07 - Smooth Page Navigation Transitions

Feature updated:

- Refined app-wide page navigation animation.

Files modified:

- `lib/core/config/app_router.dart`
- `docs/activity-log.md`

Summary:

- Replaced plain GoRouter route builders with a shared custom transition page.
- Added a smooth fade and subtle horizontal slide for navigation between authenticated modules, detail screens, and login.
- Kept screen layouts, navigation destinations, permissions, and business behavior unchanged.

## 2026-07-07 - Content Entrance Animations

Feature updated:

- Added animated page content behavior across active modules.

Files created:

- `lib/shared/widgets/animated_content.dart`

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_header.dart`
- `lib/features/dashboard/presentation/widgets/dashboard_metric_tile.dart`
- `lib/features/dashboard/presentation/widgets/rover_image_placeholder.dart`
- `lib/features/dashboard/presentation/widgets/rover_overview_card.dart`
- `lib/features/dashboard/presentation/widgets/section_title.dart`
- `lib/features/rover/presentation/screens/rover_control_screen.dart`
- `lib/features/rover/presentation/widgets/rover_panel_title.dart`
- `lib/features/rover/presentation/widgets/rover_sensor_card.dart`
- `lib/features/rover/presentation/widgets/rover_status_card.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/crops/presentation/widgets/crop_card.dart`
- `lib/features/crops/presentation/widgets/crop_detail_metric.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `lib/features/crops/presentation/widgets/crop_screen_header.dart`
- `lib/features/crops/presentation/widgets/crop_sensor_snapshot_grid.dart`
- `lib/features/crops/presentation/widgets/crop_summary_row.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_card.dart`
- `lib/features/inventory/presentation/widgets/stock_detail_metric.dart`
- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `lib/features/notifications/presentation/widgets/notification_card.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/widgets/profile_detail_tile.dart`
- `docs/activity-log.md`

Summary:

- Added reusable typing text, animated metric text, and animated progress bar widgets.
- Applied type-in animation to main headings, card labels, detail labels, and high-visibility descriptive text.
- Applied count-up animation to numeric metric values, sensor values, crop/profile counts, stock quantities, and percent values.
- Applied progress-from-zero animation to crop progress bars.
- Kept controls, filters, dialogs, routing, permissions, and business behavior unchanged.

## 2026-07-07 - Dashboard Farm Analytics

Feature added:

- Added mock-only Dashboard analytics for crops planted and products sold.

Files created:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`

Files modified:

- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `docs/activity-log.md`

Summary:

- Added Dashboard KPI cards for crop records, seeds planted, units sold, and top sold item.
- Added native Flutter bar charts for crops planted by seed type, products sold by item, and average crop progress by seed type.
- Added a native Flutter sales trend line chart for recent inventory stock-out activity.
- Derived analytics from existing mock Crop Monitoring and Stocks/Inventory Riverpod state.
- Kept analytics mock-only and did not connect Dashboard to Supabase.

## 2026-07-07 - Dashboard Analytics Filters And Icons

Feature updated:

- Made Dashboard Farm Analytics interactive.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`
- `docs/activity-log.md`

Summary:

- Added Week, Month, and Year filters to the Farm Analytics section.
- Filtered crop analytics by planting date and inventory sales analytics by stock-out transaction date.
- Updated the sales trend chart to group by day for Week, week buckets for Month, and month buckets for Year.
- Added icons beside Farm Analytics KPI labels/values for Crops, Seeds, Sold, and Top Item.
- Added icons beside chart titles for Crops Planted, Products Sold, Crop Progress, and Sales Trend.

## 2026-07-07 - Dashboard Analytics Formatter Fix

Bug fixed:

- Fixed a Dashboard analytics runtime lookup failure for the quantity formatter.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`
- `docs/activity-log.md`

Summary:

- Replaced widget-private quantity formatter methods with one file-level helper.
- Updated KPI, bar chart, and top-item formatting to use the shared helper.

## 2026-07-10 - Dashboard Analytics Header Cleanup

Feature updated:

- Simplified the Dashboard Farm Analytics header and KPI labels.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the duplicate icons from the KPI label rows so only the metric values keep the icon treatment.
- Moved the Week, Month, and Year filters into the Farm Analytics header row on the right side.
- Removed the separate Farm Analytics title from the dashboard screen to avoid duplicated headings.

## 2026-07-10 - Dashboard Analytics Container Unification

Feature updated:

- Wrapped the Dashboard Farm Analytics content into one outer container.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`
- `docs/activity-log.md`

Summary:

- Placed the Farm Analytics title, range filters, KPI cards, and charts inside a single shared card surface.
- Kept the inner analytics cards and interactions intact while improving the section-level grouping.

## 2026-07-10 - Dashboard Analytics Border Match

Feature updated:

- Matched the Farm Analytics container styling to the rest of the dashboard cards.

Files modified:

- `lib/features/dashboard/presentation/widgets/dashboard_analytics_section.dart`
- `docs/activity-log.md`

Summary:

- Removed the green outline from the outer Farm Analytics container.
- Switched the analytics shell to the same regular background and border treatment used by the other cards.

## 2026-07-10 - Crop State Image Placeholders

Feature updated:

- Added state-aware crop image placeholders.

Files created:

- `assets/images/crops/README.md`

Files modified:

- `lib/features/crops/presentation/widgets/crop_plant_image.dart`
- `lib/features/crops/presentation/widgets/crop_detail_panel.dart`
- `lib/features/crops/presentation/widgets/planted_crop_group.dart`
- `lib/features/crops/presentation/widgets/planted_today_card.dart`
- `docs/activity-log.md`

Summary:

- Updated crop images to resolve by crop type and current growth/status state.
- Added placeholder visuals for missing crop-state PNG assets.
- Documented the expected crop image filename pattern for future assets.

## 2026-07-10 - Crop Image Placeholder Overflow Fix

Bug fixed:

- Fixed crop image placeholder overflow in small crop cards.

Files modified:

- `lib/features/crops/presentation/widgets/crop_plant_image.dart`
- `docs/activity-log.md`

Summary:

- Changed compact crop placeholders to icon-only rendering.
- Kept crop and state labels only for larger crop detail images.

## 2026-07-10 - Rover Control Floating Assistant And Radius Polish

Feature updated:

- Hid the Rovie floating assistant button on the Rover Control screen.
- Reduced Rover Control container corner radii.

Files modified:

- `lib/core/config/app_router.dart`
- `lib/shared/widgets/app_card.dart`
- `lib/features/rover/presentation/widgets/camera_preview_panel.dart`
- `lib/features/rover/presentation/widgets/planting_control_panel.dart`
- `lib/features/rover/presentation/widgets/movement_control_panel.dart`
- `lib/features/rover/presentation/widgets/rover_sensor_card.dart`
- `lib/features/rover/presentation/widgets/rover_status_card.dart`
- `docs/activity-log.md`

Summary:

- Made the authenticated shell route-aware so Rovie is not shown on Rover Control.
- Added an optional radius override to `AppCard` while preserving its default behavior.
- Applied sharper `AppRadius.sm` corners to Rover Control panels, camera, controls, sensors, and status cards.

## 2026-07-10 - Rover Navigation Icon Update

Feature updated:

- Replaced the Rover navigation icon with a wheel-like icon.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Changed the Rover bottom navigation icon from the repair glyph to a cleaner circular wheel-style icon.

## 2026-07-11 - Rover Navigation Icon Refinement

Feature updated:

- Made the Rover navigation icon look more mechanical.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Replaced the Rover tab icon with a manufacturing-style mechanical icon to better match the rover concept.

## 2026-07-11 - Rover Navigation Icon Gear Feel

Feature updated:

- Adjusted the Rover navigation icon to feel more like a gear or wheel.

Files modified:

- `lib/shared/widgets/authenticated_scaffold.dart`
- `docs/activity-log.md`

Summary:

- Swapped the Rover navigation glyph to a gear-like settings icon for a more wheel-like visual impression.

## 2026-07-11 - Login Welcome Copy Refresh

Feature updated:

- Made the login welcome text friendlier and more planting-focused.

Files modified:

- `lib/features/authentication/presentation/screens/login_screen.dart`
- `docs/activity-log.md`

Summary:

- Replaced the login greeting with softer planting-themed language.
- Removed the internal product-style wording from the welcome messages.
- Updated the headline to the exact phrase `Welcome back!` while keeping the planting-focused supporting line.

## 2026-07-11 - Supabase Integration Pass

Feature updated:

- Replaced major mock repositories with Supabase-backed data access.

Files modified:

- `lib/features/authentication/data/repositories/auth_repository.dart`
- `lib/features/assistant/data/models/assistant_context_model.dart`
- `lib/features/assistant/data/repositories/assistant_context_repository.dart`
- `lib/features/crops/controllers/crop_monitoring_controller.dart`
- `lib/features/crops/data/repositories/crop_repository.dart`
- `lib/features/crops/presentation/screens/crop_details_screen.dart`
- `lib/features/crops/providers/crop_providers.dart`
- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/data/repositories/stock_repository.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/providers/stock_providers.dart`
- `lib/features/notifications/controllers/notification_controller.dart`
- `lib/features/notifications/data/repositories/notification_repository.dart`
- `lib/features/notifications/providers/notification_providers.dart`
- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/profile/data/repositories/profile_repository.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/rover/controllers/rover_control_controller.dart`
- `lib/features/rover/data/repositories/rover_repository.dart`
- `lib/features/rover/providers/rover_providers.dart`

Summary:

- Connected crops, inventory, notifications, dashboard, rover telemetry, profile, and activity loading to Supabase tables.
- Added Supabase-backed create methods for crop and inventory records at the repository/controller layer.
- Added Supabase writes for crop updates, crop maintenance actions, stock movements, stock edits, notification read/unread/delete, profile updates, rover command audit rows, and auth login/logout logs.
- Added realtime subscriptions for crops, inventory, notifications, and rover status where the existing controllers can refresh affected state safely.
- Preserved approved UI, navigation, layouts, loading skeletons, and reusable widgets.

Known issues:

- Secure System Administrator user creation and password reset require a Supabase Edge Function or backend service using admin privileges; the Flutter client must not use the service role key.
- The current database schema does not include separate columns for some approved UI fields such as crop reminders, crop history rows, inventory supplier, inventory notes, and profile contact number, so those are derived from available live rows until a schema update is approved.

## 2026-07-11 - Dashboard Supabase Realtime Refresh

Feature updated:

- Completed dashboard realtime refresh wiring for Supabase-backed dashboard data.

Files modified:

- `lib/features/dashboard/controllers/dashboard_controller.dart`
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- `lib/features/assistant/data/repositories/assistant_context_repository.dart`
- `docs/activity-log.md`

Summary:

- Added realtime dashboard refresh events for rover status, sensor readings, and activity logs.
- The dashboard screen now invalidates its Supabase-backed provider when related live rows change.
- Replaced a Riverpod async convenience getter in the assistant context with explicit async handling for better compatibility.

## 2026-07-11 - Profile Provider Build Fix

Issue fixed:

- Resolved the undefined `profileRepositoryProvider` compile error during Android debug build.

Files modified:

- `lib/features/profile/providers/profile_providers.dart`
- `docs/activity-log.md`

Summary:

- Added the missing profile repository import so the profile controller provider can access the Supabase-backed repository provider.

## 2026-07-11 - Crop and Inventory Refresh UX Fix

Issue fixed:

- Crop Monitoring and Stocks/Inventory no longer replace the page with refresh-error text when realtime refresh fails.

Files modified:

- `lib/features/crops/controllers/crop_monitoring_controller.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `docs/activity-log.md`

Summary:

- Realtime refresh errors are now handled quietly so existing/empty content remains visible.
- Crop and inventory empty states now use the same `You're all caught up.` message style as notifications.
- Added a permission-aware Add Item action on the inventory list for users with `stocks.manage`.

## 2026-07-11 - Stock List Controller Import Fix

Issue fixed:

- Resolved the hot reload compile error for the `StockInventoryController` type in the stock list screen.

Files modified:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Added the missing stock inventory controller import used by the Add Item dialog helper.

## 2026-07-11 - Inventory Add Item Field Refinement

Feature updated:

- Refined the Stocks/Inventory Add Item flow.

Files modified:

- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/data/models/stock_model.dart`
- `lib/features/inventory/data/repositories/stock_repository.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_card.dart`
- `lib/features/inventory/presentation/widgets/stock_produce_image.dart`
- `docs/activity-log.md`

Summary:

- Moved the Add Item button beside the Stocks title on the right side.
- Changed the Add Item unit field from free text to a preset dropdown.
- Added a stock image selector that maps to available stock image asset slots.
- Added user-facing stock display IDs in the `STK-001` format while keeping Supabase UUIDs internal for database operations.

## 2026-07-11 - Inventory Supabase Stock Images

Feature updated:

- Added lightweight user-uploaded stock image support for Stocks/Inventory.

Files modified:

- `pubspec.yaml`
- `supabase/migrations/20260711170000_inventory_stock_images.sql`
- `lib/features/inventory/controllers/stock_inventory_controller.dart`
- `lib/features/inventory/data/models/stock_model.dart`
- `lib/features/inventory/data/repositories/stock_repository.dart`
- `lib/features/inventory/presentation/screens/stock_details_screen.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_card.dart`
- `lib/features/inventory/presentation/widgets/stock_produce_image.dart`
- `ios/Runner/Info.plist`
- `docs/database-schema.md`
- `docs/database-specification.md`
- `docs/activity-log.md`

Summary:

- Added `inventory.image_path` and `inventory.stock_code` through a new Supabase migration.
- Added the `stock-images` Supabase Storage bucket with permission-aware object policies.
- Replaced the temporary stock image asset selector with a gallery image picker and local preview.
- Uploaded selected stock images to Supabase Storage and stored only the storage path in the database.
- Stock cards and stock details now load uploaded stock images from Supabase Storage.
- Added the iOS photo library usage description required by the image picker.

## 2026-07-11 - Stock Image Picker Interaction Fix

Issue fixed:

- The stock image control did not visibly respond when tapped.

Files modified:

- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Made the whole stock image field tappable instead of relying only on the icon.
- Added an upload bottom sheet with Gallery and Camera options before opening the native picker.
- Added visible error handling if the native image picker cannot open or an image cannot be read.
- Added camera permission declarations for Android and iOS.

## 2026-07-11 - Caught Up Empty State Button Removal

Feature updated:

- Simplified the caught-up empty states across the app.

Files modified:

- `lib/features/notifications/presentation/widgets/notification_empty_state.dart`
- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `lib/features/crops/presentation/widgets/crop_empty_state.dart`
- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `lib/features/inventory/presentation/widgets/stock_empty_state.dart`
- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Removed the `Clear Filters` button from Notifications, Crop Monitoring, and Stocks/Inventory caught-up empty states.
- Kept the existing caught-up message and module-specific empty-state copy.

## 2026-07-11 - Crop Planted Today Conditional Display

Issue fixed:

- Removed the hanging hardcoded `Planted Today` section from the Crop Monitoring screen.

Files modified:

- `lib/features/crops/presentation/screens/crop_monitoring_screen.dart`
- `docs/activity-log.md`

Summary:

- The `Planted Today` section now appears only when a crop record has today's planting date.
- Removed the fixed `May 19, 2026` text and hardcoded Calamansi fallback.
- The section now uses the current date and lists all crops planted today.

## 2026-07-11 - Notification Unread Indicator Color

Feature updated:

- Adjusted the unread counter styling in the Notifications page.

Files modified:

- `lib/features/notifications/presentation/screens/notification_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Changed the unread indicator outline and text from green to white.

## 2026-07-11 - Rovie Farm Analytics Context

Feature updated:

- Expanded Rovie's assistant context so it can analyze farm analytics.

Files modified:

- `lib/features/assistant/data/models/assistant_context_model.dart`
- `lib/features/assistant/data/repositories/assistant_context_repository.dart`
- `lib/features/assistant/controllers/assistant_controller.dart`
- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Added `farmAnalytics` to the assistant context payload.
- Rovie now receives monthly sales movement, monthly planting counts, top sold items, top planted crops, latest stock-out activity, best observed sales month, and recommendation hints.
- Updated the assistant Edge Function prompt to use `farmAnalytics` for sales seasonality, best time to sell, top product, and trend questions.
- Added a local fallback answer for analytics questions when the Gemini Edge Function is unavailable.

## 2026-07-11 - Profile Image Storage Integration

Feature updated:

- Connected profile picture upload/removal to Supabase Storage instead of local-only state.

Files created:

- `supabase/migrations/20260711173000_profile_images.sql`

Files modified:

- `lib/features/profile/controllers/profile_controller.dart`
- `lib/features/profile/data/models/profile_user_model.dart`
- `lib/features/profile/data/repositories/profile_repository.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/user_details_screen.dart`
- `lib/features/profile/presentation/widgets/profile_avatar.dart`
- `lib/features/profile/presentation/widgets/user_management_card.dart`
- `ios/Runner/Info.plist`
- `docs/database-schema.md`
- `docs/database-specification.md`
- `docs/activity-log.md`

Summary:

- Added `profiles.profile_image_path` and a public Supabase Storage bucket named `profile-images`.
- Added Storage RLS policies so authenticated users with profile/user management permissions can upload, update, and remove profile pictures.
- Updated the profile repository to upload image bytes to Storage and save only the object path in the database.
- Updated profile avatars to render uploaded images from Supabase public URLs with the existing fallback style.

## 2026-07-11 - Profile Detail Tile Label Icon Alignment

Feature updated:

- Refined the Personal Information field layout in the Profile page.

Files modified:

- `lib/features/profile/presentation/widgets/profile_detail_tile.dart`
- `docs/activity-log.md`

Summary:

- Moved each field icon beside the field label instead of vertically between the label and value.
- Kept the existing SeedRover colors, spacing, and typography.

## 2026-07-11 - Notification Initial Load Retry

Issue fixed:

- Prevented the Notifications page from showing an initial load error before Supabase/auth state fully settles.

Files modified:

- `lib/features/notifications/controllers/notification_controller.dart`
- `docs/activity-log.md`

Summary:

- Added quiet retry attempts for the first notification load.
- Ignored realtime stream errors while the initial notification fetch is still loading with no cached data.
- Kept manual refresh behavior unchanged.

## 2026-07-11 - Notification Realtime Error Handling

Issue fixed:

- Prevented realtime notification stream errors from replacing the Notifications page with `Unable to refresh notifications`.

Files modified:

- `lib/features/notifications/controllers/notification_controller.dart`
- `docs/activity-log.md`

Summary:

- Kept the regular Supabase fetch as the visible source of load errors.
- Made realtime startup errors silent so notifications can still appear after the successful fetch.

## 2026-07-11 - Dashboard Connection Badge Text Wrap

Feature updated:

- Refined dashboard connection status badge text wrapping.

Files modified:

- `lib/features/dashboard/presentation/widgets/connection_status_row.dart`
- `docs/activity-log.md`

Summary:

- Kept connection badge labels on one compact line.
- Shortened Bluetooth to `BT` and Camera to `Cam` so statuses stay readable.
- Shortened status text from `Online`/`Offline` to `On`/`Off`.

## 2026-07-11 - Stocks Header Add Item Button Sizing

Feature updated:

- Reduced the Add Item button size on the Stocks page header.

Files modified:

- `lib/features/inventory/presentation/screens/stock_list_screen.dart`
- `docs/activity-log.md`

Summary:

- Reduced the Add Item button icon size, padding, and minimum height.
- Kept the existing outlined SeedRover action style.

## 2026-07-11 - Profile Header Edit Button Styling

Feature updated:

- Matched the Profile page Edit button style to the compact Stocks Add Item button.

Files modified:

- `lib/features/profile/presentation/screens/profile_screen.dart`
- `docs/activity-log.md`

Summary:

- Changed the Profile Edit menu trigger to use a smaller transparent outlined style.
- Kept the existing edit dropdown menu behavior.

## 2026-07-11 - Rovie Current Sales Status Context

Issue fixed:

- Improved Rovie's answer quality for current sales status questions.

Files modified:

- `lib/features/assistant/data/repositories/assistant_context_repository.dart`
- `lib/features/assistant/controllers/assistant_controller.dart`
- `supabase/functions/assistant/index.ts`
- `docs/activity-log.md`

Summary:

- Added `currentSalesStatus` to the assistant analytics context.
- Included stock-out transaction count, total sold quantity, latest sale movement, recent sales, and active sold item types.
- Updated local fallback and Gemini instructions so current sales questions do not get treated as long-term sales trend questions.

## 2026-07-11 - Native Launch Screen Branding

Feature updated:

- Replaced the default native launch screen appearance with SeedRover branding.

Files created:

- `android/app/src/main/res/drawable-nodpi/launch_logo.png`

Files modified:

- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `docs/activity-log.md`

Summary:

- Added a centered SeedRover logo to the native Android and iOS launch screens.
- Changed the native launch background to the app's dark gray `#1B1B1B`.

## 2026-07-11 - Android 12 Splash Screen Branding

Issue fixed:

- Prevented Android 12+ from showing the default Flutter launcher splash before SeedRover loads.

Files created:

- `android/app/src/main/res/values-v31/styles.xml`

Files modified:

- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `docs/activity-log.md`

Summary:

- Added Android 12+ `windowSplashScreen` attributes using the SeedRover launch logo.
- Set light and dark normal Android window backgrounds to SeedRover dark gray `#1B1B1B`.
- Removed unsupported `android:postSplashScreenTheme` attribute after Android resource linking failed.

## 2026-07-11 - Square SeedRover Splash Asset

Feature updated:

- Replaced the native splash logo output with the new square SeedRover splash asset.

Files modified:

- `android/app/src/main/res/drawable-nodpi/launch_logo.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `docs/activity-log.md`

Summary:

- Regenerated native launch assets from `assets/images/seedrover_splash.png`.
- Updated iOS launch image metadata to square dimensions.
