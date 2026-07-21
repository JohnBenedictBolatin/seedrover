import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

const protectedRoutes = [
  "/activity-log",
  "/crops",
  "/customers",
  "/dashboard",
  "/inventory",
  "/notifications",
  "/reports",
  "/rover-monitor",
  "/sales",
  "/users",
];

function isProtectedRoute(pathname: string) {
  return protectedRoutes.some(
    (route) => pathname === route || pathname.startsWith(`${route}/`),
  );
}

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

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  let response = NextResponse.next({ request });
  const rememberSession = request.cookies.get("seedrover-remember")?.value !== "0";
  const supabaseUrl =
    process.env.NEXT_PUBLIC_SUPABASE_URL ?? process.env.SUPABASE_URL;
  const supabaseAnonKey =
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
    process.env.SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return response;
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });

        response = NextResponse.next({ request });

        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(
            name,
            value,
            getSessionCookieOptions(options, rememberSession),
          );
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (isProtectedRoute(pathname) && !user) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    loginUrl.searchParams.set("redirectedFrom", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if ((pathname === "/" || pathname === "/login") && user) {
    const dashboardUrl = request.nextUrl.clone();
    dashboardUrl.pathname = "/dashboard";
    dashboardUrl.search = "";
    return NextResponse.redirect(dashboardUrl);
  }

  return response;
}

export const config = {
  matcher: [
    "/",
    "/login",
    "/activity-log/:path*",
    "/crops/:path*",
    "/customers/:path*",
    "/dashboard/:path*",
    "/inventory/:path*",
    "/notifications/:path*",
    "/reports/:path*",
    "/rover-monitor/:path*",
    "/sales/:path*",
    "/users/:path*",
  ],
};
