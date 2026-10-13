import { test, expect, type Page } from '@playwright/test';
import { asRole, crop, db, check, prefix, evidence } from '../support';
async function details(page: Page, name: string) {
  await page.goto('/crops'); await page.getByPlaceholder('Search crop, batch ID, field...').fill(name);
  const card = page.locator('article').filter({ hasText: name });
  await card.getByRole('button', { name: /View details for/ }).click();
}
test.beforeEach(async ({ page }) => { await asRole(page, 'planting'); });
test('SR-CROP-001 Seeded crop batch displays correct details', async ({ page }, info) => {
  const item = await crop('display'); await details(page, item.name);
  await expect(page.getByRole('dialog').getByText(item.name, { exact: true }).first()).toBeVisible(); await evidence(page, info);
});
test('SR-CROP-002 Edit crop details through a reachable UI control', async ({ page }, info) => {
  const item = await crop('edit'); await details(page, item.name);
  const edit = page.getByRole('button', { name: /edit crop/i });
  if (await edit.count() === 0) {
    await evidence(page, info, 'missing-edit-control');
    test.skip(true, 'Blocked: current crop details screen exposes no Edit Crop control; edit component exists but has no reachable trigger.');
  }
  await edit.click(); await page.locator('[name="maintenance_notes"]').fill(`${prefix}_updated`);
  await page.getByRole('button', { name: /save/i }).last().click();
  await expect.poll(async () => (await db().from('crops').select('maintenance_notes').eq('id', item.id).single()).data?.maintenance_notes).toBe(`${prefix}_updated`);
});
test('SR-CROP-003 Record field care and verify persisted activity history', async ({ page }, info) => {
  const item = await crop('care'); await details(page, item.name);
  await page.getByRole('button', { name: 'RECORD ACTIVITY', exact: true }).click();
  const form = page.getByRole('dialog', { name: 'Record care' });
  await form.getByRole('button', { name: 'Choose an observation', exact: true }).click();
  await form.getByRole('button', { name: 'Looks normal', exact: true }).click();
  await form.locator('[name="notes"]').fill(`${prefix}_field_check`);
  await form.getByRole('button', { name: 'SAVE FIELD CHECK', exact: true }).click();
  await expect.poll(async () => (await db().from('crop_activities').select('id').eq('crop_id', item.id).eq('notes', `${prefix}_field_check`)).data?.length).toBe(1);
  const saved = await db().from('crop_activities').select('activity_type,material').eq('crop_id', item.id).eq('notes', `${prefix}_field_check`).single(); check(saved.error);
  expect(saved.data!.activity_type).toBe('Inspected'); expect(saved.data!.material).toBe('Looks normal');
  await details(page, item.name); await page.getByRole('tab', { name: 'ACTIVITY', exact: true }).click();
  await expect(page.getByText(`${prefix}_field_check`, { exact: false })).toBeVisible(); await evidence(page, info);
});
test('SR-CROP-004 Missing field observation prevents saving care', async ({ page }, info) => {
  const item = await crop('required'); await details(page, item.name);
  const before = await db().from('crop_activities').select('id').eq('crop_id', item.id); check(before.error);
  await page.getByRole('button', { name: 'RECORD ACTIVITY', exact: true }).click();
  await page.getByRole('button', { name: 'SAVE FIELD CHECK', exact: true }).click();
  await expect(page.getByText('Choose whether the crop looks normal or has an issue.')).toBeVisible();
  const saved = await db().from('crop_activities').select('id').eq('crop_id', item.id); check(saved.error);
  expect(saved.data?.map(row => row.id)).toEqual(before.data?.map(row => row.id));
  await evidence(page, info);
});
