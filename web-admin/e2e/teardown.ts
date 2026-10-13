import fs from 'node:fs';
import path from 'node:path';
import { db, runDir, privateDir, prefix } from './support';

export default async function teardown() {
  const manifest = path.join(runDir, 'records.jsonl');
  if (!fs.existsSync(manifest)) return;
  const client = db();
  const records: { table: string; id: string; label: string }[] = fs.readFileSync(manifest, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  const actions: object[] = [];
  // Retain business/audit history. Disable every exact-ID test account; no broad name-based deletes.
  for (const record of records.filter(r => r.table === 'profiles')) {
    const { data, error } = await client.from('profiles').select('username').eq('id', record.id).single();
    if (error || data?.username !== record.label) { actions.push({ ...record, action: 'identity-check-failed' }); continue; }
    const update = await client.from('profiles').update({ is_active: false }).eq('id', record.id);
    actions.push({ ...record, action: update.error ? 'deactivation-failed' : 'deactivated', error: update.error?.message });
  }
  for (const record of records.filter(r => r.table !== 'profiles')) {
    if (!record.label.startsWith(prefix)) { actions.push({ ...record, action: 'retained-unverified-label' }); continue; }
    // Transactional rows are retained for traceability. Disposable notifications are safe to remove.
    if (record.table === 'notifications') {
      const removed = await client.from('notifications').delete().eq('id', record.id).like('title', `${prefix}%`);
      actions.push({ ...record, action: removed.error ? 'retained' : 'removed', error: removed.error?.message });
    } else actions.push({ ...record, action: 'retained-test-history' });
  }
  fs.writeFileSync(path.join(runDir, 'cleanup.json'), JSON.stringify({ policy: 'Accounts deactivated; test transactions and audit history retained; exact-ID notifications removed.', actions }, null, 2));
  // Session files are private and disposable; the evidence folder never includes passwords/cookies.
  for (const file of fs.readdirSync(privateDir)) {
    if (file.endsWith('.json')) fs.unlinkSync(path.join(privateDir, file));
  }
}
