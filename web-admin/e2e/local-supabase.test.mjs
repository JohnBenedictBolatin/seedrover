import test from 'node:test';
import assert from 'node:assert/strict';
import { localSupabaseConfig, localSupabaseHost } from './local-supabase.mjs';

test('accepts a configured local Supabase instance', () => {
  const config = localSupabaseConfig({
    E2E_LOCAL_SUPABASE_URL: 'http://127.0.0.1:54321',
    E2E_LOCAL_SUPABASE_ANON_KEY: 'local-anon-key',
    E2E_LOCAL_SUPABASE_SERVICE_ROLE_KEY: 'local-service-key',
  });
  assert.equal(config.hostname, '127.0.0.1');
});

test('rejects a remote project even if credentials are present', () => {
  assert.throws(
    () => localSupabaseHost('https://example.supabase.co'),
    /restricted to local Supabase/,
  );
});

test('refuses to infer local credentials from the app environment', () => {
  assert.throws(
    () => localSupabaseConfig({ NEXT_PUBLIC_SUPABASE_URL: 'http://localhost:54321' }),
    /E2E_LOCAL_SUPABASE_URL/,
  );
});
