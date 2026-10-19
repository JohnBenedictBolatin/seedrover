import { test, expect, type Page, type Locator } from '@playwright/test';
import { asRole, balance, check, confirm, crop, db, evidence, fillSale, produceInventory, prefix, selectNamed, submitSale } from '../support';

const calamansiStageLabels: Record<string, string> = {
  Seedbed: 'Seeds in nursery',
  Germinating: 'Seeds sprouting',
  'Nursery Seedling': 'Seedlings growing in nursery',
  'Transplant Review': 'Check seedlings before moving',
  Establishing: 'Settling in after moving',
  Juvenile: 'Young tree growing',
  'First Bearing': 'First fruits appearing',
};

const activityLabels: Record<string, string> = {
  Watered: 'Watering',
  Fertilized: 'Fertilizing',
  Inspected: 'Field check',
  'Stage Observed': 'Observe growth',
  Transplanted: 'Transplanting',
};

async function openCrop(page: Page, searchName: string) {
  await page.goto('/crops');
  await page.getByPlaceholder('Search crop, batch ID, field...').fill(searchName);
  await page.locator('article').filter({ hasText: searchName })
    .getByRole('button', { name: /View details for/ }).click();
}

async function openCareForm(page: Page, searchName: string) {
  await openCrop(page, searchName);
  await page.getByRole('button', { name: 'RECORD ACTIVITY', exact: true }).click();
  return page.getByRole('dialog', { name: 'Record care' });
}

async function chooseActivity(form: Locator, activity: string) {
  const activitySelect = form.locator('button[aria-expanded]').first();
  await activitySelect.click();
  await form.getByRole('button', { name: activity, exact: true }).last().click();
}

async function assertActivity(cropId: string, notes: string, expected: Record<string, unknown>) {
  await expect.poll(async () => {
    const { data, error } = await db().from('crop_activities').select('*')
      .eq('crop_id', cropId).eq('notes', notes).maybeSingle();
    check(error);
    return data;
  }).not.toBeNull();
  const { data, error } = await db().from('crop_activities').select('*')
    .eq('crop_id', cropId).eq('notes', notes).single();
  check(error);
  for (const [key, value] of Object.entries(expected)) expect(data![key]).toEqual(value);
  return data!;
}

test.beforeEach(async ({ page }) => { await asRole(page, 'planting'); });

