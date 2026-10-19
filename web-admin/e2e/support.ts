import fs from 'node:fs';
import path from 'node:path';
import { randomBytes, randomUUID } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { expect, type Page, type Locator, type TestInfo } from '@playwright/test';
import { localSupabaseConfig } from './local-supabase.mjs';

export const roles = {
  admin: 'System Administrator', planting: 'Farm Planting Manager', inventory: 'Farm Inventory Manager',
  plantingStaff: 'Planting Staff', inventoryStaff: 'Inventory Staff',
} as const;
export type Role = keyof typeof roles;
export const runId = process.env.E2E_RUN_ID || 'unconfigured';
export const runDir = process.env.E2E_RUN_DIR || path.resolve('e2e/runs/unconfigured');
export const privateDir = path.resolve('e2e/.private', runId);
export const prefix = `AUTOTEST_${runId}`;
export function db() {
  const config = localSupabaseConfig();
  return createClient(config.url, config.serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
}
export function check(error: { message: string } | null) { if (error) throw new Error(error.message); }
export type Account = { id: string; username: string; email: string; password: string; role: Role };
export function accounts(): Record<Role, Account> { return JSON.parse(fs.readFileSync(path.join(privateDir, 'accounts.json'), 'utf8')); }
export function landingAccounts(): Record<Role, Account> { return JSON.parse(fs.readFileSync(path.join(privateDir, 'landing-accounts.json'), 'utf8')); }
export function authFile(role: Role) { return path.join(privateDir, `${role}.json`); }
export function track(table: string, id: string, label: string) {
  fs.appendFileSync(path.join(runDir, 'records.jsonl'), JSON.stringify({ table, id, label, at: new Date().toISOString() }) + '\n');
}
export async function createAccount(role: Role, suffix: string): Promise<Account> {
  const client = db();
  const username = `at_${randomBytes(6).toString('hex')}_${suffix}`.slice(0, 32);
  const email = `${username}@example.invalid`;
  const password = `Sr!${randomBytes(18).toString('base64url')}9a`;
  const result = await client.auth.admin.createUser({ email, password, email_confirm: true,
    user_metadata: { username, full_name: `${prefix} ${suffix}`, first_name: 'AUTOTEST', last_name: suffix } });
  check(result.error);
  const id = result.data.user!.id;
  track('profiles', id, username);
  const roleResult = await client.from('roles').select('id').eq('role_name', roles[role]).single(); check(roleResult.error);
  const profile = await client.from('profiles').upsert({ id, username, email, full_name: `${prefix} ${suffix}`,
    first_name: 'AUTOTEST', last_name: suffix, role_id: roleResult.data!.id, is_active: true }); check(profile.error);
  return { id, username, email, password, role };
}
export async function login(page: Page, account: Account, destination?: string) {
  await page.goto('/login');
  await page.locator('input[name="username"]').fill(account.username);
  await page.locator('input[name="password"]').fill(account.password);
  await page.getByRole('button', { name: 'Log in', exact: true }).click();
  if (destination) await expect(page).toHaveURL(new RegExp(`${destination}$`));
}
export async function asRole(page: Page, role: Role = 'admin') {
  const state = JSON.parse(fs.readFileSync(authFile(role), 'utf8'));
  await page.context().addCookies(state.cookies);
}
export async function evidence(page: Page, info: TestInfo, name = 'verified-result') {
  await info.attach(name, { body: await page.screenshot({ fullPage: true }), contentType: 'image/png' });
}
export async function inventory(label: string, quantity = 20) {
  const id = randomUUID(); const name = `${prefix}_${label}`;
  track('inventory', id, name);
  const { error } = await db().from('inventory').insert({ id, item_name: name, quantity, unit: 'kg', minimum_quantity: 1,
    category: 'Leafy Vegetables', storage_location: 'AUTOTEST ONLY', unit_cost: 20, selling_price: 50,
    updated_by: accounts().admin.id, notes: prefix }); check(error);
  return { id, name };
}
export async function produceInventory(name: 'Sitaw' | 'Calamansi' | 'Peanut') {
  const client = db();
  const existing = await client.from('inventory').select('id, item_name, quantity')
    .ilike('item_name', name).maybeSingle();
  check(existing.error);
  let data = existing.data;
  if (!data) {
    const inserted = await client.from('inventory').insert({
      item_name: name, quantity: 0, unit: 'kg', minimum_quantity: 0,
      category: 'Leafy Vegetables', storage_location: 'AUTOTEST ONLY',
      unit_cost: 20, selling_price: 50, updated_by: accounts().admin.id, notes: prefix,
    }).select('id, item_name, quantity').single();
    if (inserted.error?.code === '23505') {
      const raced = await client.from('inventory').select('id, item_name, quantity')
        .ilike('item_name', name).single();
      check(raced.error);
      data = raced.data;
    } else {
      check(inserted.error);
      data = inserted.data;
      track('inventory', data!.id, `${prefix}_${name}`);
    }
  }
  return { id: data!.id as string, name: data!.item_name as string, startingQuantity: Number(data!.quantity) };
}
export async function harvestBatches(cropId: string, inventoryId: string) {
  const harvests = await db().from('crop_harvests').select('id').eq('crop_id', cropId);
  check(harvests.error);
  if (!harvests.data?.length) return [];
  const receipts = await db().from('inventory_transactions').select('id')
    .eq('inventory_id', inventoryId).eq('source', 'harvest')
    .in('source_id', harvests.data.map((row) => row.id));
  check(receipts.error);
  if (!receipts.data?.length) return [];
  const batches = await db().from('inventory_stock_batches').select('id, inventory_id, source_transaction_id, initial_quantity, remaining_quantity')
    .in('source_transaction_id', receipts.data.map((row) => row.id));
  check(batches.error);
  return batches.data ?? [];
}
export async function crop(label: string, profileKey = 'sitaw') {
  const config = localSupabaseConfig();
  const account = accounts().planting;
  const session = createClient(config.url, config.anonKey,
    { auth: { persistSession: false, autoRefreshToken: false } });
  const signedIn = await session.auth.signInWithPassword({ email: account.email, password: account.password }); check(signedIn.error);
  const startedAt = new Date(Date.now() - 60_000).toISOString();
  const rpc = await session.rpc('sync_rover_planting_run', { p_run: {
    session_id: randomUUID(), rover_id: 'AUTOTEST_SYNTHETIC_NO_HARDWARE', crop_profile_key: profileKey,
    field_label: `${prefix}_${label}`, target_drop_cycles: 1, completed_drop_cycles: 1,
    measured_distance_cm: 0, planting_status: 'Completed', started_at: startedAt, completed_at: new Date().toISOString(),
    confirmation_outcome: 'row_planted', sync_payload: { synthetic_fixture: true, hardware_verified: false,
      note: 'AUTOTEST database fixture generated through authorized planting receipt RPC; no rover or physical planting run.' },
  } });
  check(rpc.error);
  const created = rpc.data as { planting_log_id: string; crop_id: string | null };
  if (!created.crop_id) throw new Error('Authorized planting receipt did not produce a crop fixture');
  const name = `${prefix}_${label}`;
  track('planting_logs', created.planting_log_id, name);
  track('crops', created.crop_id, name);
  return { id: created.crop_id, name, plantingLogId: created.planting_log_id };
}
export async function balance(id: string) {
  const { data, error } = await db().from('inventory').select('quantity').eq('id', id).single(); check(error);
  return Number(data!.quantity);
}
export async function selectNamed(root: Page | Locator, name: string, option: string) {
  const wrapper = root.locator(`input[name="${name}"]`).locator('..');
  await wrapper.locator('button').first().click();
  await wrapper.getByRole('button', { name: option, exact: true }).last().click();
}
export async function confirm(page: Page, title: string | RegExp, button: string | RegExp) {
  await page.getByRole('dialog', { name: title }).getByRole('button', { name: button, exact: true }).click();
}
export async function openItem(page: Page, name: string, action: 'Edit' | 'Receive stock' | 'Issue stock') {
  await page.goto('/inventory');
  await page.getByPlaceholder('Search inventory').fill(name);
  const card = page.locator('article').filter({ hasText: name });
  await card.getByRole('button', { name: action, exact: true }).click();
  return page.getByRole('dialog').first();
}
export async function fillSale(page: Page, items: { name: string; quantity: number }[], suffix: string, paid = 200) {
  await page.goto('/sales', { waitUntil: 'domcontentloaded' });
  await page.getByRole('button', { name: /record sale/i }).first().click();
  for (let i = 0; i < items.length; i++) {
    if (i) await page.getByRole('button', { name: /Add item/i }).click();
    await page.getByPlaceholder('Search crop or stock code...').nth(i).fill(items[i].name);
    await page.getByRole('button').filter({ has: page.getByText(items[i].name, { exact: true }) }).click();
    await page.locator('input[name="quantity"]').nth(i).fill(String(items[i].quantity));
  }
  await page.locator('input[name="customer_first_name"]').fill('AUTOTEST');
  await page.locator('input[name="customer_last_name"]').fill(`${runId}_${suffix}`);
  await page.locator('input[name="customer_contact"]').fill('09000000000');
  await page.locator('textarea[name="remarks"]').fill(`${prefix}_${suffix}`);
  await page.locator('input[name="amount_paid"]').fill(String(paid));
}
export async function submitSale(page: Page, suffix: string) {
  await page.getByRole('button', { name: 'Record sale', exact: true }).last().click();
  await confirm(page, 'Record this sale?', 'Record sale');
  let order: Record<string, unknown> | null = null;
  await expect.poll(async () => {
    const { data, error } = await db().from('sales_orders').select('*').eq('remarks', `${prefix}_${suffix}`); check(error);
    order = data?.[0] || null; return data?.length;
  }).toBe(1);
  const result = order as unknown as { id: string; total_amount: number; change_amount: number; status: string; receipt_number: string };
  track('sales_orders', result.id, `${prefix}_${suffix}`);
  return result;
}
