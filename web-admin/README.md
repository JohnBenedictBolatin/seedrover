# SeedRover Web Admin

The web admin is the office-facing management portal for SeedRover. It is a Next.js application backed by Supabase Auth, PostgreSQL, Storage, and Edge Functions. Rover pages provide status and activity monitoring; rover operation is handled by the mobile app.

## Features

- Operational dashboards and activity history
- Crop monitoring and crop outcomes
- Inventory, stock movement, sales, receipts, and payment collection
- Customer profiles, discounts, investments, and reports/exports
- Role-scoped notifications and user administration
- Read-only rover status, sensor, and command history
- Rovie assistant and farm weather integrations when configured

## Requirements

- Node.js `22.x`
- npm
- A configured Supabase project and an authorized user account

## Local development

Create `.env.local` in this directory. The `.env.example` template lists the supported settings:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SITE_URL
WEATHERAPI_API_KEY (optional)
OPENAI_API_KEY (optional)
```

The service-role key is server-only. Never prefix it with `NEXT_PUBLIC_`. Weather and external AI keys are optional; current Edge Function providers and server configuration are described in the deployment documentation.

Install and run:

```sh
npm ci
npm run dev
```

Open <http://localhost:3000>. The Supabase project must have the required migrations, Auth configuration, and Row Level Security policies applied for authenticated workflows to work.

## Verification

```sh
npm run check:tracked-secrets
npm run lint
npm run build
```

`npm run verify` runs lint and the production build. `npm run check:shared-workflows` checks the generated shared workflow contract, and `npm run test:input-contract` runs the contact number contract tests.

## Database and deployment

Apply timestamped files from `../supabase/migrations/` in order to the intended project. Use staging for release validation. Edge Functions live in `../supabase/functions/`; their secrets belong in Supabase, not in browser environment variables.

For Vercel, set the project root to `web-admin`, use Node.js `22.x`, install with `npm ci`, and build with `npm run build`. Set `SITE_URL` to the canonical site origin and configure the matching Supabase Auth redirect URLs. Follow the full [Vercel deployment guide](../docs/web-admin-vercel-deployment.md) and [staging checklist](../docs/web-admin-staging-checklist.md) before a release.

## Related documentation

- [SeedRover repository overview](../README.md)
- [Documentation index](../docs/README.md)
- [Vercel deployment guide](../docs/web-admin-vercel-deployment.md)
- [Staging checklist](../docs/web-admin-staging-checklist.md)
