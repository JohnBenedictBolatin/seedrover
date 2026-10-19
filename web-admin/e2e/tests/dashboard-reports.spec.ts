import { test, expect, type Page } from '@playwright/test';
import { asRole, inventory, fillSale, submitSale, evidence, prefix, runDir } from '../support';
import fs from 'node:fs';
import path from 'node:path';

test.beforeEach(async ({ page }) => { await asRole(page); });
async function metric(page: Page) {
  const element = page.getByRole('region', { name: 'Operations summary' }).locator('article').filter({ hasText: 'Sales total' }).locator('strong');
  let previous = ''; let current = '';
  await expect.poll(async () => { current = await element.innerText(); const stable = current === previous; previous = current; return stable; }, { intervals: [1200, 1200, 1200] }).toBe(true);
  return Number(current.replace(/[^0-9.-]/g, ''));
}
test('SR-DASH-001 @smoke Dashboard loads and all period selectors work', async ({ page }, info) => {
  await page.goto('/dashboard'); await expect(page.getByRole('heading', { name: 'Operations Dashboard' })).toBeVisible();
  for (const period of ['Day', 'Week', 'Month', 'Year']) {
    await page.getByRole('button', { name: period, exact: true }).click();
    await expect(page).toHaveURL(new RegExp(`range=${period.toLowerCase()}`));
    await expect(page.getByRole('button', { name: period, exact: true })).toHaveAttribute('aria-current', 'page');
    await expect(page.getByText('Some dashboard data could not load.')).toHaveCount(0);
  }
  await evidence(page, info);
});
test('SR-DASH-002 Dashboard sales total increases by the controlled sale amount', async ({ page }, info) => {
  await page.goto('/dashboard?range=day'); const before = await metric(page);
  const item = await inventory('dashboard'); await fillSale(page, [{ name: item.name, quantity: 2 }], 'dashboard', 100);
  await submitSale(page, 'dashboard'); await page.goto('/dashboard?range=day');
  const after = await metric(page); expect(after - before).toBe(100);
  await info.attach('baseline-and-delta', { body: JSON.stringify({ before, after, expectedDelta: 100 }), contentType: 'application/json' });
  await evidence(page, info);
});
test('SR-DASH-003 Empty customer search displays an explicit empty state', async ({ page }, info) => {
  await page.goto('/customers'); await page.getByPlaceholder('Search customer, contact, payment, item...').fill(`${prefix}_NO_MATCH`);
  await expect(page.getByText('No customers found.', { exact: true })).toBeVisible(); await evidence(page, info);
});
test('SR-REPORT-001 Inventory CSV contains headers and exact fixture values', async ({ page }, info) => {
  const item = await inventory('csv', 23); await page.goto('/inventory');
  const response = await page.request.get('/api/exports/inventory.csv'); expect(response.status()).toBe(200);
  expect(response.headers()['content-disposition']).toContain('attachment');
  const csv = await response.text(); expect(csv).toContain('Item');
  const row = csv.split('\n').find(line => line.includes(item.name)); expect(row).toBeTruthy(); expect(row).toMatch(/(?:,|\")23(?:,|\")/);
  await info.attach('inventory.csv', { body: csv, contentType: 'text/csv' });
  await evidence(page, info);
});
test('SR-REPORT-002 Sales CSV respects date filters and includes the new receipt', async ({ page }, info) => {
  const item = await inventory('sales_csv'); await fillSale(page, [{ name: item.name, quantity: 3 }], 'sales_csv', 150);
  const sale = await submitSale(page, 'sales_csv');
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date());
  const response = await page.request.get(`/api/exports/sales.csv?start=${today}&end=${today}`);
  expect(response.status()).toBe(200); const csv = await response.text(); expect(csv).toContain('Receipt / Reference');
  expect(csv).toContain(sale.receipt_number); expect(csv).toContain(item.name);
  const old = await page.request.get('/api/exports/sales.csv?start=2000-01-01&end=2000-01-02'); expect(old.status()).toBe(200);
  expect(await old.text()).not.toContain(sale.receipt_number);
  await info.attach('sales.csv', { body: csv, contentType: 'text/csv' });
  await page.goto('/sales'); await evidence(page, info);
});
test('SR-REPORT-003 Receipt and report print views render their fixture data', async ({ page }, info) => {
  const item = await inventory('print'); await fillSale(page, [{ name: item.name, quantity: 1 }], 'print', 50);
  const sale = await submitSale(page, 'print');
  await page.goto('/sales');
  await page.getByPlaceholder('Search sale reference, customer, payment...').fill(sale.receipt_number);
  await page.getByRole('button', { name: 'View sale details', exact: true }).click();
  const detail = page.getByRole('dialog', { name: 'Sales record details' });
  await expect(detail.getByRole('heading', { name: 'Sale Details', exact: true })).toBeVisible();
  // The receipt reference is intentionally shown in both the summary and
  // printable receipt within this dialog; assert the summary field directly.
  await expect(detail.locator('strong').filter({ hasText: sale.receipt_number })).toBeVisible();
  await expect(detail.locator('strong').filter({ hasText: item.name })).toBeVisible();
  await page.emulateMedia({ media: 'print' });
  const pdf = await page.pdf({ format: 'A4', printBackground: true });
  await info.attach('sale-details-print.pdf', { body: pdf, contentType: 'application/pdf' });
  await page.emulateMedia({ media: 'screen' }); await page.goto('/reports/sales/print');
  await expect(page.getByRole('heading', { name: 'Sales Report' })).toBeVisible();
  await expect(page.getByText(item.name, { exact: true })).toBeVisible(); await evidence(page, info);
});
test.afterAll(() => { fs.writeFileSync(path.join(runDir, 'report-testing-note.txt'), 'CSV routes verified through the authenticated browser request context; receipt PDF rendered with Chromium. Native OS print dialog is outside scope.'); });
