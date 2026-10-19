import { test, expect } from '@playwright/test';
import { asRole, inventory, fillSale, submitSale, balance, evidence, selectNamed, db, check, confirm, runId } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page, 'inventory'); });
test('SR-SALE-001 @smoke Cash sale saves receipt total change and exact stock deduction', async ({ page }, info) => {
  const item = await inventory('cash'); await fillSale(page, [{ name: item.name, quantity: 3 }], 'cash');
  const discountPicker = page.locator('input[name="discount_code"]').locator('..');
  await discountPicker.locator('button').first().click();
  await expect(discountPicker.getByRole('button', { name: /No discount(?:s available)?/, exact: true })).toBeVisible();
  await discountPicker.locator('button').first().click();
  const sale = await submitSale(page, 'cash'); expect(Number(sale.total_amount)).toBe(150); expect(Number(sale.change_amount)).toBe(50);
  expect(await balance(item.id)).toBe(17);
  await page.goto(`/sales/${sale.id}`); await expect(page.getByRole('cell', { name: item.name, exact: true })).toBeVisible();
  await expect(page.getByText(/150\.00/).first()).toBeVisible(); await evidence(page, info, 'receipt');
  const moves = await db().from('inventory_transactions').select('id, quantity').eq('inventory_id', item.id).eq('transaction_type', 'OUT'); check(moves.error);
  expect(moves.data).toHaveLength(1); expect(Number(moves.data![0].quantity)).toBe(3);
  await page.goto('/inventory'); await page.getByPlaceholder('Search inventory').fill(item.name); await evidence(page, info, 'remaining-stock');
});
test('SR-SALE-002 Multi-item sale deducts each stock once', async ({ page }, info) => {
  const first = await inventory('multi_a'); const second = await inventory('multi_b');
  await fillSale(page, [{ name: first.name, quantity: 2 }, { name: second.name, quantity: 1 }], 'multi', 150);
  const sale = await submitSale(page, 'multi'); expect(Number(sale.total_amount)).toBe(150);
  expect(await balance(first.id)).toBe(18); expect(await balance(second.id)).toBe(19);
  const lines = await db().from('sales_order_items').select('id').eq('sales_order_id', sale.id); check(lines.error); expect(lines.data).toHaveLength(2);
  await page.goto(`/sales/${sale.id}`); await evidence(page, info);
});
test('SR-SALE-003 Overselling is rejected and stock remains unchanged', async ({ page }, info) => {
  const item = await inventory('oversell', 2); await fillSale(page, [{ name: item.name, quantity: 3 }], 'oversell');
  await page.getByRole('button', { name: 'Record sale', exact: true }).last().click();
  await expect(page.getByRole('alert').filter({ hasText: /stock|available|quantity/i })).toBeVisible();
  expect(await balance(item.id)).toBe(2); await evidence(page, info);
});
test('SR-SALE-004 Non-cash payment requires a transaction reference', async ({ page }, info) => {
  const item = await inventory('reference'); await fillSale(page, [{ name: item.name, quantity: 3 }], 'reference', 150);
  await selectNamed(page, 'payment_method_display', 'GCash');
  const field = page.locator('[name="transaction_reference"]'); await expect(field).toBeVisible();
  await page.getByRole('button', { name: 'Record sale', exact: true }).last().click();
  expect(await field.evaluate((el: HTMLInputElement) => el.validity.valueMissing)).toBe(true);
  expect(await balance(item.id)).toBe(20); await evidence(page, info);
});
test('SR-SALE-007 A payment transaction ID cannot be reused', async ({ page }, info) => {
  const firstItem = await inventory('unique_reference_first');
  const secondItem = await inventory('unique_reference_second');
  const reference = `AUTOTEST-TXN-${runId}`.slice(0, 32);

  await fillSale(page, [{ name: firstItem.name, quantity: 1 }], 'unique_reference_first', 50);
  await selectNamed(page, 'payment_method_display', 'GCash');
  await page.locator('[name="transaction_reference"]').fill(reference);
  const firstSale = await submitSale(page, 'unique_reference_first');
  expect(firstSale.status).toBe('Completed');
  expect(await balance(firstItem.id)).toBe(19);

  await page.goto('/sales');
  await fillSale(page, [{ name: secondItem.name, quantity: 1 }], 'unique_reference_second', 50);
  await selectNamed(page, 'payment_method_display', 'GCash');
  await page.locator('[name="transaction_reference"]').fill(reference.toLowerCase());
  await page.getByRole('button', { name: 'Record sale', exact: true }).last().click();
  await confirm(page, 'Record this sale?', 'Record sale');
  await expect(page.getByRole('alert').filter({ hasText: /transaction ID is already recorded/i })).toBeVisible();

  expect(await balance(secondItem.id)).toBe(20);
  const matching = await db().from('sales_orders').select('id').ilike('transaction_reference', reference);
  check(matching.error);
  expect(matching.data).toHaveLength(1);
  await evidence(page, info, 'duplicate-transaction-id-rejected');
});
test('SR-SALE-005 Authorized cancellation restores inventory exactly once', async ({ page }, info) => {
  const item = await inventory('void'); await fillSale(page, [{ name: item.name, quantity: 3 }], 'void');
  const sale = await submitSale(page, 'void');
  await page.goto('/sales'); await page.getByPlaceholder('Search sale reference, customer, payment...').fill(sale.receipt_number);
  await page.getByRole('button', { name: 'Void sale', exact: true }).first().click(); await confirm(page, 'Void this sale?', 'Void sale');
  await expect.poll(() => balance(item.id)).toBe(20);
  expect((await db().from('sales_orders').select('status').eq('id', sale.id).single()).data?.status).toBe('Voided');
  await page.reload(); await page.getByPlaceholder('Search sale reference, customer, payment...').fill(sale.receipt_number);
  await expect(page.getByRole('button', { name: 'Void sale', exact: true })).toHaveCount(0); await evidence(page, info);
});
test('SR-SALE-006 Inventory staff cannot cancel a completed sale', async ({ page }, info) => {
  const item = await inventory('staff_void'); await fillSale(page, [{ name: item.name, quantity: 1 }], 'staff_void', 50);
  const sale = await submitSale(page, 'staff_void');
  await page.context().clearCookies(); await asRole(page, 'inventoryStaff');
  await page.goto('/sales'); await page.getByPlaceholder('Search sale reference, customer, payment...').fill(sale.receipt_number);
  await expect(page.getByRole('button', { name: 'Void sale', exact: true })).toHaveCount(0);
  expect(await balance(item.id)).toBe(19); await evidence(page, info);
});
