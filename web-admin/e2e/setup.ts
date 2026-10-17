import fs from 'node:fs';
import path from 'node:path';
import { chromium } from '@playwright/test';
import { roles, privateDir, runDir, createAccount, authFile, login, db, check, type Account, type Role } from './support';
import teardown from './teardown';

export default async function setup() {
  fs.mkdirSync(privateDir, { recursive: true });
  const client = db();
  for (const table of ['roles', 'inventory', 'inventory_stock_batches', 'sales_orders', 'crops', 'crop_activities', 'customer_discounts']) {
    const { error } = await client.from(table).select('id').limit(0); check(error);
  }
  const result = {} as Record<Role, Account>;
  const probes = {} as Record<Role, Account>;
  const browser = await chromium.launch();
  try {
    for (const role of Object.keys(roles) as Role[]) {
      result[role] = await createAccount(role, role.toLowerCase());
      fs.writeFileSync(path.join(privateDir, 'accounts.json'), JSON.stringify(result, null, 2));
      const page = await browser.newPage({ baseURL: 'http://127.0.0.1:3100', timezoneId: 'Asia/Manila' });
      try {
        await login(page, result[role], role.startsWith('planting') ? '/crops' : role === 'inventoryStaff' ? '/inventory' : '/dashboard');
      } catch (error) {
        await page.screenshot({ path: path.join(runDir, 'setup-failure.png'), fullPage: true });
        fs.writeFileSync(path.join(runDir, 'setup-failure.txt'), await page.locator('body').innerText());
        throw error;
      }
      await page.context().storageState({ path: authFile(role) });
      await page.close();
    }
    // UI-login probes use separate accounts so single-session invalidation cannot expire
    // the reusable business-test sessions saved above.
    for (const role of Object.keys(roles) as Role[]) {
      probes[role] = await createAccount(role, `login_${role.toLowerCase()}`);
    }
    fs.writeFileSync(path.join(privateDir, 'landing-accounts.json'), JSON.stringify(probes, null, 2));
    fs.writeFileSync(path.join(runDir, 'setup.json'), JSON.stringify({ status: 'passed', roles: Object.values(roles), browser: browser.version() }, null, 2));
  } catch (error) {
    fs.writeFileSync(path.join(runDir, 'setup.json'), JSON.stringify({ status: 'blocked', reason: String(error) }, null, 2));
    await teardown(); throw error;
  } finally { await browser.close(); }
}
