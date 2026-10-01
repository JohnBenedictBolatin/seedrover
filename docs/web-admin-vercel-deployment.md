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
SITE_URL
```

Set `SITE_URL` to the canonical public web-admin origin (for example,
`https://farm.example.com`, with no trailing path). Password recovery redirects
through `${SITE_URL}/auth/recovery`, which exchanges the Supabase recovery code
before sending the user to `/reset-password`.

The mobile app starts password recovery in this same web flow so the browser
that requests the email also handles the recovery session. Set `WEB_ADMIN_URL`
in the mobile app environment to the canonical web-admin origin
(`https://seedrover.vercel.app` for production). The app opens
`/login?reset=1`, where users enter their username and request a reset link.

The service-role key is server-only. Do not prefix it with `NEXT_PUBLIC_`.

## Auth configuration

In Supabase Auth URL settings, add the production Vercel/custom domain and the
approved preview URL or wildcard. Include the exact `/auth/recovery` callback
URL, `/login`, and `/dashboard` redirects, and test password reset using the
deployed origin. Keep `/login` allowed for older reset emails.

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
- Rover status, sensor readings, and activity history in read-only mode

Confirm both successful and denied actions for each role. The web rover module
is monitoring-only and does not communicate directly with or control the rover.

## Production promotion and rollback

Before promotion, back up production Supabase, apply and verify migrations,
deploy the approved Edge Functions, configure production secrets, and rerun the
smoke test with a production administrator. Promote the verified Vercel
deployment and retain the previous Vercel deployment and Edge Function versions
for rollback.

Monitor Vercel function errors, Supabase Auth/database/storage errors, Edge
Function logs, MQTT failures, crop-monitor cron runs, push failures, rate-limit
events, and failed inventory/sales RPCs after launch.
