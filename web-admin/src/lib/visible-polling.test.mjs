import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startVisiblePolling } from './visible-polling.mjs';

function setup(t) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 10_000 });
  const document = Object.assign(new EventTarget(), { visibilityState: 'visible' });
  const window = Object.assign(new EventTarget(), { setTimeout, clearTimeout });
  const navigator = { onLine: true };
  for (const [name, value] of Object.entries({ document, window, navigator })) {
    const old = Object.getOwnPropertyDescriptor(globalThis, name);
    Object.defineProperty(globalThis, name, { value, configurable: true });
    t.after(() => old ? Object.defineProperty(globalThis, name, old) : delete globalThis[name]);
  }
  return {
    async tick(ms) { t.mock.timers.tick(ms); await Promise.resolve(); },
    visibility(value) { document.visibilityState = value; document.dispatchEvent(new Event('visibilitychange')); },
    online(value) { navigator.onLine = value; window.dispatchEvent(new Event(value ? 'online' : 'offline')); },
  };
}

test('rover waits 30s, pauses while hidden, and refreshes once on return', async (t) => {
  const env = setup(t);
  let calls = 0;
  const poll = startVisiblePolling({ task: () => { calls++; }, intervalMs: 30_000, runOnStart: false });
  t.after(poll.stop);
  await env.tick(29_999);
  assert.equal(calls, 0);
  await env.tick(1);
  assert.equal(calls, 1);
  env.visibility('hidden');
  await env.tick(300_000);
  assert.equal(calls, 1);
  env.visibility('visible');
  env.online(true);
  await env.tick(0);
  assert.equal(calls, 2);
  await env.tick(30_000);
  assert.equal(calls, 3);
});

test('connectivity checks every 120s and pauses offline', async (t) => {
  const env = setup(t);
  let calls = 0;
  const poll = startVisiblePolling({ task: () => { calls++; }, intervalMs: 120_000 });
  t.after(poll.stop);
  await env.tick(0);
  await env.tick(119_999);
  assert.equal(calls, 1);
  await env.tick(1);
  assert.equal(calls, 2);
  env.online(false);
  await env.tick(600_000);
  assert.equal(calls, 2);
  env.online(true);
  await env.tick(0);
  assert.equal(calls, 3);
});

test('manual refresh and wake events do not overlap an outstanding request', async (t) => {
  const env = setup(t);
  let calls = 0;
  let finish;
  const request = new Promise((resolve) => { finish = resolve; });
  const poll = startVisiblePolling({ task: () => { calls++; return request; }, intervalMs: 30_000 });
  await env.tick(120_000);
  await poll.run();
  env.visibility('hidden');
  env.visibility('visible');
  assert.equal(calls, 1);
  poll.stop();
  finish();
  await env.tick(0);
  await env.tick(120_000);
  assert.equal(calls, 1);
});

test('manual refresh restarts the interval; disposal removes wake listeners', async (t) => {
  const env = setup(t);
  let calls = 0;
  const poll = startVisiblePolling({ task: () => { calls++; }, intervalMs: 30_000, runOnStart: false });
  await env.tick(20_000);
  await poll.run();
  await env.tick(10_000);
  assert.equal(calls, 1);
  await env.tick(20_000);
  assert.equal(calls, 2);
  poll.stop();
  env.visibility('hidden');
  env.visibility('visible');
  env.online(true);
  await env.tick(120_000);
  assert.equal(calls, 2);
});

test('mounting hidden does no work until visible', async (t) => {
  const env = setup(t);
  env.visibility('hidden');
  let calls = 0;
  const poll = startVisiblePolling({ task: () => { calls++; }, intervalMs: 120_000 });
  t.after(poll.stop);
  await env.tick(600_000);
  assert.equal(calls, 0);
  env.visibility('visible');
  await env.tick(0);
  assert.equal(calls, 1);
});
