import nextEnv from '@next/env';
import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';
import path from 'node:path';

nextEnv.loadEnvConfig(process.cwd());
if (fs.existsSync('.env.e2e.local')) process.loadEnvFile('.env.e2e.local');
const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const expectedHost = process.env.E2E_EXPECTED_SUPABASE_HOST;
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key || !expectedHost) throw new Error('Require NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and E2E_EXPECTED_SUPABASE_HOST.');
const host = new URL(url).hostname;
if (host !== expectedHost) throw new Error(`Refusing cleanup: configured project ${host} differs from expected host ${expectedHost}.`);

const runsRoot = path.resolve('e2e/runs');
const manifests = [];
for (const entry of fs.readdirSync(runsRoot, { withFileTypes: true })) {
  if (!entry.isDirectory() || entry.name === 'list-only') continue;
  const runDir = path.join(runsRoot, entry.name);
  const envPath = path.join(runDir, 'environment.json');
  const recordsPath = path.join(runDir, 'records.jsonl');
  if (!fs.existsSync(envPath) || !fs.existsSync(recordsPath)) continue;
  const env = JSON.parse(fs.readFileSync(envPath, 'utf8'));
  const records = fs.readFileSync(recordsPath, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
  const inventory = records.filter(row => row.table === 'inventory');
  if (!inventory.length) continue;
  if (env.supabaseHost !== host) throw new Error(`Refusing cleanup: run ${entry.name} points to ${env.supabaseHost || 'unknown project'}, not ${host}.`);
  for (const row of inventory) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(row.id || '')) throw new Error(`Invalid manifest inventory ID in ${entry.name}.`);
    if (typeof row.label !== 'string' || !row.label.startsWith(`AUTOTEST_${entry.name}_`)) throw new Error(`Inventory label does not match exact run ${entry.name}; aborting.`);
    manifests.push({ runId: entry.name, id: row.id, label: row.label });
  }
}
const unique = new Map();
for (const row of manifests) {
  const prior = unique.get(row.id);
  if (prior && prior.label !== row.label) throw new Error(`Conflicting manifest labels for ${row.id}.`);
  unique.set(row.id, row);
}
const candidates = [...unique.values()];
console.log(`Verified Supabase project: ${host}`);
console.log(`Manifest inventory candidates: ${candidates.length} unique IDs from ${new Set(candidates.map(r => r.runId)).size} runs.`);
if (!candidates.length) throw new Error('No exact inventory candidates were found.');

const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
const ids = candidates.map(row => row.id);
const chunks = arr => Array.from({ length: Math.ceil(arr.length / 100) }, (_, i) => arr.slice(i * 100, (i + 1) * 100));
async function fetchRows(table, columns, field, values) {
  const rows = [];
  for (const batch of chunks(values)) {
    const { data, error } = await db.from(table).select(columns).in(field, batch);
    if (error) throw new Error(`${table} read failed; no cleanup performed: ${error.message}`);
    rows.push(...(data || []));
  }
  return rows;
}
const live = await fetchRows('inventory', 'id,item_name', 'id', ids);
const liveById = new Map(live.map(row => [row.id, row]));
for (const row of live) {
  const expected = unique.get(row.id);
  if (!expected || row.item_name !== expected.label) throw new Error(`Live ID/label mismatch for ${row.id}; no cleanup performed.`);
}
const missing = candidates.filter(row => !liveById.has(row.id));
console.log(`Live exact ID+label matches: ${live.length}; already absent: ${missing.length}.`);

// Any linked business/history row protects its inventory item in this conservative cleanup pass.
// This keeps the operation narrow and avoids guessing whether a reference is safe to delete.
const references = [
  ['inventory_transactions', 'id,inventory_id', 'inventory_id'],
  ['sales_transactions', 'id,inventory_id', 'inventory_id'],
  ['sales_order_items', 'id,inventory_id', 'inventory_id'],
  ['crop_harvests', 'id,inventory_id', 'inventory_id'],
  ['farm_expenses', 'id,related_inventory_id', 'related_inventory_id'],
  ['crops', 'id,harvest_inventory_id', 'harvest_inventory_id'],
  ['inventory_stock_batches', 'id,inventory_id', 'inventory_id'],
];
const refsById = new Map(ids.map(id => [id, []]));
for (const [table, columns, field] of references) {
  const rows = await fetchRows(table, columns, field, ids);
  for (const row of rows) {
    const inventoryId = row[field];
    if (refsById.has(inventoryId)) refsById.get(inventoryId).push({ table, id: row.id });
  }
}
const deletable = candidates.filter(row => liveById.has(row.id) && refsById.get(row.id).length === 0);
const protectedRows = candidates.filter(row => liveById.has(row.id) && refsById.get(row.id).length > 0);
console.log(`Exact candidates with no detected dependencies: ${deletable.length}.`);
console.log(`Candidates protected by linked rows: ${protectedRows.length}.`);
if (protectedRows.length) {
  console.log('Protected item references (sample):');
  for (const row of protectedRows.slice(0, 20)) console.log(JSON.stringify({ id: row.id, label: row.label, references: refsById.get(row.id) }));
  if (protectedRows.length > 20) console.log(`... ${protectedRows.length - 20} more protected candidates.`);
}
if (!apply) {
  console.log('PREVIEW ONLY: no database rows changed. Re-run with --apply to remove only unreferenced exact manifest IDs.');
  process.exit(0);
}
if (!deletable.length) {
  console.log('No safe exact inventory rows to delete; database unchanged.');
  process.exit(0);
}
for (const batch of chunks(deletable.map(row => row.id))) {
  const { data, error } = await db.from('inventory').delete().in('id', batch).select('id');
  if (error) throw new Error(`Exact-ID inventory delete failed: ${error.message}`);
  const deleted = new Set((data || []).map(row => row.id));
  if (deleted.size !== batch.length) throw new Error(`Delete count mismatch: requested ${batch.length}, confirmed ${deleted.size}.`);
}
const remaining = await fetchRows('inventory', 'id,item_name', 'id', ids);
const remainingIds = new Set(remaining.map(row => row.id));
if (deletable.some(row => remainingIds.has(row.id))) throw new Error('Post-delete verification found an exact candidate still present.');
console.log(`APPLIED: removed ${deletable.length} unreferenced exact manifest-listed inventory rows.`);
console.log(`Exceptions retained: ${protectedRows.length} linked rows, ${missing.length} candidates already absent. Independent audit/history and all accounts were untouched.`);
