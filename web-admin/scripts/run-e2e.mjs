import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import nextEnv from '@next/env';
import { applyLocalSupabaseConfig } from '../e2e/local-supabase.mjs';

nextEnv.loadEnvConfig(process.cwd());
if (fs.existsSync('.env.e2e.local')) process.loadEnvFile('.env.e2e.local');
const { hostname: host } = applyLocalSupabaseConfig();
if (!process.version.startsWith('v22.')) throw new Error('Run this suite with Node.js 22.x.');
const runId = new Date().toISOString().replace(/[-:.]/g, '').replace('Z', '') + '-' + process.pid;
const runDir = path.resolve('e2e/runs', runId);
fs.mkdirSync('e2e/.private', { recursive: true });
const lock = path.resolve('e2e/.private/run.lock');
const fd = fs.openSync(lock, 'wx');
fs.writeFileSync(fd, JSON.stringify({ pid: process.pid, runId }));
fs.mkdirSync(runDir, { recursive: true });
const git = (args) => spawnSync('git', args, { encoding: 'utf8' }).stdout?.trim() || 'unavailable';
fs.writeFileSync(path.join(runDir, 'environment.json'), JSON.stringify({
  runId, startedAt: new Date().toISOString(), node: process.version,
  platform: process.platform, supabaseHost: host, commit: git(['rev-parse', 'HEAD']),
  workingTree: git(['status', '--short']), timezone: 'Asia/Manila',
  browser: 'Chromium', playwright: JSON.parse(fs.readFileSync('node_modules/@playwright/test/package.json')).version,
}, null, 2));
const env = { ...process.env, E2E_RUN_ID: runId, E2E_RUN_DIR: runDir, NODE_OPTIONS: '--dns-result-order=ipv4first' };
let result;
try {
  result = spawnSync(process.execPath, ['node_modules/@playwright/test/cli.js', 'test', ...process.argv.slice(2)], { env, stdio: 'inherit' });
} finally {
  fs.closeSync(fd);
  fs.unlinkSync(lock);
  fs.writeFileSync('e2e/runs/latest.txt', runId);
  console.log(`Evidence: ${runDir}`);
}
process.exitCode = result?.status ?? 1;
