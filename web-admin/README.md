# SeedRover Web Admin

Fresh Next.js admin console for SeedRover farm managers and system administrators.

This website is intentionally focused on:

- sales and inventory management
- receipt-ready multi-item transactions
- customer details, discounts, and payment methods
- sales-derived customer tracking
- crop supervision
- read-only rover status and activity monitoring
- role-based access for farm/admin responsibilities
- admin-only existing user profile management
- admin notification supervision
- admin activity log auditing

The mobile app remains the field-first SeedRover experience. This web app is the office/manager console.

## Run Locally

This workspace currently uses the portable Node runtime stored in `../tmp/node-runtime/`.

Create `web-admin/.env.local` with the same Supabase project values used by the mobile app:

```text
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

```powershell
$nodeRoot = Resolve-Path '..\tmp\node-runtime\node-v24.18.0-win-x64'
$env:PATH = "$nodeRoot;$env:PATH"
npm run dev
```

Then open:

```text
http://localhost:3000
```

Useful routes:

```text
/login
/dashboard
```

## Verify

```powershell
npm run lint
npm run build
```

The UI uses local/system font fallbacks so builds do not depend on downloading remote font files.

## Build Order

1. Foundation UI and routing
2. Supabase connection and admin authentication
3. Role-based portal access
4. Inventory items, batches, stock movements, and low-stock alerts
5. Sales transaction builder with customer details, discounts, payments, and receipts
6. Reports and exports for CSV, Excel, PDF, and print
7. Crop supervision pages
8. Read-only rover status/activity pages
9. Deployment to Vercel with `web-admin` as the project root

## Database Notes

Multi-item web sales require the migration:

```text
../supabase/migrations/20260714090000_sales_orders.sql
```

Apply it to Supabase before recording web sales. The page can load before the migration, but submitting a receipt needs the `record_sales_order` RPC.

## Exports

Reports are available at:

```text
/reports
```

Current export formats:

- Inventory CSV: `/api/exports/inventory.csv`
- Inventory Excel-compatible file: `/api/exports/inventory.xls`
- Sales CSV: `/api/exports/sales.csv`
- Sales Excel-compatible file: `/api/exports/sales.xls`
- Inventory PDF: open `/reports/inventory/print`, then print or save as PDF
- Sales PDF: open `/reports/sales/print`, then print or save as PDF
