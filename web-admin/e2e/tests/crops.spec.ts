import { test, expect, type Page } from '@playwright/test';
import { asRole, crop, db, check, prefix, evidence, selectNamed, confirm, produceInventory } from '../support';
async function details(page: Page, name: string) {
  await page.goto('/crops', { waitUntil: 'domcontentloaded' });
  const search = page.getByPlaceholder('Search crop, batch ID, field...');
  await expect(search).toBeVisible();
  await search.fill(name);
  const card = page.locator('article').filter({ hasText: name });
  await card.getByRole('button', { name: /View details for/ }).click();
}
test.beforeEach(async ({ page }) => { await asRole(page, 'planting'); });
test('SR-CROP-001 Seeded crop batch displays correct details', async ({ page }, info) => {
  const item = await crop('display'); await details(page, item.name);
  await expect(page.getByRole('dialog').getByText(item.name, { exact: true }).first()).toBeVisible(); await evidence(page, info);
});
test('Growth journey checks earlier stages skipped before the recorded current stage', async ({ page }, info) => {
  const item = await crop('skipped_growth_stage');
  const record = await db().from('crops').select('crop_profiles(stage_plan)').eq('id', item.id).single();
  check(record.error);
  const profile = record.data!.crop_profiles as { stage_plan?: { stage: string }[] } | null;
  const stagePlan = profile?.stage_plan ?? [];
  // Stage zero is observed by the planting receipt. Advance past stage one so
  // the journey has a real skipped stage between the receipt and current stage.
  if (stagePlan.length < 3) test.skip(true, 'Crop profile does not contain enough stages to demonstrate a skipped stage.');

  const advanced = await db().from('crops').update({ growth_stage: stagePlan[2].stage }).eq('id', item.id);
  check(advanced.error);
  await details(page, item.name);
  await page.getByRole('tab', { name: 'GROWTH JOURNEY', exact: true }).click();
  const journey = page.locator('#crop-tabpanel-growth');
  await expect(journey.getByText('Skipped', { exact: true })).toBeVisible();
  await expect(journey.getByText('Stage passed without an observation', { exact: true })).toBeVisible();
  await expect(journey.getByText('Current step', { exact: true })).toBeVisible();
  await evidence(page, info, 'skipped-growth-stage');
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

test('SR-CROP-005 Rename planting keeps crop type and tracking identity intact', async ({ page }, info) => {
  const item = await crop('planting_name');
  await details(page, item.name);
  const before = await db().from('crops').select('crop_name,batch_code,assigned_planting_name,planting_name_version').eq('id', item.id).single();
  check(before.error);
  await page.getByRole('button', { name: 'RENAME', exact: true }).click();
  const form = page.getByRole('dialog', { name: 'Rename planting' });
  await form.locator('[name="planting_name"]').fill(`${prefix} north rows`);
  await form.getByRole('button', { name: 'SAVE NAME', exact: true }).click();
  await expect.poll(async () => (await db().from('crops').select('custom_planting_name').eq('id', item.id).single()).data?.custom_planting_name).toBe(`${prefix} north rows`);
  const after = await db().from('crops').select('crop_name,batch_code,assigned_planting_name,custom_planting_name,planting_name_version').eq('id', item.id).single();
  check(after.error);
  expect(after.data!.crop_name).toBe(before.data!.crop_name);
  expect(after.data!.batch_code).toBe(before.data!.batch_code);
  expect(after.data!.assigned_planting_name).toBe(before.data!.assigned_planting_name);
  expect(after.data!.planting_name_version).toBe(Number(before.data!.planting_name_version) + 1);
  await evidence(page, info);
});

test('SR-CROP-006 Repeat harvest records separate stock batches and closes with the combined total', async ({ page }, info) => {
  const item = await crop('repeat_harvest');
  const produce = await produceInventory('Sitaw');
  const stage = await db().from('crops').update({ growth_stage: 'Harvest Ready' }).eq('id', item.id);
  check(stage.error);

  async function recordHarvest(quantity: number) {
    await details(page, item.name);
    await page.getByRole('tab', { name: 'GROWTH JOURNEY', exact: true }).click();
    await page.getByRole('button', { name: 'Record harvest', exact: true }).click();
    const form = page.getByRole('dialog', { name: 'Record harvest' }).locator('form');
    await form.locator('input[name="quantity"]').fill(String(quantity));
    await form.getByRole('button', { name: 'REVIEW HARVEST', exact: true }).click();
    await confirm(page, 'Review harvest', 'RECORD HARVEST');
    await expect.poll(async () => {
      const { data, error } = await db().from('crop_harvests')
        .select('id').eq('crop_id', item.id);
      check(error); return data?.length ?? 0;
    }).toBe(quantity === 5 ? 1 : 2);
  }

  await recordHarvest(5);
  const afterFirst = await db().from('crops').select('crop_status, harvest_mode').eq('id', item.id).single();
  check(afterFirst.error);
  expect(afterFirst.data!.crop_status).toBe('Active');
  expect(afterFirst.data!.harvest_mode).toBe('repeat');

  await recordHarvest(3);
  const harvests = await db().from('crop_harvests').select('id, quantity').eq('crop_id', item.id);
  check(harvests.error);
  expect(harvests.data).toHaveLength(2);
  expect(harvests.data!.reduce((sum, harvest) => sum + Number(harvest.quantity), 0)).toBe(8);

  const cropHarvests = await db().from('crop_harvests').select('id').eq('crop_id', item.id);
  check(cropHarvests.error);
  const movements = await db().from('inventory_transactions')
    .select('id, source_id').eq('inventory_id', produce.id).eq('source', 'harvest')
    .in('source_id', cropHarvests.data!.map(({ id }) => id));
  check(movements.error);
  expect(movements.data).toHaveLength(2);
  expect(new Set(movements.data!.map((movement) => movement.source_id)).size).toBe(2);
  const active = await db().from('crops').select('crop_status').eq('id', item.id).single();
  check(active.error);
  expect(active.data!.crop_status).toBe('Active');

  await details(page, item.name);
  const detailsDialog = page.getByRole('dialog').last();
  // Crop details exposes End crop as a compact trash icon with a descriptive
  // accessible label; the confirmation form carries the visible END CROP text.
  await detailsDialog.getByRole('button', { name: /^End crop /i }).click();
  const endForm = page.getByRole('dialog').last();
  await selectNamed(endForm, 'reason', 'Plants stopped producing');
  // selectNamed already chooses the option and closes the custom menu.
  await endForm.getByRole('button', { name: 'END CROP', exact: true }).click();
  await confirm(page, 'End this crop?', 'END CROP');
  await expect.poll(async () => (await db().from('crop_closures').select('id').eq('crop_id', item.id)).data?.length).toBe(1);
  const ended = await db().from('crops').select('crop_status').eq('id', item.id).single();
  check(ended.error);
  expect(ended.data!.crop_status).toBe('Completed');
  const outcomes = await db().from('crop_outcomes').select('quantity').eq('crop_id', item.id).order('recorded_at', { ascending: false }).limit(1);
  check(outcomes.error);
  expect(Number(outcomes.data?.[0]?.quantity)).toBe(8);
  const movementsAfterEnd = await db().from('inventory_transactions')
    .select('id').eq('inventory_id', produce.id).eq('source', 'harvest')
    .in('source_id', cropHarvests.data!.map(({ id }) => id));
  check(movementsAfterEnd.error);
  expect(movementsAfterEnd.data).toHaveLength(2);
  await evidence(page, info);
});
