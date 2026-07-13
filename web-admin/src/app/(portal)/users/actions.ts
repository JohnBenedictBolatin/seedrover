"use server";

import { revalidatePath } from "next/cache";
import { getCurrentAdminProfile } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function updateUserAction(formData: FormData) {
  const profile = await getCurrentAdminProfile();

  if (!profile || profile.roleName !== "System Administrator") {
    return;
  }

  const userId = String(formData.get("user_id") ?? "");
  const fullName = String(formData.get("full_name") ?? "").trim();
  const roleId = String(formData.get("role_id") ?? "");
  const isActive = String(formData.get("is_active") ?? "false") === "true";

  if (!userId || !fullName || !roleId) {
    return;
  }

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return;
  }

  await supabase
    .from("profiles")
    .update({
      full_name: fullName,
      role_id: roleId,
      is_active: isActive,
    })
    .eq("id", userId);

  await supabase.from("activity_logs").insert({
    user_id: profile.id,
    activity: "User Updated",
    description: `${fullName} profile updated from the web admin.`,
    module: "Users",
  });

  revalidatePath("/users");
}
