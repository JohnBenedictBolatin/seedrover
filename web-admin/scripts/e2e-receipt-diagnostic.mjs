import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
nextEnv.loadEnvConfig(process.cwd());
const db = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
for (const query of ['id,profiles(full_name)', 'id,profiles!sales_orders_recorded_by_fkey(full_name)']) {
  const { error } = await db.from('sales_orders').select(query).limit(0);
  console.log(JSON.stringify({ query, error }));
}
