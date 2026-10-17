import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { asRole, inventory, fillSale, submitSale, evidence, selectNamed, db, check, confirm, prefix, runId, track, accounts } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page, 'inventory'); });
test('SR-CUST-001 Completed sale appears in customer purchase history', async ({ page }, info) => {
  const item = await inventory('customer'); await fillSale(page, [{ name: item.name, quantity: 1 }], 'customer', 50);
  await submitSale(page, 'customer'); await page.goto('/customers', { waitUntil: 'domcontentloaded' });
  await page.getByPlaceholder('Search customer, contact, payment, item...').fill(`${runId}_customer`);
  await expect(page.getByText(`AUTOTEST ${runId}_customer`, { exact: true }).first()).toBeVisible();
  await expect(page.getByText(/50\.00/).first()).toBeVisible(); await evidence(page, info);
});
test('SR-CUST-002 Create and apply a valid discount to a sale', async ({ page }, info) => {
  await page.goto('/customers', { waitUntil: 'domcontentloaded' }); await page.getByRole('button', { name: 'Create Discount', exact: true }).first().click();
  const dialog = page.getByRole('dialog', { name: 'Create discount' });
  await selectNamed(dialog, 'discount_type', 'Percent'); await dialog.locator('[name="discount_value"]').fill('10');
  await dialog.locator('[name="notes"]').fill(`${prefix}_discount`);
  await dialog.getByRole('button', { name: 'Create Discount', exact: true }).click();
  await page.getByRole('dialog', { name: 'Discount coupon preview' }).getByRole('button', { name: 'Release discount', exact: true }).click();
  await confirm(page, 'Release this discount?', 'Release discount');
  await expect.poll(async () => (await db().from('customer_discounts').select('id').eq('notes', `${prefix}_discount`)).data?.length).toBe(1);
  const discount = await db().from('customer_discounts').select('*').eq('notes', `${prefix}_discount`).single(); check(discount.error);
  track('customer_discounts', discount.data!.id, `${prefix}_discount`);
  await evidence(page, info, 'discount-created');
  const item = await inventory('discount'); await fillSale(page, [{ name: item.name, quantity: 2 }], 'discount', 90);
  const wrapper = page.locator('input[name="discount_code"]').locator('..');
  await wrapper.locator('button').first().click();
  await wrapper.getByRole('button', { name: new RegExp(`${discount.data!.discount_code} - 10% off`), exact: true }).last().click();
  const sale = await submitSale(page, 'discount'); expect(Number(sale.total_amount)).toBe(90);
  const saved = await db().from('sales_orders').select('discount_amount, discount_code').eq('id', sale.id).single(); check(saved.error);
  expect(Number(saved.data!.discount_amount)).toBe(10); expect(saved.data!.discount_code).toBe(discount.data!.discount_code);
  await page.goto(`/sales/${sale.id}`); await evidence(page, info, 'discounted-receipt');
});
test('SR-CUST-003 Expired discount cannot be selected for a new sale', async ({ page }, info) => {
  const id = randomUUID(); const code = `AT_EXPIRED_${Date.now()}`;
  track('customer_discounts', id, `${prefix}_expired`);
  const result = await db().from('customer_discounts').insert({ id, discount_code: code, customer_key: prefix,
    customer_name: 'Anyone with the code', discount_type: 'Percent', discount_value: 10,
    valid_until: '2020-01-01', released_by: accounts().admin.id, notes: `${prefix}_expired` }); check(result.error);
  const item = await inventory('expired'); await fillSale(page, [{ name: item.name, quantity: 1 }], 'expired', 50);
  const wrapper = page.locator('input[name="discount_code"]').locator('..'); await wrapper.locator('button').first().click();
  await expect(wrapper.getByRole('button', { name: new RegExp(code) })).toHaveCount(0);
  await evidence(page, info);
});
