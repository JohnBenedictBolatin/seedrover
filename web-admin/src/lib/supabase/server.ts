import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { getSupabaseEnv } from "@/lib/env";

type SupabaseServerClientOptions = {
  rememberSession?: boolean;
};

function getSessionCookieOptions<T extends { maxAge?: unknown; expires?: unknown }>(
  options: T,
  rememberSession: boolean,
) {
  if (rememberSession) {
    return options;
  }

  const { maxAge: _maxAge, expires: _expires, ...sessionOptions } = options;
  return sessionOptions;
}

export async function createSupabaseServerClient(
  options: SupabaseServerClientOptions = {},
) {
  const env = getSupabaseEnv();

  if (!env) {
    return null;
  }

  const cookieStore = await cookies();
  const rememberSession =
    options.rememberSession ??
    cookieStore.get("seedrover-remember")?.value !== "0";

  return createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(
              name,
              value,
              getSessionCookieOptions(options, rememberSession),
            );
          });
        } catch {
          // Server Components cannot set cookies. Server Actions can.
        }
      },
    },
  });
}