test('SR-CORE-001 Calamansi planting, care, every stage, repeat harvest, inventory sale and second harvest', async ({ page }, info) => {
  // Plant through the same authorized rover receipt RPC used by the app. The
  // fixture is synthetic and explicitly marked as not physically hardware-tested.
  const planting = await crop('full_lifecycle_calamansi', 'calamansi');
  const produce = await produceInventory('Calamansi');
  const startingQuantity = await balance(produce.id);
  const oldestExistingBatch = await db().from('inventory_stock_batches')
    .select('id, remaining_quantity').eq('inventory_id', produce.id)
    .order('created_at', { ascending: true }).limit(1).maybeSingle();
  check(oldestExistingBatch.error);

  const plantingReceipt = await db().from('planting_logs')
    .select('id, crop_id, confirmation_outcome, planting_status, sync_payload')
    .eq('id', planting.plantingLogId).single();
  check(plantingReceipt.error);
  expect(plantingReceipt.data!.crop_id).toBe(planting.id);
  expect(plantingReceipt.data!.confirmation_outcome).toBe('Row Planted');
  expect(plantingReceipt.data!.sync_payload).toMatchObject({ synthetic_fixture: true, hardware_verified: false });
  await info.attach('planting-receipt', { body: JSON.stringify(plantingReceipt.data, null, 2), contentType: 'application/json' });
  await openCrop(page, planting.name);
  await expect(page.getByRole('dialog', { name: /Crop details for Calamansi/ })).toBeVisible();
  await evidence(page, info, 'planted-crop');

  // Record the four recurring care actions available to this crop. Calamansi
  // also supports Transplanted, which is exercised at its transplant stage below.
  const waterNotes = `${prefix}_lifecycle_water`;
  let form = await openCareForm(page, planting.name);
  await chooseActivity(form, activityLabels.Watered);
  await form.locator('input[name="quantity"]').fill('100');
  await form.locator('[name="notes"]').fill(waterNotes);
  await form.getByRole('button', { name: 'SAVE WATERING', exact: true }).click();
  await assertActivity(planting.id, waterNotes, { activity_type: 'Watered', quantity: 100, unit: 'ml' });

  const fertilizerNotes = `${prefix}_lifecycle_fertilizer`;
  form = await openCareForm(page, planting.name);
  await chooseActivity(form, activityLabels.Fertilized);
  await form.locator('input[name="quantity"]').fill('10');
  await form.locator('input[name="unit"]').fill('g');
  await form.locator('input[name="material"]').fill('Organic compost');
  await form.locator('[name="notes"]').fill(fertilizerNotes);
  await form.getByRole('button', { name: 'SAVE FERTILIZING', exact: true }).click();
  await assertActivity(planting.id, fertilizerNotes, {
    activity_type: 'Fertilized', quantity: 10, unit: 'g', material: 'Organic compost',
  });

  const inspectionNotes = `${prefix}_lifecycle_inspection`;
  form = await openCareForm(page, planting.name);
  await chooseActivity(form, activityLabels.Inspected);
  await selectNamed(form, 'material', 'Looks normal');
  await form.locator('[name="notes"]').fill(inspectionNotes);
  await form.getByRole('button', { name: 'SAVE FIELD CHECK', exact: true }).click();
  await assertActivity(planting.id, inspectionNotes, { activity_type: 'Inspected', material: 'Looks normal' });

  const profile = await db().from('crop_profiles').select('stage_plan').eq('profile_key', 'calamansi').single();
  check(profile.error);
  const stages = (profile.data!.stage_plan as { stage: string }[]).map(({ stage }) => stage);
  expect(stages).toEqual(Object.keys(calamansiStageLabels));

  const transplantNotes = `${prefix}_lifecycle_transplant`;
  async function recordTransplant() {
    const transplantForm = await openCareForm(page, planting.name);
    await chooseActivity(transplantForm, activityLabels.Transplanted);
    await transplantForm.locator('input[name="material"]').fill('Field 1, north orchard row');
    await transplantForm.locator('[name="notes"]').fill(transplantNotes);
    await transplantForm.getByRole('button', { name: 'SAVE TRANSPLANTING', exact: true }).click();
    await assertActivity(planting.id, transplantNotes, {
      activity_type: 'Transplanted', material: 'Field 1, north orchard row',
    });
  }

  // Observe and verify every configured Calamansi stage in order. The next
  // observation is selected using its farmer-facing label; the canonical stage
  // saved by the server is checked after each submission.
  for (const stage of stages) {
    const notes = `${prefix}_lifecycle_stage_${stage.replaceAll(' ', '_')}`;
    form = await openCareForm(page, planting.name);
    await chooseActivity(form, activityLabels['Stage Observed']);
    await selectNamed(form, 'observed_stage', calamansiStageLabels[stage]);
    await form.locator('[name="notes"]').fill(notes);
    await form.getByRole('button', { name: 'SAVE OBSERVE GROWTH', exact: true }).click();
    const activity = await assertActivity(planting.id, notes, {
      activity_type: 'Stage Observed', observed_stage: stage,
    });
    expect(activity.id).toBeTruthy();
    const cropState = await db().from('crops').select('growth_stage,crop_status')
      .eq('id', planting.id).single();
    check(cropState.error);
    expect(cropState.data!.growth_stage).toBe(stage);
    expect(['Active', 'Needs Attention', 'Harvest Ready']).toContain(cropState.data!.crop_status);
    await info.attach(`stage-${stage.replaceAll(' ', '-')}`, {
      body: JSON.stringify({ stage, displayedAs: calamansiStageLabels[stage], activityId: activity.id }, null, 2),
      contentType: 'application/json',
    });
    if (stage === 'Transplant Review') await recordTransplant();
  }
  await evidence(page, info, 'all-growth-stages-observed');

  async function harvest(quantity: number, marker: string, expectedCount: number) {
    await openCrop(page, planting.name);
    await page.getByRole('tab', { name: 'GROWTH JOURNEY', exact: true }).click();
    await page.getByRole('button', { name: 'Record harvest', exact: true }).click();
    const harvestForm = page.getByRole('dialog', { name: 'Record harvest' }).locator('form');
    await harvestForm.locator('input[name="quantity"]').fill(String(quantity));
    await harvestForm.locator('[name="notes"]').fill(marker);
    await harvestForm.getByRole('button', { name: 'REVIEW HARVEST', exact: true }).click();
    await confirm(page, 'Review harvest', 'RECORD HARVEST');
    await expect.poll(async () => {
      const { data, error } = await db().from('crop_harvests').select('id')
        .eq('crop_id', planting.id);
      check(error); return data?.length ?? 0;
    }).toBe(expectedCount);
  }

  await harvest(5, `${prefix}_lifecycle_first_pick`, 1);
  const firstHarvest = await db().from('crop_harvests')
    .select('id, inventory_id, quantity').eq('crop_id', planting.id).single();
  check(firstHarvest.error);
  expect(Number(firstHarvest.data!.quantity)).toBe(5);
  expect(firstHarvest.data!.inventory_id).toBe(produce.id);
  expect(await balance(produce.id)).toBe(startingQuantity + 5);
  const firstReceipt = await db().from('inventory_transactions').select('id')
    .eq('source', 'harvest').eq('source_id', firstHarvest.data!.id).single();
  check(firstReceipt.error);
  const firstBatchQuery = await db().from('inventory_stock_batches')
    .select('id, initial_quantity, remaining_quantity').eq('source_transaction_id', firstReceipt.data!.id);
  check(firstBatchQuery.error);
  expect(firstBatchQuery.data).toHaveLength(1);
  const firstBatch = firstBatchQuery.data![0];
  expect(Number(firstBatch.initial_quantity)).toBe(5);
  expect(Number(firstBatch.remaining_quantity)).toBe(5);

  // Switch to the inventory role for the sale, then return to planting for the
  // next pick, proving the shared record survives the role and page boundary.
  await page.context().clearCookies();
  await asRole(page, 'inventory');
  await fillSale(page, [{ name: 'Calamansi', quantity: 2 }], 'lifecycle_sale', 200);
  const sale = await submitSale(page, 'lifecycle_sale');
  expect(Number(sale.total_amount)).toBe(100);
  const saleLine = await db().from('sales_order_items')
    .select('inventory_id, quantity_sold, unit_price, line_total')
    .eq('sales_order_id', sale.id).single();
  check(saleLine.error);
  expect(saleLine.data!.inventory_id).toBe(produce.id);
  expect(Number(saleLine.data!.quantity_sold)).toBe(2);
  expect(Number(saleLine.data!.line_total)).toBe(100);
  expect(await balance(produce.id)).toBe(startingQuantity + 3);
  const saleMovement = await db().from('inventory_transactions')
    .select('id, quantity, transaction_type').eq('inventory_id', produce.id)
    .eq('source', 'sale').eq('source_id', sale.id).single();
  check(saleMovement.error);
  const saleAllocation = await db().from('inventory_transaction_batch_allocations')
    .select('batch_id, quantity').eq('transaction_id', saleMovement.data!.id).single();
  check(saleAllocation.error);
  expect(saleAllocation.data!.batch_id).toBe(oldestExistingBatch.data?.id ?? firstBatch.id);
  expect(Number(saleAllocation.data!.quantity)).toBe(2);
  const allocatedBatch = await db().from('inventory_stock_batches').select('remaining_quantity')
    .eq('id', saleAllocation.data!.batch_id).single();
  check(allocatedBatch.error);
  expect(Number(allocatedBatch.data!.remaining_quantity)).toBe(oldestExistingBatch.data
    ? Number(oldestExistingBatch.data.remaining_quantity) - 2 : 3);
  await evidence(page, info, 'first-harvest-sold-from-oldest-batch');

  await page.context().clearCookies();
  await asRole(page, 'planting');
  await harvest(4, `${prefix}_lifecycle_second_pick`, 2);
  const harvestRows = await db().from('crop_harvests').select('id, inventory_id, quantity')
    .eq('crop_id', planting.id).order('created_at', { ascending: true });
  check(harvestRows.error);
  expect(harvestRows.data).toHaveLength(2);
  expect(new Set(harvestRows.data!.map((row) => row.id)).size).toBe(2);
  expect(harvestRows.data!.every((row) => row.inventory_id === produce.id)).toBe(true);
  expect(harvestRows.data!.map((row) => Number(row.quantity))).toEqual([5, 4]);
  expect(await balance(produce.id)).toBe(startingQuantity + 7);
  const secondReceipt = await db().from('inventory_transactions').select('id')
    .eq('source', 'harvest').eq('source_id', harvestRows.data![1].id).single();
  check(secondReceipt.error);
  const finalBatches = await db().from('inventory_stock_batches')
    .select('id, initial_quantity, remaining_quantity').eq('source_transaction_id', secondReceipt.data!.id);
  check(finalBatches.error);
  expect(finalBatches.data).toHaveLength(1);
  expect(finalBatches.data!.map((batch) => Number(batch.initial_quantity))).toEqual([4]);
  expect(finalBatches.data!.map((batch) => Number(batch.remaining_quantity))).toEqual([4]);

  const finalCrop = await db().from('crops')
    .select('crop_status, growth_stage, harvest_mode').eq('id', planting.id).single();
  check(finalCrop.error);
  expect(finalCrop.data!.crop_status).not.toBe('Completed');
  expect(finalCrop.data!.crop_status).not.toBe('Cancelled');
  expect(finalCrop.data!.harvest_mode).toBe('repeat');
  const harvestTransactions = await db().from('inventory_transactions')
    .select('id, source_id').eq('inventory_id', produce.id).eq('source', 'harvest')
    .in('source_id', harvestRows.data!.map((row) => row.id));
  check(harvestTransactions.error);
  expect(harvestTransactions.data).toHaveLength(2);
  await evidence(page, info, 'second-harvest-stock-and-active-crop');
  await info.attach('workflow-result', {
    body: JSON.stringify({ cropId: planting.id, cropType: 'Calamansi', stagesObserved: stages,
      careActivities: ['Watered', 'Fertilized', 'Inspected', 'Transplanted', 'Stage Observed × 7'],
      harvestsKg: [5, 4], soldKg: 2, remainingInventoryKg: 7,
      batches: finalBatches.data, cropStatus: finalCrop.data!.crop_status }, null, 2),
    contentType: 'application/json',
  });
});
