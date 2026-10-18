# SeedRover resource optimization and verification

**Execution date:** 2026-10-18 (Asia/Manila)  
**Scope:** Web portal, Flutter Android app, Supabase database functions, crop-monitor job, and local verification.  
**Deployment:** Not deployed. The added migration must be applied before clients using the new crop summary RPCs are deployed.

## Summary of implementation

| Area | Change | Expected resource effect | Integrity and compatibility |
|---|---|---|---|
| Web crop overview | Replaced the full crop activity history scan with `get_crop_activity_summaries`. | One summary RPC instead of downloading all activity pages for overview metrics. | Returns latest observation, business-week activity count, and latest drop-cycle count. Existing activity write contracts remain unchanged. |
| Android crop list | Removed eager activity/photo history reads from crop list loading. History loads on the Growth or Activity tab with deterministic server pagination. | Avoids loading detailed histories for crops the user never opens. | Full history and attached photos remain available on demand; viewer authorization remains enforced by existing table/storage access policies. |
| Web crop history | Fetches photo attachment rows in a batch and requests signed URLs in batches of up to 100 paths. | Removes per-activity/per-photo query and signing loops. | Does not delete or shorten history. |
| Crop monitor job | Loads watering and fresh verified sensor inputs through one service-only aggregate RPC before evaluating crops. | Replaces two input queries per crop with one batched RPC per job invocation. | Keeps the 24-hour water calculation, 60-second sensor freshness rule, thresholds, hourly cadence, task writes, and notification behavior. |
| Mobile crop/dashboard realtime | Uses change notifications rather than full table snapshots; debounces bursts and queues a follow-up crop refresh when a change arrives during an active request. | Avoids downloading table snapshots and reduces duplicate refreshes. | Initial crop load remains explicit; realtime changes trigger refreshes. Channels and timers are disposed when their listeners close. |
| Web polling | Retains the previously selected 30-second visible rover refresh and 120-second visible connectivity checks. | Approximately 83% fewer scheduled polls while visible than the earlier 5-second/20-second intervals. | Manual refresh and return-to-visible checks remain available. Actual log reduction has not been measured. |
| Web font loading | Uses the repository's Poppins font files locally rather than fetching Google Fonts during build/runtime. | Removes an external font request and makes production builds independent of Google Fonts availability. | Existing Poppins family is retained; browser synthesis supplies weights above the bundled 700 weight. |
| Browser CI | Starts an isolated local Supabase stack from canonical migrations and passes only local test credentials to Playwright. | Removes hosted project use and credentials from browser E2E runs. | Existing remote-host safety checks remain enabled; workflow always stops its local stack. |

No records were deleted, retention was not reduced, existing application write endpoints were not changed, and no speculative database indexes were added. The existing `crop_activities_crop_time_idx` is reused by the summary reads.

## Database changes and rollback

Migration: `supabase/migrations/20261024100000_crop_activity_summary_reads.sql`.

It adds two functions only:

- `public.get_crop_activity_summaries(uuid[], timestamptz, timestamptz)` is executable by authenticated users and checks `crops.view` or `crops.manage` before returning summaries.
- `public.get_crop_monitor_inputs(uuid[], timestamptz, timestamptz)` is executable only by `service_role` and supplies the crop monitor's aggregate inputs.

The migration has not been applied to a hosted project. Before rollout, apply it through the normal migration process and run `supabase/tests/crop_activity_summary_reads.sql` against the target database. Keep the migration in place while any deployed web, mobile, or edge function version calls these RPCs.

Rollback sequence:

1. Roll web, Android, and the `crop-monitor` function back to versions that do not call the new RPCs.
2. Confirm no deployed client or scheduled function still calls either RPC.
3. Apply a new rollback migration containing:

   ```sql
   drop function if exists public.get_crop_monitor_inputs(uuid[], timestamptz, timestamptz);
   drop function if exists public.get_crop_activity_summaries(uuid[], timestamptz, timestamptz);
   ```

This rollback removes only the two additive functions and does not alter stored records or existing API contracts.

## Coverage register

The repository's browser suite documents its route/action coverage in `web-admin/e2e/README.md`. Results below distinguish checks that ran from coverage that requires the unavailable local database or device.

