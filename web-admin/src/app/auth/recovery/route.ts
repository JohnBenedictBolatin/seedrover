import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import { getSupabaseEnv } from "@/lib/env";

const recoveryCookieName = "seedrover-password-recovery";

function invalidRecoveryResponse(request: NextRequest) {
  const loginUrl = new URL("/login", request.url);
  loginUrl.searchParams.set("recovery", "invalid");
  const response = NextResponse.redirect(loginUrl);
  response.cookies.delete(recoveryCookieName);
  return response;
}

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const env = getSupabaseEnv();

  if (!code || !env) {
    return invalidRecoveryResponse(request);
  }

  const response = NextResponse.redirect(new URL("/reset-password", request.url));
  const supabase = createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    console.error("Password recovery code exchange failed.", { message: error.message });
    return invalidRecoveryResponse(request);
  }

  response.cookies.set(recoveryCookieName, "1", {
    httpOnly: true,
    maxAge: 10 * 60,
    path: "/",
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  return response;
}
