# Mobile and web data accuracy audit

This note records the shared definitions applied during the mobile/web accuracy pass. Live values remain permission-scoped and come from the currently authenticated Supabase user.

| Display | Source and calculation | Time and availability |
| --- | --- | --- |
| Dashboard and inventory sales totals | Completed `sales_orders.total_amount` (receipt discounts already applied) plus completed standalone `sales_transactions.total_amount`; receipt headers are counted once. Voided records are excluded. | Business calendar is Asia/Manila. Day/week/month/year start at calendar boundaries, with weeks starting Monday. One assessment instant bounds each read; future records are excluded. Query errors or incomplete pages produce an unavailable state. |
| Sales trend | The same completed receipt totals and completed standalone totals, grouped into display buckets. Monthly totals are not copied into a single bucket. | Mobile reads all completed records in the current year with stable, paginated queries. |
| Sales category breakdown | Receipt item `line_total` is an item-line breakdown before receipt-level discounts; standalone sales use their recorded total. | Explicitly labeled before receipt discounts where shown. This breakdown does not replace net sales totals. |
| Inventory category summary | Counts inventory item records by category instead of adding quantities with potentially different units. | Empty is shown only after a successful complete inventory read. |
| Stock transaction chart | Counts recorded IN, OUT, and adjustment transactions by period; it does not sum quantities across different units. | Aggregate reads are paginated; recent-activity previews retain their intentional display limit. |
| Crop status totals | Active batches include every crop not completed by harvest or cancellation, matching mobile's active-batch definition. | Crop and sales totals are separate from permission-limited previews. |
| Sensor readings | Stored sensor records retain their real value, including zero, with source/provenance, calibration, and recorded time. | Missing/invalid values are unavailable; older readings are not substituted as fresh. Device-only and unsynchronized values are not cloud-verified values. |
| Assistant summaries | Uses the same permitted sales, inventory, crop, and rover providers. | Failed summaries are described as unavailable instead of converted into zero-valued facts. |
| Mobile startup | Dashboard, crops, and inventory show loading while initial permitted reads are pending. Failures and reads taking longer than 15 seconds offer retry and permitted destinations. | No persistent business-data cache is introduced. Rover access remains available when the role permits it and the phone is connected to rover Wi-Fi. |

## Verification boundary

The local mobile `.env` and web `.env.local` Supabase URL hosts were compared without printing either URL or any key; they match. The deployed Vercel environment and authenticated live records were not inspected in this pass, so deployment parity remains unverified. Read-only live comparisons require an authenticated runtime or a database inspection tool that is not available in this workspace session.
