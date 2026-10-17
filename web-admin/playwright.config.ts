import { defineConfig, devices } from '@playwright/test';
import path from 'node:path';

const runDir = process.env.E2E_RUN_DIR || path.resolve('e2e/runs/list-only');
export default defineConfig({
  testDir: './e2e/tests', fullyParallel: false, workers: 1, retries: 0,
  timeout: 60_000, expect: { timeout: 15_000 },
  globalSetup: './e2e/setup.ts', globalTeardown: './e2e/teardown.ts',
  outputDir: path.join(runDir, 'test-results'),
  reporter: [['list'], ['html', { outputFolder: path.join(runDir, 'html'), open: 'never' }],
    ['json', { outputFile: path.join(runDir, 'results.json') }]],
  use: { baseURL: 'http://127.0.0.1:3100', timezoneId: 'Asia/Manila',
    ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 },
    screenshot: 'only-on-failure', trace: 'retain-on-failure', video: 'retain-on-failure',
    actionTimeout: 15_000, navigationTimeout: 30_000 },
  projects: [{ name: 'chromium' }],
  webServer: { command: `"${process.execPath}" scripts/e2e-server.mjs`,
    url: 'http://127.0.0.1:3100/login', reuseExistingServer: false, timeout: 240_000 },
});
