import { test, expect } from '@playwright/test';
import { asRole } from '../support';

test('log budget: manual refresh and connectivity recovery', async ({ page }) => {
  await asRole(page);
  let checks = 0;
  let healthy = true;
  await page.route('**/api/connectivity', async route => {
    checks++;
    await route.fulfill({ status: healthy ? 200 : 503,
      contentType: 'application/json', body: JSON.stringify({ connected: healthy }) });
  });
  await page.goto('/rover-monitor');
  await expect(page.getByRole('heading', { name: 'Rover Monitor' })).toBeVisible();
  const refresh = page.getByRole('button', { name: 'Refresh now', exact: true });
  await expect(refresh).toBeEnabled();
  const refreshed = page.waitForResponse(response => response.url().includes('/rover-monitor?') && response.request().headers()['rsc'] === '1');
  await refresh.click();
  await refreshed;
  await expect(refresh).toBeEnabled();
  await expect.poll(() => checks).toBe(1);
  // Simulate browser visibility transitions while using the real mounted component.
  await page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'hidden' });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.install();
  await page.clock.runFor(300_000);
  expect(checks).toBe(1);
  healthy = false;
  await page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, value: 'visible' });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.getByRole('status')).toContainText('temporarily unavailable');
  await expect.poll(() => checks).toBe(2);
  healthy = true;
  await page.clock.runFor(2000);
  await page.evaluate(() => window.dispatchEvent(new Event('online')));
  await expect(page.getByRole('status')).toContainText('Connection restored');
  await expect.poll(() => checks).toBe(3);
  await page.clock.runFor(3500);
  await expect(page.getByText('Connection restored. Refreshing data is safe.')).toHaveCount(0);
});
