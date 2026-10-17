import { test, expect } from '@playwright/test';
import { asRole, inventory, balance, openItem, selectNamed, confirm, prefix, db, check, track, evidence } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page, 'inventory'); });
test('SR-INV-001 @smoke Inventory displays a persisted test item', async ({ page }, info) => {
  const item = await inventory('view'); await page.goto('/inventory');
  await page.getByPlaceholder('Search inventory').fill(item.name);
  await expect(page.getByText(item.name, { exact: true })).toBeVisible(); await evidence(page, info);
});
test('SR-INV-002 Create inventory item through UI and verify persistence', async ({ page }, info) => {
  const name = `${prefix}_ui_created`;
  await page.goto('/inventory'); await page.getByRole('button', { name: /Add (new )?item|Add stock/i }).click();
  const form = page.getByRole('dialog');
  for (const [key, value] of Object.entries({ item_name: name, quantity: '20', minimum_quantity: '1', unit_cost: '20', selling_price: '50', storage_location: 'AUTOTEST ONLY', notes: prefix })) {
    await form.locator(`[name="${key}"]`).fill(value);
  }
  await selectNamed(form, 'category', 'Leafy Vegetables');
  await form.locator('input[type="file"]').setInputFiles({ name: 'test.png', mimeType: 'image/png', buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64') });
  await form.getByRole('button', { name: 'Save Item', exact: true }).click();
  await confirm(page, 'Create inventory item?', 'Create item');
  await expect.poll(async () => { const r = await db().from('inventory').select('id').eq('item_name', name); check(r.error); return r.data?.length; }).toBe(1);
  const { data } = await db().from('inventory').select('id').eq('item_name', name).single(); track('inventory', data!.id, name);
  await page.reload(); await page.getByPlaceholder('Search inventory').fill(name);
  await expect(page.getByText(name, { exact: true })).toBeVisible(); expect(await balance(data!.id)).toBe(20); await evidence(page, info);
});
test('SR-INV-003 Edit inventory location and verify after reload', async ({ page }, info) => {
  const item = await inventory('edit'); const form = await openItem(page, item.name, 'Edit');
  await form.locator('[name="storage_location"]').fill('AUTOTEST UPDATED');
  await form.getByRole('button', { name: 'Save Item', exact: true }).click();
  await expect.poll(async () => (await db().from('inventory').select('storage_location').eq('id', item.id).single()).data?.storage_location).toBe('AUTOTEST UPDATED');
  const reopened = await openItem(page, item.name, 'Edit'); await expect(reopened.locator('[name="storage_location"]')).toHaveValue('AUTOTEST UPDATED'); await evidence(page, info);
});
for (const [id, action, quantity, expected, reason] of [
  ['004', 'Receive stock', 5, 25, 'Field Crate'], ['005', 'Issue stock', 3, 17, 'Kitchen Preparation'],
] as const) {
  test(`SR-INV-${id} ${action} updates balance and movement history`, async ({ page }, info) => {
    const item = await inventory(`movement_${id}`); const form = await openItem(page, item.name, action);
    await form.locator('[name="quantity"]').fill(String(quantity)); await selectNamed(form, 'reason', reason);
    await form.locator('[name="remarks"]').fill(`${prefix}_${id}`);
    await form.getByRole('button', { name: action, exact: true }).click(); await confirm(page, `${action}?`, action);
    await expect.poll(() => balance(item.id)).toBe(expected);
    const rows = await db().from('inventory_transactions').select('*').eq('inventory_id', item.id).eq('transaction_type', action === 'Receive stock' ? 'IN' : 'OUT'); check(rows.error);
    expect(rows.data).toHaveLength(1); expect(Number(rows.data![0].quantity)).toBe(quantity);
    await page.reload(); await page.getByPlaceholder('Search inventory').fill(item.name); await evidence(page, info);
  });
}
test('SR-INV-006 Insufficient stock issue is rejected without changing balance', async ({ page }, info) => {
  const item = await inventory('insufficient', 2); const form = await openItem(page, item.name, 'Issue stock');
  await form.locator('[name="quantity"]').fill('3'); await selectNamed(form, 'reason', 'Kitchen Preparation');
  await form.getByRole('button', { name: 'Issue stock', exact: true }).click(); await confirm(page, 'Issue stock?', 'Issue stock');
  await expect(page.getByRole('alert').filter({ hasText: /Not enough stock is available for this issue/i })).toBeVisible({ timeout: 5_000 });
  expect(await balance(item.id)).toBe(2); await evidence(page, info);
});
test('SR-INV-007 Negative selling price is rejected', async ({ page }, info) => {
  const item = await inventory('negative'); const form = await openItem(page, item.name, 'Edit');
  const field = form.locator('[name="selling_price"]'); await field.fill('-1');
  // NumericInput may remove the minus sign; otherwise HTML validity must reject it.
  const value = await field.inputValue();
  if (Number(value) < 0) expect(await field.evaluate((el: HTMLInputElement) => el.validity.rangeUnderflow)).toBe(true);
  else expect(Number(value)).toBeGreaterThanOrEqual(0);
  expect((await db().from('inventory').select('selling_price').eq('id', item.id).single()).data?.selling_price).toBe(50);
  await evidence(page, info);
});
