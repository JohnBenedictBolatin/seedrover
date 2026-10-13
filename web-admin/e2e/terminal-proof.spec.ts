import { expect, test } from '@playwright/test';

test('Supplementary terminal proof: SeedRover login screen renders', async ({ page }) => {
  const response = await page.goto('/login');

  expect(response?.status()).toBe(200);
  await expect(page.getByRole('heading', { name: 'Manage your farm in one convenient system.' })).toBeVisible();
  await expect(page.getByLabel('Username')).toBeVisible();
  await expect(page.getByLabel('Password', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Log in' })).toBeVisible();
});
