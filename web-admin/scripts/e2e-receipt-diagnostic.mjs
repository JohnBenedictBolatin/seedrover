import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';
import { applyLocalSupabaseConfig } from '../e2e/local-supabase.mjs';
nextEnv.loadEnvConfig(process.cwd());
if (fs.existsSync('.env.e2e.local')) process.loadEnvFile('.env.e2e.local');
const { url, serviceRoleKey } = applyLocalSupabaseConfig();
const db = createClient(url, serviceRoleKey, { auth: { persistSession: false } });
for (const query of ['id,profiles(full_name)', 'id,profiles!sales_orders_recorded_by_fkey(full_name)']) {
  const { error } = await db.from('sales_orders').select(query).limit(0);
  console.log(JSON.stringify({ query, error }));
}
