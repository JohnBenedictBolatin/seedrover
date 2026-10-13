import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';

nextEnv.loadEnvConfig(process.cwd());
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error('Supabase configuration is missing.');
const project = new URL(url).hostname;
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
console.log('Configured project:', project);
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
