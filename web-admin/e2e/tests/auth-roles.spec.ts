import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';
import { accounts, landingAccounts, asRole, authFile, createAccount, db, check, evidence, login, roles, type Role, inventory, crop, balance } from '../support';

test('SR-AUTH-001 @smoke Valid administrator login reaches dashboard', async ({ page }, info) => {
  await login(page, landingAccounts().admin, '/dashboard');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await evidence(page, info);
});
test('SR-AUTH-002 Invalid credentials are rejected', async ({ page }, info) => {
  await login(page, { ...accounts().admin, password: 'Incorrect-only-for-test-123!' });
  await expect(page.getByRole('status')).toContainText('Invalid username or password.');
  await expect(page).toHaveURL(/\/login$/); await evidence(page, info);
});
test('SR-AUTH-003 Required username and password prevent empty submission', async ({ page }, info) => {
  await page.goto('/login'); await page.getByRole('button', { name: 'Log in', exact: true }).click();
  expect(await page.locator('input[name="username"]').evaluate((el: HTMLInputElement) => el.validity.valueMissing)).toBe(true);
  await page.locator('input[name="username"]').fill('autotest');
  expect(await page.locator('input[name="password"]').evaluate((el: HTMLInputElement) => el.validity.valueMissing)).toBe(true);
  await expect(page).toHaveURL(/\/login$/); await evidence(page, info);
});
test('SR-AUTH-004 Signed-out dashboard access redirects to login', async ({ page }, info) => {
  await page.goto('/dashboard'); await expect(page).toHaveURL(/\/login/); await evidence(page, info);
});
test('SR-AUTH-005 @smoke Logout prevents subsequent protected access', async ({ page }, info) => {
  await login(page, landingAccounts().admin, '/dashboard');
  await page.getByRole('button', { name: /sign out|log out|logout/i }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: 'Sign out', exact: true }).click();
  await expect(page).toHaveURL(/\/login/); await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/login/); await evidence(page, info);
});
test('SR-AUTH-006 Inactive account cannot access portal', async ({ page }, info) => {
  const account = await createAccount('inventory', 'inactive');
  check((await db().from('profiles').update({ is_active: false }).eq('id', account.id)).error);
  await login(page, account); await expect(page).toHaveURL(/\/login/);
  await page.goto('/inventory'); await expect(page).toHaveURL(/\/login/); await evidence(page, info);
});

for (const [index, role] of (Object.keys(roles) as Role[]).entries()) {
  test(`SR-ROLE-00${index + 1} ${roles[role]} receives the correct landing page`, async ({ page }, info) => {
    await login(page, landingAccounts()[role], role.startsWith('planting') ? '/crops' : role === 'inventoryStaff' ? '/inventory' : '/dashboard');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible(); await evidence(page, info);
  });
}
for (const [index, role] of (['planting', 'inventory', 'plantingStaff', 'inventoryStaff'] as Role[]).entries()) {
  test(`SR-ROLE-01${index + 1} ${roles[role]} cannot open user administration`, async ({ page }, info) => {
    await asRole(page, role); await page.goto('/users');
    await expect(page).not.toHaveURL(/\/users$/); await expect(page.getByRole('heading', { name: 'User Management' })).toHaveCount(0);
    await evidence(page, info);
  });
}
function roleClient(role: Role) {
  const state = JSON.parse(fs.readFileSync(authFile(role), 'utf8'));
  const cookies = state.cookies.filter((c: { name: string }) => c.name.includes('-auth-token')).sort((a: {name:string}, b: {name:string}) => a.name.localeCompare(b.name));
  const value = cookies.map((c: { value: string }) => c.value).join('');
  const session = JSON.parse(value.startsWith('base64-') ? Buffer.from(value.slice(7), 'base64url').toString() : value);
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: `Bearer ${session.access_token}` } }, auth: { persistSession: false, autoRefreshToken: false },
  });
}
test('SR-ROLE-020 Planting role cannot change inventory through database API', async ({ page }, info) => {
  const item = await inventory('role_inventory');
  const result = await roleClient('planting').from('inventory').update({ quantity: 999 }).eq('id', item.id).select('id');
  expect(Boolean(result.error) || result.data?.length === 0).toBe(true);
  expect(await balance(item.id)).toBe(20);
  await asRole(page, 'planting'); await page.goto('/inventory'); await expect(page).not.toHaveURL(/\/inventory$/); await evidence(page, info);
});
test('SR-ROLE-021 Inventory role cannot change crops through database API', async ({ page }, info) => {
  const item = await crop('role_crop');
  const result = await roleClient('inventory').from('crops').update({ maintenance_notes: 'unauthorized edit' }).eq('id', item.id).select('id');
  expect(Boolean(result.error) || result.data?.length === 0).toBe(true);
  const saved = await db().from('crops').select('maintenance_notes').eq('id', item.id).single(); check(saved.error);
  expect(saved.data!.maintenance_notes).not.toBe('unauthorized edit');
  await asRole(page, 'inventory'); await page.goto('/crops'); await expect(page).not.toHaveURL(/\/crops$/); await evidence(page, info);
});
test('SR-ROLE-022 Signed-out and planting-role sales exports are rejected', async ({ page, request }, info) => {
  expect((await request.get('/api/exports/sales.csv')).status()).toBe(401);
  await asRole(page, 'planting'); expect((await page.request.get('/api/exports/sales.csv')).status()).toBe(401);
  const response = await page.goto('/api/exports/sales.csv'); expect(response?.status()).toBe(401); await evidence(page, info);
});

export { roleClient };
