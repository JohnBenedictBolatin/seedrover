# SeedRover Web Admin Staging Checklist

Use this while waiting for full rover hardware integration. The goal is to make
the web/admin side stable before live rover data arrives.

## 1. Database setup

Apply every migration in order from:

```text
supabase/migrations
```

Important recent migrations:

- `20260717000000_web_admin_database_repair.sql`
- `20260717003000_inventory_vegetable_categories.sql`
- `20260718090000_crop_images.sql`
- `20260718100000_market_distribution_transaction_reference.sql`

Optional demo data:

```text
supabase/seed_demo_data.sql
```

Run the demo seed only after at least one active admin/profile exists.

## 2. Environment variables

Local `web-admin/.env.local` and Vercel should contain:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
OPENAI_API_KEY
```

Notes:

- `SUPABASE_SERVICE_ROLE_KEY` is server-only.
- Never use `NEXT_PUBLIC_` for the service role key.
- Never commit real `.env.local` values.

## 3. Auth checks

- Login with a System Administrator account.
- Confirm `/dashboard` redirects to `/login` when signed out.
- Confirm System Administrator can open `/users`.
- Confirm non-admin roles cannot open `/users`.
- Create one test user from the Users page.
- Confirm the new user appears in Managed Users.
- Confirm login throttling shows a wait message after repeated failed attempts.

## 4. Inventory checks

- Add an item with image.
- Edit current quantity.
- Stock in.
- Stock out.
- Select Market Distribution and confirm payment method appears.
- Select non-cash Market Distribution payment and confirm transaction ID is required.
- Confirm Market Distribution appears in Sales history.
- Delete item only with System Administrator account.
- Confirm vegetable categories are not old labels like Seeds/Tools/Consumables.

## 5. Sales checks

- Record one-item sale.
- Record multi-item sale.
- Apply a discount code.
- Use Cash, GCash, Bank Transfer, Card, and Other.
- Confirm amount paid/change calculation.
- Try selling more than available stock.
- Confirm inventory quantity decreases after sale.
- View receipt.
- Open Market Distribution row details and confirm item, quantity, price, payment, and transaction ID appear.
- Print/PDF receipt.
- Void sale and confirm stock returns.

## 6. Customers checks

- Confirm customers derive from sales receipts.
- Create a discount.
- Confirm discount appears in Discount List.
- Confirm redeemed/unredeemed status displays cleanly.
- Edit customer profile notes/type/tags.
- Export CSV/Excel.
- Print/PDF customer report.

## 7. Crops checks

- Add crop with image.
- Edit crop and replace image.
- Open crop details and confirm image displays.
- Record watering/fertilizing/harvest activity.
- Confirm mobile app falls back to local illustrations if no crop image exists.

## 8. Dashboard checks

- Switch Day / Week / Month / Year.
- Confirm sales, inventory, stock movement, payment, crop, and rover panels do not crash.
- Confirm empty states display cleanly when data is missing.

## 9. Rover monitor checks

- Confirm rover status, sensor snapshot, and command history display.
- Treat the page as read-only until hardware integration is finalized.
- Confirm stale/no-data states are understandable.

## 10. Before Vercel production

- Apply migrations to production Supabase.
- Confirm RLS policies directly in Supabase.
- Confirm Supabase Auth Site URL and Redirect URLs.
- Confirm Vercel environment variables.
- Use staging first before public production.
