import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { getWeatherApiForecast } from "@/lib/crops";
import { getSupabaseEnv } from "@/lib/env";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const accessToken = request.headers
    .get("authorization")
    ?.match(/^Bearer\s+(.+)$/i)?.[1];

  if (!accessToken) {
    return NextResponse.json({ error: "Authentication required." }, { status: 401 });
  }

  const env = getSupabaseEnv();
  if (!env) {
    return NextResponse.json({ error: "Weather service is not configured." }, { status: 503 });
  }

  const supabase = createClient(env.url, env.anonKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
  const { data, error } = await supabase.auth.getUser(accessToken);

  if (error || !data.user) {
    return NextResponse.json({ error: "Authentication required." }, { status: 401 });
  }

  const forecast = await getWeatherApiForecast();
  if (!forecast) {
    return NextResponse.json({ error: "WeatherAPI forecast is unavailable." }, { status: 503 });
  }

  return NextResponse.json(forecast, {
    headers: { "Cache-Control": "private, no-store, max-age=0" },
  });
}
