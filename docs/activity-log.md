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
