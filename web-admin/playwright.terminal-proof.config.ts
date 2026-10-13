import { defineConfig, devices } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

// Direct `npx playwright test` invocation bypasses run-e2e.mjs, so load the
// repository's browser-cache setting before Playwright resolves Chromium.
const localE2eEnv = path.resolve(process.cwd(), '.env.e2e.local');
if (fs.existsSync(localE2eEnv)) process.loadEnvFile(localE2eEnv);

export default defineConfig({
  testDir: './e2e',
  testMatch: 'terminal-proof.spec.ts',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  reporter: [
    ['list'],
    ['html', { outputFolder: '../docs/automation/terminal-proof/html', open: 'never' }],
    ['json', { outputFile: '../docs/automation/terminal-proof/terminal-proof-results.json' }],
  ],
  outputDir: '../docs/automation/terminal-proof/test-results',
  use: {
    ...devices['Desktop Chrome'],
    baseURL: 'http://127.0.0.1:3100',
    viewport: { width: 1440, height: 1000 },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  ...(process.env.TERMINAL_PROOF_EXTERNAL_SERVER === '1' ? {} : {
    webServer: {
      command: `"${process.execPath}" node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port 3100`,
      url: 'http://127.0.0.1:3100/login',
      reuseExistingServer: false,
      timeout: 120_000,
    },
  }),
});
