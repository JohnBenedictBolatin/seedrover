"use server";

import { revalidatePath } from "next/cache";
import { getCurrentAdminProfile } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function requireAdminClient() {
  const profile = await getCurrentAdminProfile();

  if (!profile || profile.roleName !== "System Administrator") {
    return null;
  }

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return null;
  }

  return { supabase, profile };
}

export async function markNotificationReadAction(formData: FormData) {
  const context = await requireAdminClient();

  if (!context) {
    return;
  }

  const id = String(formData.get("notification_id") ?? "");
  const isRead = String(formData.get("is_read") ?? "true") === "true";

  if (!id) {
    return;
  }

  await context.supabase
    .from("notifications")
    .update({ is_read: isRead })
    .eq("id", id);

  await context.supabase.from("activity_logs").insert({
    user_id: context.profile.id,
    activity: isRead ? "Notification Read" : "Notification Unread",
    description: "Notification status updated from the web admin.",
    module: "Notifications",
  });

  revalidatePath("/notifications");
}

export async function deleteNotificationAction(formData: FormData) {
  const context = await requireAdminClient();

  if (!context) {
    return;
  }

  const id = String(formData.get("notification_id") ?? "");

  if (!id) {
    return;
  }

  await context.supabase.from("notifications").delete().eq("id", id);

  await context.supabase.from("activity_logs").insert({
    user_id: context.profile.id,
    activity: "Notification Deleted",
    description: "Notification deleted from the web admin.",
    module: "Notifications",
  });

  revalidatePath("/notifications");
}
