const loopbackHosts = new Set(['localhost', '127.0.0.1', '[::1]']);

export function localSupabaseHost(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('The E2E Supabase URL is invalid. Use the local Supabase API URL.');
  }
  const hostname = parsed.hostname.toLowerCase();
  if (!loopbackHosts.has(hostname) || parsed.protocol !== 'http:') {
    throw new Error('E2E database access is restricted to local Supabase on this computer.');
  }
  return hostname;
}

export function localSupabaseConfig(env = process.env) {
  const url = env.E2E_LOCAL_SUPABASE_URL;
  const anonKey = env.E2E_LOCAL_SUPABASE_ANON_KEY;
  const serviceRoleKey = env.E2E_LOCAL_SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !anonKey || !serviceRoleKey) {
    throw new Error('Set E2E_LOCAL_SUPABASE_URL, E2E_LOCAL_SUPABASE_ANON_KEY, and E2E_LOCAL_SUPABASE_SERVICE_ROLE_KEY from the local Supabase instance.');
  }
  return { url, anonKey, serviceRoleKey, hostname: localSupabaseHost(url) };
}

export function applyLocalSupabaseConfig(env = process.env) {
  const config = localSupabaseConfig(env);
  env.NEXT_PUBLIC_SUPABASE_URL = config.url;
  env.NEXT_PUBLIC_SUPABASE_ANON_KEY = config.anonKey;
  env.SUPABASE_SERVICE_ROLE_KEY = config.serviceRoleKey;
  return config;
}
