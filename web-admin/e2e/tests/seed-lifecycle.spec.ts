import { randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { test, expect, type Locator, type Page } from '@playwright/test';
import {
  accounts, asRole, balance, check, confirm, crop, db, evidence, fillSale, harvestBatches, produceInventory,
  prefix, selectNamed, submitSale,
} from '../support';
import { localSupabaseConfig } from '../local-supabase.mjs';

const stageCopy: Record<string, string> = {
  Seeded: 'Seeds planted',
  Germinating: 'Seeds sprouting',
  Vegetative: 'Leaves and stems growing',
  Trellising: 'Vines growing on support',
  Flowering: 'Flowers opening',
  'Pod Formation': 'Pods starting to form',
  'First Harvest': 'Ready to harvest',
  Pegging: 'Peanut stems reaching into the soil',
  'Pod Development': 'Pods growing',
  'Maturity Check': 'Check if the crop is ready to harvest',
};

const activityCopy = {
  Watered: 'Watering',
  Fertilized: 'Fertilizing',
  Inspected: 'Field check',
  'Stage Observed': 'Observe growth',
} as const;

async function openCrop(page: Page, name: string) {
  await page.goto('/crops');
  await page.getByPlaceholder('Search crop, batch ID, field...').fill(name);
  await page.locator('article').filter({ hasText: name })
    .getByRole('button', { name: /View details for/ }).click();
}

async function openCareForm(page: Page, name: string) {
  await openCrop(page, name);
  await page.getByRole('button', { name: 'RECORD ACTIVITY', exact: true }).click();
  return page.getByRole('dialog', { name: 'Record care' });
}

async function chooseActivity(form: Locator, activity: string) {
  await form.locator('button[aria-expanded]').first().click();
  await form.getByRole('button', { name: activity, exact: true }).last().click();
}

async function assertSavedActivity(cropId: string, note: string, type: string, extra: Record<string, unknown> = {}) {
  await expect.poll(async () => {
    const { data, error } = await db().from('crop_activities').select('id')
      .eq('crop_id', cropId).eq('notes', note);
    check(error);
    return data?.length ?? 0;
  }).toBe(1);
  const { data, error } = await db().from('crop_activities').select('*')
    .eq('crop_id', cropId).eq('notes', note).single();
  check(error);
  expect(data!.activity_type).toBe(type);
  for (const [key, value] of Object.entries(extra)) expect(data![key]).toEqual(value);
  return data!;
}

async function doCare(page: Page, cropName: string, cropId: string, activity: keyof typeof activityCopy) {
  const note = `${prefix}_${cropName}_${activity.toLowerCase().replaceAll(' ', '_')}`;
  const form = await openCareForm(page, cropName);
  await chooseActivity(form, activityCopy[activity]);
  if (activity === 'Watered') await form.locator('input[name="quantity"]').fill('100');
  if (activity === 'Fertilized') {
    await form.locator('input[name="quantity"]').fill('10');
    await form.locator('input[name="unit"]').fill('g');
    await form.locator('input[name="material"]').fill('Organic compost');
  }
  if (activity === 'Inspected') await selectNamed(form, 'material', 'Looks normal');
  await form.locator('[name="notes"]').fill(note);
  const saveLabel = activity === 'Inspected' ? 'SAVE FIELD CHECK' : `SAVE ${activityCopy[activity].toUpperCase()}`;
  await form.getByRole('button', { name: saveLabel, exact: true }).click();
  await assertSavedActivity(cropId, note, activity, activity === 'Fertilized'
    ? { quantity: 10, unit: 'g', material: 'Organic compost' }
    : activity === 'Inspected' ? { material: 'Looks normal' }
      : activity === 'Watered' ? { quantity: 100, unit: 'ml' } : {});
}

async function observeStages(page: Page, name: string, cropId: string, profileKey: string) {
  const { data: profile, error } = await db().from('crop_profiles').select('stage_plan')
    .eq('profile_key', profileKey).single();
  check(error);
  const stages = (profile!.stage_plan as { stage: string }[]).map(({ stage }) => stage)
    .filter((stage) => stage !== 'Repeated Harvest');
  for (const stage of stages) {
    const note = `${prefix}_${name}_stage_${stage.replaceAll(' ', '_')}`;
    const form = await openCareForm(page, name);
    await chooseActivity(form, activityCopy['Stage Observed']);
    await selectNamed(form, 'observed_stage', stageCopy[stage] ?? stage);
    await form.locator('[name="notes"]').fill(note);
    await form.getByRole('button', { name: 'SAVE OBSERVE GROWTH', exact: true }).click();
    const canonicalStage = stage === 'First Harvest' ? 'Harvest Ready' : stage;
    await assertSavedActivity(cropId, note, 'Stage Observed', { observed_stage: canonicalStage });
    const state = await db().from('crops').select('growth_stage')
      .eq('id', cropId).single();
    check(state.error);
    expect(state.data!.growth_stage).toBe(canonicalStage);
  }
  // The Peanut profile ends at Maturity Check, while the web harvest control
  // requires an explicit farmer observation that the crop is ready to pick.
  if (profileKey === 'peanut') {
    const note = `${prefix}_${name}_stage_harvest_ready`;
    const form = await openCareForm(page, name);
    await chooseActivity(form, activityCopy['Stage Observed']);
    await selectNamed(form, 'observed_stage', 'Ready to harvest');
    await form.locator('[name="notes"]').fill(note);
    await form.getByRole('button', { name: 'SAVE OBSERVE GROWTH', exact: true }).click();
    await assertSavedActivity(cropId, note, 'Stage Observed', { observed_stage: 'Harvest Ready' });
    const state = await db().from('crops').select('growth_stage').eq('id', cropId).single();
    check(state.error);
    expect(state.data!.growth_stage).toBe('Harvest Ready');
    stages.push('Harvest Ready');
  }
  return stages;
}

async function harvest(page: Page, name: string, cropId: string, quantity: number, notes: string, expectedCount: number, isRepeat: boolean) {
  await openCrop(page, name);
  await page.getByRole('tab', { name: 'GROWTH JOURNEY', exact: true }).click();
  await page.getByRole('button', { name: 'Record harvest', exact: true }).click();
  const form = page.getByRole('dialog', { name: 'Record harvest' }).locator('form');
  await form.locator('input[name="quantity"]').fill(String(quantity));
  await form.locator('[name="notes"]').fill(notes);
  await form.getByRole('button', { name: 'REVIEW HARVEST', exact: true }).click();
  await confirm(page, 'Review harvest', isRepeat ? 'RECORD HARVEST' : 'Record final harvest');
  await expect.poll(async () => {
    const { data, error } = await db().from('crop_harvests').select('id').eq('remarks', notes);
    check(error);
    return data?.length ?? 0;
  }).toBe(1);
  await expect.poll(async () => {
    const { data, error } = await db().from('crop_harvests').select('id').eq('crop_id', cropId);
    check(error);
    return data?.length ?? 0;
  }).toBe(expectedCount);
}

async function sell(page: Page, product: string, quantity: number, suffix: string) {
  await page.context().clearCookies();
  await asRole(page, 'inventory');
  await fillSale(page, [{ name: product, quantity }], suffix, 200);
  const sale = await submitSale(page, suffix);
  expect(Number(sale.total_amount)).toBe(quantity * 50);
  return sale;
}

test.beforeEach(async ({ page }) => { await asRole(page, 'planting'); });

test('SR-CORE-002 Sitaw care, growth stages, sale between repeat harvests, and exact batches', async ({ page }, info) => {
  const planting = await crop('repeat_sitaw', 'sitaw');
  const stock = await produceInventory('Sitaw');
  const startingQuantity = await balance(stock.id);
  const oldestBatchBefore = await db().from('inventory_stock_batches').select('id')
    .eq('inventory_id', stock.id).order('created_at', { ascending: true }).limit(1).maybeSingle();
  check(oldestBatchBefore.error);
  for (const activity of ['Watered', 'Fertilized', 'Inspected'] as const) {
    await doCare(page, planting.name, planting.id, activity);
  }
  const stages = await observeStages(page, planting.name, planting.id, 'sitaw');
  expect(stages).toEqual(['Seeded', 'Germinating', 'Vegetative', 'Trellising', 'Flowering', 'Pod Formation', 'First Harvest']);

  await harvest(page, planting.name, planting.id, 6, `${prefix}_sitaw_pick_one`, 1, true);
  let state = await db().from('crops').select('crop_status,growth_stage,harvest_mode')
    .eq('id', planting.id).single();
  check(state.error);
  expect(state.data).toMatchObject({ crop_status: 'Active', growth_stage: 'Harvest Ready', harvest_mode: 'repeat' });
  expect(await balance(stock.id)).toBe(startingQuantity + 6);
  const firstCropBatch = await harvestBatches(planting.id, stock.id);
  expect(firstCropBatch).toHaveLength(1);

  const sale = await sell(page, 'Sitaw', 2, 'sitaw_sale_between_picks');
  const saleLine = await db().from('sales_order_items').select('inventory_id,quantity_sold,line_total')
    .eq('sales_order_id', sale.id).single();
  check(saleLine.error);
  expect(saleLine.data).toMatchObject({ inventory_id: stock.id, quantity_sold: 2, line_total: 100 });
  expect(await balance(stock.id)).toBe(startingQuantity + 4);
  const saleMovement = await db().from('inventory_transactions').select('id')
    .eq('inventory_id', stock.id).eq('source', 'sale').eq('source_id', sale.id).single();
  check(saleMovement.error);
  const saleAllocations = await db().from('inventory_transaction_batch_allocations')
    .select('batch_id,quantity').eq('transaction_id', saleMovement.data!.id);
  check(saleAllocations.error);
  expect(saleAllocations.data?.reduce((sum, row) => sum + Number(row.quantity), 0)).toBe(2);
  expect(saleAllocations.data![0].batch_id).toBe(oldestBatchBefore.data?.id ?? firstCropBatch[0].id);

  await page.context().clearCookies();
  await asRole(page, 'planting');
  await harvest(page, planting.name, planting.id, 3, `${prefix}_sitaw_pick_two`, 2, true);
  state = await db().from('crops').select('crop_status,growth_stage,harvest_mode')
    .eq('id', planting.id).single();
  check(state.error);
  expect(state.data).toMatchObject({ crop_status: 'Active', growth_stage: 'Harvest Ready', harvest_mode: 'repeat' });
  const harvestRows = await db().from('crop_harvests').select('quantity,inventory_id')
    .eq('crop_id', planting.id).order('created_at');
  check(harvestRows.error);
  expect(harvestRows.data?.map((row) => Number(row.quantity))).toEqual([6, 3]);
  expect(harvestRows.data?.every((row) => row.inventory_id === stock.id)).toBe(true);
  expect(await balance(stock.id)).toBe(startingQuantity + 7);
  const batches = await harvestBatches(planting.id, stock.id);
  expect(batches).toHaveLength(2);
  expect(batches.map((row) => Number(row.initial_quantity)).sort((a, b) => a - b)).toEqual([3, 6]);
  const allocatedByBatch = new Map(saleAllocations.data!.map((row) => [row.batch_id, Number(row.quantity)]));
  for (const batch of batches) {
    expect(Number(batch.remaining_quantity)).toBe(
      Number(batch.initial_quantity) - (allocatedByBatch.get(batch.id) ?? 0),
    );
  }
  await evidence(page, info, 'sitaw-two-harvests-and-sale');
  await info.attach('sitaw-result', { body: JSON.stringify({ cropId: planting.id, stages,
    harvests: [6, 3], sold: 2, remaining: startingQuantity + 7, batches, cropStatus: state.data!.crop_status }, null, 2), contentType: 'application/json' });
});

test('SR-CORE-003 Peanut care, growth stages, final harvest closes crop, and stock can be sold', async ({ page }, info) => {
  const planting = await crop('single_peanut', 'peanut');
  const stock = await produceInventory('Peanut');
  const startingQuantity = await balance(stock.id);
  const oldestBatchBefore = await db().from('inventory_stock_batches').select('id,remaining_quantity')
    .eq('inventory_id', stock.id).order('created_at', { ascending: true }).limit(1).maybeSingle();
  check(oldestBatchBefore.error);
  for (const activity of ['Watered', 'Fertilized', 'Inspected'] as const) {
    await doCare(page, planting.name, planting.id, activity);
  }
  const stages = await observeStages(page, planting.name, planting.id, 'peanut');
  expect(stages).toEqual(['Seeded', 'Germinating', 'Vegetative', 'Flowering', 'Pegging', 'Pod Development', 'Maturity Check', 'Harvest Ready']);

  await harvest(page, planting.name, planting.id, 8, `${prefix}_peanut_final_pick`, 1, false);
  const cropResult = await db().from('crops').select('crop_status,growth_stage,harvest_mode,harvested_at')
    .eq('id', planting.id).single();
  check(cropResult.error);
  expect(cropResult.data).toMatchObject({ crop_status: 'Completed', growth_stage: 'Completed', harvest_mode: 'single' });
  expect(cropResult.data!.harvested_at).toBeTruthy();
  const harvestRows = await db().from('crop_harvests').select('id,quantity,inventory_id')
    .eq('crop_id', planting.id);
  check(harvestRows.error);
  expect(harvestRows.data).toHaveLength(1);
  expect(harvestRows.data![0]).toMatchObject({ inventory_id: stock.id, quantity: 8 });
  expect(await balance(stock.id)).toBe(startingQuantity + 8);
  const batches = await harvestBatches(planting.id, stock.id);
  expect(batches).toHaveLength(1);
  expect(batches[0]).toMatchObject({ initial_quantity: 8, remaining_quantity: 8 });

  const config = localSupabaseConfig();
  const user = accounts().planting;
  const client = createClient(config.url, config.anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const login = await client.auth.signInWithPassword({ email: user.email, password: user.password });
  check(login.error);
  const retry = await client.rpc('record_crop_harvest', { p_entry: {
    crop_id: planting.id, quantity: 1, unit: 'kg', performed_at: new Date().toISOString(),
    notes: `${prefix}_peanut_illegal_second_pick`, submission_id: randomUUID(),
  } });
  expect(retry.error?.message).toMatch(/single harvest|ended|closed/i);
  const unchanged = await db().from('crop_harvests').select('id').eq('crop_id', planting.id);
  check(unchanged.error);
  expect(unchanged.data).toHaveLength(1);
  expect(await balance(stock.id)).toBe(startingQuantity + 8);

  const sale = await sell(page, 'Peanut', 3, 'peanut_final_harvest_sale');
  const line = await db().from('sales_order_items').select('inventory_id,quantity_sold,line_total')
    .eq('sales_order_id', sale.id).single();
  check(line.error);
  expect(line.data).toMatchObject({ inventory_id: stock.id, quantity_sold: 3, line_total: 150 });
  expect(await balance(stock.id)).toBe(startingQuantity + 5);
  const saleMovement = await db().from('inventory_transactions').select('id')
    .eq('inventory_id', stock.id).eq('source', 'sale').eq('source_id', sale.id).single();
  check(saleMovement.error);
  const allocation = await db().from('inventory_transaction_batch_allocations').select('batch_id,quantity')
    .eq('transaction_id', saleMovement.data!.id).single();
  check(allocation.error);
  expect(allocation.data!.batch_id).toBe(oldestBatchBefore.data?.id ?? batches[0].id);
  expect(Number(allocation.data!.quantity)).toBe(3);
  const soldBatch = await db().from('inventory_stock_batches').select('initial_quantity,remaining_quantity')
    .eq('id', batches[0].id).single();
  check(soldBatch.error);
  expect(soldBatch.data).toMatchObject({ initial_quantity: 8,
    remaining_quantity: oldestBatchBefore.data ? 8 : 5 });
  await evidence(page, info, 'peanut-final-harvest-and-sale');
  await info.attach('peanut-result', { body: JSON.stringify({ cropId: planting.id, stages,
    harvestKg: 8, soldKg: 3, remainingInventoryKg: 5, cropStatus: cropResult.data!.crop_status,
    secondHarvestRejected: true }, null, 2), contentType: 'application/json' });
});
