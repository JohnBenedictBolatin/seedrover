"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function signOutAction() {
  const supabase = await createSupabaseServerClient();

  if (supabase) {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      await supabase.from("activity_logs").insert({
        user_id: user.id,
        activity: "Web Logout",
        description: "User signed out of the web admin.",
        module: "Authentication",
      });
    }

    await supabase.auth.signOut();
  }

  const cookieStore = await cookies();
  cookieStore.delete("seedrover-remember");

  redirect("/login");
}
