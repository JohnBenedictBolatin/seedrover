# Android push notification deployment

SeedRover keeps notification records and recipient routing in Supabase. A database trigger calls the `push-notification` Edge Function for each new `public.notifications` row. The function sends the title, message, notification ID, and action route through Firebase Cloud Messaging (FCM). Audit-only activity remains in `activity_logs` and does not produce push messages.

## Android app setup

1. Create or select a Firebase project and register an Android app with the application ID `com.altf4.seedrover`.
2. Download the Android app's `google-services.json` and place it at `android/app/google-services.json`.
3. Install the app on Android 6.0 (API 23) or newer with Google Play services. The native Android FCM SDK is bridged to Flutter; no Firebase Flutter plugin or iOS/APNs setup is used.
4. The app requests Android notification permission after sign-in, registers the device token through `register_push_device_token`, and refreshes registration when FCM rotates the token.
5. Keep the Firebase service-account JSON and Supabase service-role key out of Flutter assets, source control, and chat.

## Supabase setup

1. Apply migrations, including `20261004100000_mobile_push_notifications.sql`.
2. Deploy the Edge Function with gateway JWT verification disabled. The function verifies the service-role bearer token sent by the database trigger:

   ```text
   supabase functions deploy push-notification --no-verify-jwt
   ```

3. Add `FCM_SERVICE_ACCOUNT_JSON` to the Supabase Edge Function secrets. The service account must be allowed to send through FCM HTTP v1 for the Firebase project. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are available to the Edge Function from the Supabase project environment.
4. As a signed-in System Administrator, invoke `configure_notification_push_dispatch(project_url, service_role_key)` once. It stores the project URL and service-role key in Vault for the database trigger.
5. Confirm the hosted database has `pg_net` and Supabase Vault available. If push dispatch cannot be queued, the notification insert still succeeds and the database records a warning.

## Smoke check

Sign in to the Android app, allow notifications, then create a normal SeedRover notification for that profile. Check delivery with the app foregrounded, backgrounded, and closed, and tap the alert to confirm it opens the associated screen. The existing role and recipient rules determine who receives each alert.

Without `google-services.json`, the Supabase migration, deployed Edge Function, and FCM service-account secret, the in-app Supabase notification feed continues to work but Android push delivery is unavailable.
