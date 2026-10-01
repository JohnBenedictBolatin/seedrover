import { createBrowserClient } from "@supabase/ssr";

export function createSupabaseBrowserClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  // Keep browser auth aligned with the SSR client: PKCE recovery callbacks and
  // sessions are stored in the shared auth cookies that the server reads.
  return url && anonKey ? createBrowserClient(url, anonKey) : null;
}
