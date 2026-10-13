import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { accounts, asRole, db, check, prefix, track, evidence, inventory, openItem } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page); });
test('SR-OBS-001 Mark a dedicated notification read and verify persistence', async ({ page }, info) => {
  const id = randomUUID(); const title = `${prefix}_notification`; track('notifications', id, title);
  check((await db().from('notifications').insert({ id, recipient_id: accounts().admin.id, title,
    message: 'Synthetic browser-test notification', notification_type: 'System', is_read: false })).error);
  await page.goto('/notifications'); const card = page.locator('article').filter({ hasText: title });
  await card.getByRole('button', { name: 'Mark read', exact: true }).click();
  await expect.poll(async () => (await db().from('notifications').select('is_read').eq('id', id).single()).data?.is_read).toBe(true);
  await page.reload(); await expect(page.locator('article').filter({ hasText: title })).toHaveAttribute('data-read', 'true'); await evidence(page, info);
});
test('SR-OBS-002 Inventory edit creates an attributable activity record', async ({ page }, info) => {
  const item = await inventory('activity'); const form = await openItem(page, item.name, 'Edit');
  await form.locator('[name="storage_location"]').fill('AUTOTEST LOGGED'); await form.getByRole('button', { name: 'Save Item', exact: true }).click();
  await expect.poll(async () => (await db().from('activity_logs').select('id').eq('user_id', accounts().admin.id).ilike('description', `%${item.name}%`)).data?.length).toBeGreaterThan(0);
  await page.goto('/activity-log'); await expect(page.getByRole('heading', { level: 1 })).toContainText(/Activity/i);
  const search = page.locator('input[placeholder*="Search"]'); await search.fill(item.name);
  await expect(page.getByText(item.name, { exact: false }).first()).toBeVisible(); await evidence(page, info);
});
test('SR-OBS-003 Rover monitoring presents existing stale or unavailable data honestly', async ({ page }, info) => {
  await page.goto('/rover-monitor'); await expect(page.getByRole('heading', { name: 'Rover Monitor' })).toBeVisible();
  const staleState = page.getByText('Stale', { exact: true });
  const missingState = page.getByText('No verified hardware reading is available.', { exact: true });
  if (await staleState.count() === 0 && await missingState.count() === 0) {
    await evidence(page, info, 'current-sensor-state');
    test.skip(true, 'Blocked: shared database has fresh readings; suite will not overwrite global rover state to force stale/no-data.');
  }
  if (await staleState.count()) {
    await expect(page.getByText('Verified hardware', { exact: true })).toBeVisible();
    const values = page.getByRole('region', { name: 'Latest sensor values' });
    await expect(values.getByText('4.6%', { exact: true })).toBeVisible();
    await expect(values.getByText('31.9°C', { exact: true })).toBeVisible();
  } else {
    await expect(missingState).toBeVisible();
    await expect(page.getByRole('region', { name: 'Latest sensor values' }).getByText('Unavailable', { exact: true })).toHaveCount(4);
  }
  await evidence(page, info);
});
test('SR-OBS-004 Rover monitor exposes no movement or planting controls', async ({ page }, info) => {
  await page.goto('/rover-monitor');
  await expect(page.getByRole('heading', { name: 'Rover Monitor' })).toBeVisible();
  await expect(page.getByRole('button', { name: /^(forward|backward|left|right|start planting|stop planting|emergency stop)$/i })).toHaveCount(0);
  await evidence(page, info);
});
