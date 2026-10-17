import { test, expect } from '@playwright/test';
import { randomBytes } from 'node:crypto';
import { accounts, asRole, createAccount, db, check, evidence, login, prefix, selectNamed, confirm, track } from '../support';

test.beforeEach(async ({ page }) => { await asRole(page); });
for (const duplicate of [false, true]) {
  test(`SR-USER-00${duplicate ? 2 : 1} ${duplicate ? 'Duplicate username is rejected' : 'Administrator creates a user through UI'}`, async ({ page }, info) => {
    const username = duplicate ? accounts().inventory.username : `at_ui_${randomBytes(7).toString('hex')}`;
    await page.goto('/users'); await page.getByRole('button', { name: /create user|add user|create account/i }).first().click();
    const form = page.locator('form').filter({ has: page.locator('input[name="initial_password"]') });
    for (const [name, value] of Object.entries({ first_name: 'AUTOTEST', last_name: 'Created', username, email: `at_${randomBytes(7).toString('hex')}@example.invalid`, initial_password: `Sr!${randomBytes(16).toString('hex')}`, access_note: prefix })) await form.locator(`[name="${name}"]`).fill(value);
    await selectNamed(form, 'role_id', 'Inventory Staff');
    await form.getByRole('button', { name: 'Create Account', exact: true }).click(); await confirm(page, 'Review new account', 'Create account');
    if (duplicate) {
      await expect(page.getByText(/username.*already exists/i)).toBeVisible();
    } else {
      await expect.poll(async () => (await db().from('profiles').select('id').eq('username', username)).data?.length).toBe(1);
      const saved = await db().from('profiles').select('id').eq('username', username).single(); check(saved.error); track('profiles', saved.data!.id, username);
      await page.reload(); await page.getByPlaceholder('Search name, email, username, role...').fill(username);
      await expect(page.getByText(username, { exact: false }).first()).toBeVisible();
    }
    await evidence(page, info);
  });
}
test('SR-USER-003 Update account details and role persists', async ({ page }, info) => {
  const account = await createAccount('inventoryStaff', 'edituser');
  await page.goto('/users'); await page.getByPlaceholder('Search name, email, username, role...').fill(account.username);
  await page.getByRole('button', { name: /^Manage / }).click();
  const form = page.locator('form').filter({ has: page.locator('input[name="user_id"]') });
  await form.locator('[name="first_name"]').fill('AUTOTESTUPDATED'); await selectNamed(form, 'role_id', 'Planting Staff');
  await form.getByRole('button', { name: 'Save Profile', exact: true }).click(); await confirm(page, 'Update account access?', 'Update access');
  await expect.poll(async () => (await db().from('profiles').select('first_name').eq('id', account.id).single()).data?.first_name).toBe('AUTOTESTUPDATED');
  const saved = await db().from('profiles').select('roles(role_name)').eq('id', account.id).single(); check(saved.error);
  expect(JSON.stringify(saved.data)).toContain('Planting Staff'); await page.reload(); await evidence(page, info);
});
test('SR-USER-004 Deactivate account through UI and deny its login', async ({ page, browser }, info) => {
  const account = await createAccount('inventoryStaff', 'disable');
  await page.goto('/users'); await page.getByPlaceholder('Search name, email, username, role...').fill(account.username);
  await page.getByRole('button', { name: /^Manage / }).click();
  const form = page.locator('form').filter({ has: page.locator('input[name="user_id"]') });
  await selectNamed(form, 'is_active', 'Inactive');
  await form.getByRole('button', { name: 'Save Profile', exact: true }).click(); await confirm(page, 'Update account access?', 'Update access');
  await expect.poll(async () => (await db().from('profiles').select('is_active').eq('id', account.id).single()).data?.is_active).toBe(false);
  await evidence(page, info, 'deactivated');
  const context = await browser.newContext({ baseURL: 'http://127.0.0.1:3100' });
  try { const other = await context.newPage(); await login(other, account); await other.goto('/inventory'); await expect(other).toHaveURL(/\/login/); }
  finally { await context.close(); }
});
