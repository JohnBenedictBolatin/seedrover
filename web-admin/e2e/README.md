# SeedRover browser automation

This suite uses the existing **development/demo Supabase project**. It creates synthetic records and disables its test accounts after each run. It never resets the database, applies migrations, operates rover hardware, or modifies pre-existing demo records.

## Setup

Use Node.js **22.x** and run these commands in `web-admin`. PowerShell users can use the ignored portable runtime supplied on this workstation; on other machines, install Node 22 and skip the first two lines. The `.cmd` forms avoid PowerShell script-policy issues.

```powershell
$env:PATH = (Resolve-Path '..\tmp\node-runtime\node-v22.23.3-win-x64').Path + ';' + $env:PATH
npm.cmd ci
npx.cmd playwright install chromium
npm.cmd run test:e2e:preflight
```

The normal `.env.local` supplies `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and the server-only `SUPABASE_SERVICE_ROLE_KEY`. Create an ignored `.env.e2e.local` containing:

```dotenv
E2E_EXPECTED_SUPABASE_HOST=your-reviewed-demo-project.supabase.co
```

Copy the hostname printed by the read-only preflight **only after checking it is the intended demo project**. A mismatch stops execution before account creation. On this workstation, a portable Node 22 runtime and a browser cache were installed under the repository's ignored `tmp` folder; no system runtime was changed.

## Execute

```powershell
npm.cmd run test:e2e:smoke
npm.cmd run test:e2e
npm.cmd run test:e2e:list
```

The runner builds and starts the application at `http://127.0.0.1:3100`, uses Chromium, Asia/Manila time, one worker and zero retries. Stop any other service using port 3100 first. `E2E_SKIP_BUILD=1` may be used only when the exact current application source has already been built. Never use it in CI.

Each run has its own directory under `e2e/runs/<run-id>`; `latest.txt` identifies the last run. Open its HTML report with:

```powershell
npx playwright show-report e2e/runs/<run-id>/html
```

Authentication state and generated passwords are stored only under ignored `e2e/.private`. These files are excluded from CI uploads and removed during normal teardown. Browser traces may contain test-session details and should remain in the team's private evidence archive.

## Isolation and cleanup

- Account usernames start `at_`; business record names/notes start `AUTOTEST_<run-id>`.
- `records.jsonl` journals exact IDs; `cleanup.json` records each cleanup result.
- Tests receive independent fixtures, with no dependency on another case's output.
- Dedicated test accounts are deactivated. Test business transactions, inventory opening history, crop history, and activity logs are retained for audit/evidence. Dedicated notification fixtures are removed by exact ID.
- Retained records affect demo totals. Tests compare recorded baselines and deltas, not an assumed empty database.
- A filesystem lock prevents simultaneous local runs. The manual CI workflow serializes its runs; do not run local and CI tests against the shared project simultaneously.
- If a process is forcibly terminated, review the run manifest and recover cleanup using `npm run test:e2e:cleanup -- <run-id>` before deleting a stale local lock. Never delete database rows using a broad `AUTOTEST%` query.

## Scope and limitations

The suite covers authentication, five roles, inventory, ordinary sales, customers/discounts, crop care, user management, dashboard, CSV/print views, notifications/logs, and read-only rover monitoring. API authorization cases are labelled separately in their titles. CSV content is tested through the browser's authenticated request context. Chromium renders a real receipt PDF; native OS print dialogs are not automated.

Crop editing is explicitly blocked when no edit control is reachable. Stale/no-data rover testing is blocked when the shared database contains fresh readings: the suite does not overwrite the global rover state. A blocked case is not a pass.

Deferred: investments, installment collection, advanced crop closure/harvest, email delivery, live AI/weather, Flutter mobile, and physical rover behavior.

## Report generation

Install `scripts/automation-report-requirements.txt` in a Python virtual environment, then run from the repository root:

```powershell
python scripts/generate_automation_report.py --run <run-id>
```

The generator produces Word/PDF reports, CSV registers, and an evidence index in `docs/automation`. The original template's 17 headings are retained. Metrics come from the selected Playwright result file; historical runs and defect retests are identified separately. Human reviewer names and sign-off remain pending.

## GitHub Actions

`SeedRover browser evidence` is a **workflow_dispatch** workflow. Configure three repository secrets matching the Supabase variable names above, and repository variable `E2E_EXPECTED_SUPABASE_HOST`. Choose `smoke` or `full` in Actions. No workflow has been remotely dispatched merely by adding this file. Reports upload even after failure; external notifications are not configured.
