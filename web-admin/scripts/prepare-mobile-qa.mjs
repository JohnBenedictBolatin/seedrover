import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { localSupabaseHost } from '../e2e/local-supabase.mjs';

const url = process.env.E2E_LOCAL_SUPABASE_URL;
const anonKey = process.env.E2E_LOCAL_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.E2E_LOCAL_SUPABASE_SERVICE_ROLE_KEY;
const runId = process.env.QA_RUN_ID;
if (!url || !anonKey || !serviceRoleKey || !runId) {
  throw new Error('Provide local E2E credentials and a unique QA_RUN_ID.');
}
localSupabaseHost(url);
if (new URL(url).port !== '55421') {
  throw new Error('Mobile QA account setup accepts only the dedicated QA API port.');
}

const roles = {
  admin: 'System Administrator',
  plantingManager: 'Farm Planting Manager',
  inventoryManager: 'Farm Inventory Manager',
  plantingStaff: 'Planting Staff',
  inventoryStaff: 'Inventory Staff',
};
const client = createClient(url, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const accounts = {};
const createdIds = [];
const accountDir = path.resolve('e2e/.private', runId);
fs.mkdirSync(accountDir, { recursive: true });

try {
  for (const [key, roleName] of Object.entries(roles)) {
    const username = `mqa_${randomBytes(10).toString('hex')}`;
    const email = `${username}@example.invalid`;
    const password = `Sr!${randomBytes(18).toString('base64url')}9a`;
    const created = await client.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        username,
        full_name: `AUTOTEST ${key}`,
        first_name: 'AUTOTEST',
        last_name: key,
      },
    });
    if (created.error || !created.data.user) {
      throw new Error(`Could not create the ${key} mobile QA account: ${created.error?.message ?? 'no user returned'}`);
    }
    const userId = created.data.user.id;
    createdIds.push(userId);
    const role = await client.from('roles').select('id').eq('role_name', roleName).single();
    if (role.error || !role.data) throw new Error(`Missing local role ${roleName}.`);
    const profile = await client.from('profiles').upsert({
      id: userId,
      username,
      email,
      full_name: `AUTOTEST ${key}`,
      first_name: 'AUTOTEST',
      last_name: key,
      role_id: role.data.id,
      is_active: true,
    });
    if (profile.error) throw new Error(`Could not prepare the ${key} profile: ${profile.error.message}`);
    accounts[key] = { id: userId, username, email, password };
  }

  const outputPath = path.join(accountDir, 'mobile-accounts.json');
  fs.writeFileSync(outputPath, JSON.stringify(accounts, null, 2), { mode: 0o600 });
  console.log(`Created five mobile-only local QA accounts at ${path.relative(process.cwd(), outputPath)}.`);
} catch (error) {
  await Promise.all(createdIds.map((id) => client.auth.admin.deleteUser(id)));
  throw error;
}
