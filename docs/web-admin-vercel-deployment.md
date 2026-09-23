# SeedRover Web Admin Vercel Deployment

This runbook deploys `web-admin` to Vercel and keeps Supabase as the backend.
Vercel hosts the Next.js portal and its server actions/API routes. Supabase
hosts PostgreSQL, Auth, Storage, Edge Functions, scheduled crop monitoring,
push dispatch, and rover integrations.

## Release gates

Run from `web-admin` with Node 22:

```powershell
npm ci
npm run check:tracked-secrets
npm run verify
```

`verify` runs lint and the production build. The release must be created from a
clean, reviewed commit. Do not include unrelated Flutter, firmware, or local
environment changes.

## Supabase staging

Link the staging project and apply migrations in timestamp order:

```powershell
supabase login
supabase link --project-ref <staging-project-ref>
supabase migration list
supabase db push
```

Verify RLS, RPCs, Auth roles, and these Storage buckets:

- `stock-images`
- `profile-images`
- `crop-images`
- `expense-receipts`

Load demo data only after an administrator profile exists.

## Edge Functions

Deploy all functions used by the portal and device services:

```powershell
supabase functions deploy assistant
supabase functions deploy crop-monitor --no-verify-jwt
supabase functions deploy push-notification --no-verify-jwt
supabase functions deploy rover-command
supabase functions deploy rover-device --no-verify-jwt
supabase functions deploy user-admin
```

Configure function secrets in Supabase, never in browser code:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
GEMINI_API_KEY
GEMINI_MODEL
CROP_MONITOR_CRON_SECRET
PAGASA_TENDAY_TOKEN
FCM_SERVICE_ACCOUNT_JSON
MQTT_URL
MQTT_USERNAME
MQTT_PASSWORD
ROVER_DEVICE_SECRET
```

`PAGASA_TENDAY_TOKEN` is optional. Rovie currently uses Gemini through the
`assistant` function; `OPENAI_API_KEY` is not required by the active code path.

After deploying `crop-monitor`, call
`configure_crop_monitoring_automation(project_url, service_role_key, cron_secret)`
once as a System Administrator. Verify the Vault secrets, hourly cron job, and
notification push trigger.

## Vercel project

Create a Vercel project connected to the repository with:

- Root Directory: `web-admin`
- Framework: Next.js
- Install Command: `npm ci`
- Build Command: `npm run build`
- Node.js: `22.x`
- Production branch: the reviewed release branch

Configure these variables for Preview and Production independently:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```

The service-role key is server-only. Do not prefix it with `NEXT_PUBLIC_`.

## Auth configuration

In Supabase Auth URL settings, add the production Vercel/custom domain and the
approved preview URL or wildcard. Include `/login` and `/dashboard` redirects,
and test password reset using the deployed origin.

## Preview acceptance test

Validate the preview deployment before production promotion:

- Login, logout, session persistence, and password reset
- Role access for administrator, planting, and inventory roles
- Dashboard, crops, inventory, sales, customers, investments, notifications,
  activity log, rover monitor, and users
- Storage uploads for crop, inventory, profile, and expense files
- Sales, discounts, payment methods, receipts, voiding, and stock deduction
- CSV/Excel exports and printable reports
- Rovie response and fallback behavior
- Crop-monitor execution, push dispatch, and login throttling
- Rover status and `PING` command when MQTT/device infrastructure is available

Confirm both successful and denied actions for each role. The web rover module
currently supports monitoring and limited `PING`; full autonomous control is
hardware-dependent and is not a Vercel deployment guarantee.

## Production promotion and rollback

Before promotion, back up production Supabase, apply and verify migrations,
deploy the approved Edge Functions, configure production secrets, and rerun the
smoke test with a production administrator. Promote the verified Vercel
deployment and retain the previous Vercel deployment and Edge Function versions
for rollback.

Monitor Vercel function errors, Supabase Auth/database/storage errors, Edge
Function logs, MQTT failures, crop-monitor cron runs, push failures, rate-limit
events, and failed inventory/sales RPCs after launch.
