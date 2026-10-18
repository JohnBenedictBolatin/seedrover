# Supabase log usage check

The project starts from a Supabase organization meter reading of **0.916 GB out of 1 GB** on October 18, 2026. The invoice cadence suggests a cycle reset on October 30; confirm this in the dashboard. This leaves 84 MB. Keeping a 20 MB reserve gives a safe budget of about **5.33 MB per day** until the assumed reset.

At **9 AM Manila time**, record the organization-wide **Log Ingestion → Used in period** value:

```powershell
./scripts/record-supabase-log-ingestion.ps1 -UsedGb 0.916
```

Replace `0.916` with the current meter value. When Supabase confirms a different reset date, pass `-ResetDate yyyy-MM-dd`. The script appends a CSV row to `docs/automation/supabase-log-ingestion.csv`, calculates the daily budget after the reserve, and compares it with the previous day. The organization usage endpoint returned 401 for the existing CLI login, so the meter value must be copied from the dashboard.

The log query uses the saved Supabase CLI login, inspects only the previous 24 hours, returns service counts and aggregate sizes, and never saves raw messages:

```powershell
./scripts/measure-supabase-logs.ps1
```

The logger targets at most **25 MB per day** after the reset. For any cycle, it lowers that cap when needed to protect the 20 MB reserve until the cycle ends. The observed log query and request counters are diagnostic estimates, not Supabase's billable usage meter. Treat the dashboard's usage value as authoritative. Free-plan log retention is short; collect the source summary regularly to compare changes.

Recent 24-hour samples vary considerably. In the October 16–17 window, there were **12,785 API gateway events** and **11,709 pooler events**. The latest October 17–18 sample had **3,460 API gateway events** and **11,707 pooler events**. Its busiest API paths were `sensor_readings` (2,404), `crop_activities` (2,340), and `rpc/crop_performer_names` (2,333); five requests were logged as HTTP failures, and one Edge Function error was recorded. These are diagnostic event counts and field sizes, not billable bytes. Compare the next daily samples against the organization meter; do not infer a trend from one day. Keep debugging these endpoints as needed and leave the healthy default Postgres logging configuration in place.
