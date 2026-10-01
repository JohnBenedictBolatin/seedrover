# SeedRover

SeedRover is a farm operations system made up of an Android/iOS Flutter app, a Next.js web administration portal, a Supabase backend, and ESP32 firmware for the rover and camera. The mobile app supports field work, including offline rover planting sessions that synchronize receipts when connectivity returns. The web portal provides management workflows and read-only rover monitoring.

## Project components

| Component | Location | Purpose |
| --- | --- | --- |
| Flutter mobile app | `lib/`, `android/`, `ios/` | Authentication, dashboards, crop and inventory workflows, notifications, and rover operation |
| Web administration portal | `web-admin/` | Sales, customers, inventory, crops, reports, user administration, and rover monitoring |
| Supabase backend | `supabase/` | PostgreSQL migrations, Edge Functions, SQL maintenance scripts, and database tests |
| Rover firmware | `firmware/esp32_seedrover/` | ESP32 rover control, sensors, and planting protocol |
| Camera firmware | `firmware/esp32_cam/` | ESP32-CAM stream on the rover's local Wi-Fi network |
| Shared workflow contract | `contracts/`, `scripts/` | Shared mobile/web workflow terminology and its consistency check |
| Technical documentation | `docs/` | Architecture, database, hardware, security, deployment, and workflow references |

## Requirements

- Flutter SDK with Dart SDK `3.6.1` or newer, as specified in `pubspec.yaml`.
- Android Studio and Android SDK for Android builds; Xcode and CocoaPods on macOS for iOS builds.
- Node.js `22.x` and npm for the web portal.
- A configured Supabase project for authenticated and cloud-backed workflows.
- Arduino IDE and the ESP32 board package only when building firmware.

## Mobile app setup

1. Copy `.env.mobile.json.example` to `.env.mobile.json` and set the values in the local copy.
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Configure `ROVER_TOKEN`, `ROVER_BASE_URL`, `CAMERA_BASE_URL`, and `WEB_ADMIN_URL` when those integrations are used. Do not put a Supabase service-role key or other server secret in the mobile app.
3. Fetch dependencies and run on a connected device or emulator:

   ```sh
   flutter pub get
   flutter run --dart-define-from-file=.env.mobile.json
   ```

For release builds, pass the same config file:

```sh
flutter build apk --dart-define-from-file=.env.mobile.json
flutter build ios --dart-define-from-file=.env.mobile.json
```

Builds receive only the mobile settings as compile-time defines; the whole local config file is not packaged as an asset. Values passed to a mobile build can still be recovered from the app. The Supabase anon key is a public client key, and `ROVER_TOKEN` is shared with the rover firmware, so it must not be treated as a secret or the sole security boundary. Keep server credentials such as `WEATHERAPI_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY` out of this mobile config. Android push notifications also require the Firebase setup described in [the push deployment guide](supabase/functions/PUSH_NOTIFICATIONS_DEPLOYMENT.md).

## Web admin setup

1. Create `web-admin/.env.local` from `web-admin/.env.example`.
2. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and the server-only `SUPABASE_SERVICE_ROLE_KEY`. Set `SITE_URL` for password recovery. `WEATHERAPI_API_KEY` and `OPENAI_API_KEY` are optional integrations; the active Rovie Edge Function configuration is documented in the deployment guide.
3. Install dependencies and start the development server:

   ```sh
   cd web-admin
   npm ci
   npm run dev
   ```

Open <http://localhost:3000>. Never expose `SUPABASE_SERVICE_ROLE_KEY` through a `NEXT_PUBLIC_` variable or commit local environment files. See [the web admin deployment guide](docs/web-admin-vercel-deployment.md) before deploying.

## Supabase setup and deployment

The SQL files in `supabase/migrations/` are ordered by timestamp. Apply them to the intended Supabase project using the Supabase CLI or the project's established database deployment process. Review the target project and migration status before applying migrations, especially in production. SQL scripts outside `migrations/` are separate maintenance or seed operations and should only be run when their purpose and effects are understood.

Edge Functions are in `supabase/functions/`. Function secrets belong in the Supabase project environment, not in source control. Deployment notes for crop monitoring and push notifications are in that folder; the [web admin deployment guide](docs/web-admin-vercel-deployment.md) covers the full portal release flow.

## Firmware

The rover and camera have separate setup guides:

- [Rover firmware and hardware map](firmware/esp32_seedrover/README.md)
- [ESP32-CAM setup](firmware/esp32_cam/README.md)
- [Mobile-to-rover protocol](docs/hardware-protocol.md)

Create local firmware secret headers from the checked-in templates. Keep `secrets.h` and `camera_secrets.h` private. Verify the electrical wiring, power, calibration, and emergency-stop behavior before operating actuators.

## Verification

Run mobile static analysis and tests from the repository root:

```sh
flutter analyze
flutter test
```

Run web checks from `web-admin/`:

```sh
npm run check:tracked-secrets
npm run lint
npm run build
```

The GitHub Actions workflow currently verifies the web admin on changes to `web-admin/`, `supabase/`, and its workflow configuration. The `check:shared-workflows` npm script checks generated shared workflow content against its contract.

## Documentation

Start with the [documentation index](docs/README.md). It links to architecture, app workflows, database and hardware references, audits, and deployment runbooks. The [web admin guide](web-admin/README.md) has portal-specific setup details.

## Security and data

Never commit `.env`, `.env.local`, `.env.mobile.json`, service-role keys, Firebase service-account files, or populated firmware secret headers. Templates may include safe local defaults; replace them with deployment-specific values and keep real secrets out of source control. Apply backend changes through reviewed migrations, and use a staging project for release validation.
