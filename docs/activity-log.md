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