| Feature group | Evidence or test | Result in this execution |
|---|---|---|
| Web lint | `npm run lint` | **Passed**, 0 errors, 5 pre-existing/style warnings. |
| Web production build | `npm run build` | **Passed** after local Poppins bundling; the build type check and route generation completed. |
| Web input contracts | `npm run test:input-contract` | **Passed**, 11 tests. |
| Browser E2E isolation guard | `npm run test:e2e:safety` | **Passed**, 3 tests: allows local credentials and rejects remote hosts or inferred app credentials. |
| Visible polling utility | `node --test src/lib/visible-polling.test.mjs` | **Passed** in the earlier verification pass: 5 tests. |
| Browser test inventory | `npm run test:e2e:list` | **Passed**, listed 55 Playwright cases across authentication/roles and API authorization, inventory, sales, customers, crop workflows, dashboard/reports, monitoring, and users. |
| Local-only browser CI configuration | YAML parse, `npm run check:tracked-secrets`, `npm run check:shared-workflows` | **Passed**; the workflow no longer requires hosted Supabase credentials. |
| Browser workflow: login/logout, inactive-account rejection, five roles, API authorization, inventory and stock history, sales/cancellation, discounts, field care, repeat harvest and closure, planting names, users, dashboard, exports, notifications/logs, rover monitor | `web-admin/e2e/README.md` and its Playwright suite | **Blocked for execution**: local Supabase Docker engine pipe is unavailable; no remote project was used. |
| Deferred web cases: password recovery, session expiry/account switching, investments, installment collection, single harvest/corrections, photo upload, email delivery, live AI/weather | `web-admin/e2e/README.md` | **Not covered by the current browser suite**; they are not treated as passes. |
| New database functions, SQL permission tests, RLS and full business SQL regressions | `supabase/tests/*.sql` including the new crop summary test | **Blocked**: no local Supabase database could be started. |
| Targeted Dart analysis of changed crop/dashboard files | Dart analyzer | **Passed analysis** (“No issues found”); the command then exited nonzero when telemetry attempted to update a user-profile file outside the workspace. |
| Full Flutter analysis and unit/widget tests | `flutter analyze` and `flutter test` | **Blocked / incomplete**: Flutter's tool process did not return a result during this run. No test failure is inferred from the hang. |
| Android debug build | `android/gradlew.bat assembleDebug` | **Passed**, `BUILD SUCCESSFUL`; generated the debug APK. |
| Emulator navigation/lifecycle/integration tests | API 35 AVDs are installed but no emulator was active; the repository has no `integration_test/` suite yet | **Blocked / not completed**: local Supabase was unavailable and the Flutter test runner did not return. No Android behavior is marked passed. |
| Rover simulator, hardware, external push/email/weather/AI delivery | Requires running local stack or external/device delivery | **Pending**. Physical rover verification is explicitly pending. |

The repository's previously modified state was preserved. At execution start, more than 139 tracked files were already modified and numerous untracked files were present; this report does not attribute those unrelated changes to the optimization work.

## Measurements

No comparable request-count, byte-transfer, query-latency, screen-load, or Android-memory measurements could be captured because the local Supabase stack and responsive Flutter test runner were unavailable. The values below are **code-path count reductions**, not measured performance or log-ingestion savings:

| Scenario | Before | After | Measurement status |
|---|---|---|---|
| Crop overview activity metrics | Paginated reads of the complete activity history | One aggregate RPC | Source-level query-path comparison; runtime request/byte counts pending. |
| Crop monitor watering and sensor input | Two reads per crop per invocation | One batched aggregate RPC per invocation | Source-level query-path comparison; function regression test pending. |
| Crop activity history photos on web | Attachment lookup and signed-URL request per record/photo | One attachment query and batched signing (up to 100 paths/request) | Source-level query-path comparison; large-history browser scenario pending. |
| Repeated scheduled web polls | 5-second rover refresh and 20-second connectivity checks | 30-second and 120-second checks while visible | Interval arithmetic: 83% fewer scheduled polls; real request/log savings pending. |

Supabase usage reading supplied by the owner on 2026-10-18: **0.916 / 1 GB (92%)**, leaving about **84 MB** before the allowance. This is organization usage, not a per-project measurement. It cannot predict future ingestion. Continue the 9 AM Manila daily tracker and compare 24–48 hours of actual usage after deploying approved changes. Do not claim the free allowance will last through the next cycle unless measured daily usage supports that conclusion.

## Follow-up needed before acceptance

1. Restore Docker engine access, start the isolated Supabase stack, and run the SQL permissions tests plus the browser E2E suite against synthetic data.
2. Resolve the Flutter tooling stall, then run analysis, all Flutter tests, a debug Android build, and emulator integration tests pointed only at local Supabase.
3. Exercise empty, normal, and over-one-page crop histories; account switching; background/resume; realtime events during requests; and repeated navigation. Record request/byte counts and three-run median/p95 timings before and after.
4. Complete coverage deferred by the existing browser suite (financial installment/investment and advanced harvest workflows) and map each actual route/action to test evidence.
5. Keep external delivery and physical rover checks pending until those real environments are available. Review the generated feature-specific test register before production rollout.
