import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return NextResponse.json({ connected: false }, { status: 503 });
  }

  try {
    const { error } = await supabase.from("profiles").select("id").limit(1);
    if (error) {
      return NextResponse.json({ connected: false }, { status: 503 });
    }

    return NextResponse.json(
      { connected: true },
      { headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  } catch {
    return NextResponse.json({ connected: false }, { status: 503 });
  }
}
