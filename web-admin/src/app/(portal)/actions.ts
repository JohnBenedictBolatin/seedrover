"use server";

import { cookies } from "next/headers";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { writeActivityLog } from "@/lib/activity-log";

export async function signOutAction() {
  const supabase = await createSupabaseServerClient();

  if (supabase) {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      await writeActivityLog(supabase, {
        userId: user.id,
        activity: "Web Logout",
        description: "User signed out of the web admin.",
        module: "Authentication",
      });
    }

    const { error } = await supabase.auth.signOut();
    if (error) return { ok: false, message: "Unable to sign out. Please try again." };
  }

  const cookieStore = await cookies();
  cookieStore.delete("seedrover-remember");

  return { ok: true as const };
}
