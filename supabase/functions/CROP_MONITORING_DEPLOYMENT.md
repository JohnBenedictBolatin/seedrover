# Crop monitoring deployment

Apply migrations through `20260816142000_sitaw_repeated_harvest.sql`, then deploy both functions:

```text
supabase functions deploy crop-monitor --no-verify-jwt
supabase functions deploy push-notification --no-verify-jwt
```

Configure function secrets in the hosted project. Do not commit their values:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
CROP_MONITOR_CRON_SECRET
PAGASA_TENDAY_TOKEN
FCM_SERVICE_ACCOUNT_JSON
```

`PAGASA_TENDAY_TOKEN` is optional; the monitor reports Open-Meteo fallback confidence when it is absent. `FCM_SERVICE_ACCOUNT_JSON` is required for push delivery.

After deployment, sign in as a System Administrator and call `configure_crop_monitoring_automation(project_url, service_role_key, cron_secret)` once. It stores the deployment values in Supabase Vault, schedules the hourly monitor, and enables notification-triggered push dispatch. Use the same `CROP_MONITOR_CRON_SECRET` in the Edge Function.

The Flutter Android and iOS builds still require their platform Firebase files and APNs configuration. No Firebase, PAGASA, service-role, or rover token belongs in source control.
