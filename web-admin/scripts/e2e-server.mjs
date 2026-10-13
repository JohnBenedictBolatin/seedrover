import { spawn } from 'node:child_process';
const run = (args) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, ['node_modules/next/dist/bin/next', ...args], { stdio: 'inherit', env: process.env });
  child.on('error', reject);
  child.on('exit', code => code === 0 ? resolve() : reject(new Error(`Next.js exited ${code}`)));
});
if (process.env.E2E_SKIP_BUILD !== '1') await run(['build']);
await run(['start', '--hostname', '127.0.0.1', '--port', '3100']);
