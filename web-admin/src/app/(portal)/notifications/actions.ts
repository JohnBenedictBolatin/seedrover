"use server";

import { revalidatePath } from "next/cache";
import { getCurrentAdminProfile, requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

async function requireNotificationClient() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return null;
  }

  try {
    const profile = await getCurrentAdminProfile();
    if (!profile) return null;
    return { supabase, profile };
  } catch {
    return null;
  }
}

async function requireSystemAdminClient() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return null;
  }

  try {
    const profile = await requireAdminRole(["System Administrator"]);
    return { supabase, profile };
  } catch {
    return null;
  }
}

export async function markNotificationReadAction(formData: FormData) {
  const context = await requireNotificationClient();

  if (!context) {
    return { ok: false, message: "You do not have permission to update notifications." };
  }

  const id = String(formData.get("notification_id") ?? "");
  const isRead = String(formData.get("is_read") ?? "true") === "true";

  if (!id) {
    return { ok: false, message: "Notification ID is missing." };
  }

  const { error } = await context.supabase
    .from("notifications")
    .update({ is_read: isRead })
    .eq("id", id);
  if (error) return { ok: false, message: error.message };

  const { error: logError } = await context.supabase.from("activity_logs").insert({
    user_id: context.profile.id,
    activity: isRead ? "Notification Read" : "Notification Unread",
    description: "Notification status updated from the web admin.",
    module: "Notifications",
  });
  revalidatePath("/notifications");
  revalidatePath("/", "layout");
  if (logError) return { ok: true, tone: "warning" as const, message: "Notification updated, but its activity could not be logged." };
  return { ok: true, message: isRead ? "Notification marked as read." : "Notification marked as unread." };
}

export async function deleteNotificationAction(formData: FormData) {
  const context = await requireSystemAdminClient();

  if (!context) {
    return { ok: false, message: "You do not have permission to delete notifications." };
  }

  const id = String(formData.get("notification_id") ?? "");

  if (!id) {
    return { ok: false, message: "Notification ID is missing." };
  }

  const { error } = await context.supabase.from("notifications").delete().eq("id", id);
  if (error) return { ok: false, message: error.message };

  const { error: logError } = await context.supabase.from("activity_logs").insert({
    user_id: context.profile.id,
    activity: "Notification Deleted",
    description: "Notification deleted from the web admin.",
    module: "Notifications",
  });
  revalidatePath("/notifications");
  revalidatePath("/", "layout");
  if (logError) return { ok: true, tone: "warning" as const, message: "Notification deleted, but its activity could not be logged." };
  return { ok: true, message: "Notification deleted." };
}
