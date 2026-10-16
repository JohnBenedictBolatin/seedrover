import fs from 'node:fs';
import path from 'node:path';
import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
import { applyLocalSupabaseConfig } from '../e2e/local-supabase.mjs';

nextEnv.loadEnvConfig(process.cwd());
if (fs.existsSync('.env.e2e.local')) process.loadEnvFile('.env.e2e.local');
const { url, serviceRoleKey, hostname: host } = applyLocalSupabaseConfig();
const runId = process.argv[2];
if (!runId || !/^[0-9T]+-[0-9]+$/.test(runId)) throw new Error('Supply an exact run ID from e2e/runs.');
const runDir = path.resolve('e2e/runs', runId);
const metadata = JSON.parse(fs.readFileSync(path.join(runDir, 'environment.json'), 'utf8'));
if (host !== metadata.supabaseHost) throw new Error('Local database target mismatch.');
const client = createClient(url, serviceRoleKey, { auth: { persistSession: false } });
const records = fs.readFileSync(path.join(runDir, 'records.jsonl'), 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
const actions = [];
for (const record of records.filter(r => r.table === 'profiles')) {
  const result = await client.from('profiles').select('username').eq('id', record.id).single();
  if (result.error || result.data.username !== record.label || !record.label.startsWith('at_')) throw new Error('Recorded account identity cannot be verified.');
  const update = await client.from('profiles').update({ is_active: false }).eq('id', record.id);
  if (update.error) throw new Error(update.error.message);
  actions.push({ id: record.id, action: 'deactivated' });
}
const privateDir = path.resolve('e2e/.private', runId);
if (fs.existsSync(privateDir)) for (const file of fs.readdirSync(privateDir)) if (file.endsWith('.json')) fs.unlinkSync(path.join(privateDir, file));
fs.writeFileSync(path.join(runDir, 'recovery-cleanup.json'), JSON.stringify({ recoveredAt: new Date().toISOString(), actions, retained: 'Business and audit history retained; no broad deletion.' }, null, 2));
console.log(`Deactivated ${actions.length} tracked test accounts for ${runId}.`);
