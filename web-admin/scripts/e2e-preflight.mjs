import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';
import { applyLocalSupabaseConfig } from '../e2e/local-supabase.mjs';

nextEnv.loadEnvConfig(process.cwd());
if (fs.existsSync('.env.e2e.local')) process.loadEnvFile('.env.e2e.local');
const { url, serviceRoleKey: key, hostname: project } = applyLocalSupabaseConfig();
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
console.log('Configured local Supabase:', project);
const roles = await db.from('roles').select('id, role_name');
if (roles.error) throw new Error(`Preflight: ${roles.error.message}`);
console.log('Roles:', roles.data.map(r => r.role_name).join(', '));
for (const table of ['inventory', 'inventory_stock_batches', 'sales_orders', 'sales_order_items', 'crops', 'crop_activities', 'notifications', 'customer_discounts']) {
  const result = await db.from(table).select('*').limit(0);
  console.log(table, result.error ? result.error.message : 'accessible');
}
const response = await fetch(`${url}/rest/v1/`, { headers: { apikey: key, Authorization: `Bearer ${key}` } });
if (!response.ok) throw new Error(`Schema inspection failed: ${response.status}`);
const schema = await response.json();
fs.mkdirSync('e2e/.private', { recursive: true });
fs.writeFileSync('e2e/.private/schema.json', JSON.stringify(schema, null, 2));
