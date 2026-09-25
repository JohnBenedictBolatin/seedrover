import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AdminProfile } from "@/lib/auth";

export type AdminNotification = {
  id: string;
  recipientName: string;
  actorName: string | null;
  title: string;
  message: string;
  notificationType: string;
  isRead: boolean;
  actionRoute: string;
  createdAt: string;
  source: "notification" | "activity";
};

export type NotificationsSummary = {
  total: number;
  unread: number;
  inventory: number;
  system: number;
};

type NotificationRow = {
  id: string;
  title: string;
  message: string;
  notification_type: string;
  is_read: boolean;
  action_route: string | null;
  created_at: string;
  recipient: ProfileName | ProfileName[] | null;
  actor: ProfileName | ProfileName[] | null;
};

type ProfileName = {
  first_name: string | null;
  last_name: string | null;
  full_name: string | null;
};

function profileDisplayName(profile: ProfileName | null) {
  if (!profile) return null;

  const firstName = profile.first_name?.trim().split(/\s+/)[0] ?? "";
  const lastName = profile.last_name?.trim() ?? "";
  const fallbackParts = (profile.full_name ?? "").trim().split(/\s+/).filter(Boolean);
  const resolvedFirstName = firstName || fallbackParts[0] || "";
  const resolvedLastName = lastName || fallbackParts[fallbackParts.length - 1] || "";

  if (!resolvedFirstName) return null;
  return resolvedLastName
    ? `${resolvedFirstName} ${resolvedLastName.charAt(0).toUpperCase()}.`
    : resolvedFirstName;
}

function profileFromRelation(profile: ProfileName | ProfileName[] | null) {
  return Array.isArray(profile) ? profile[0] ?? null : profile;
}

function recipientName(row: NotificationRow) {
  const profile = Array.isArray(row.recipient) ? row.recipient[0] : row.recipient;
  return profileDisplayName(profile);
}

function allowedNotificationTypesFor(roleName: AdminProfile["roleName"]) {
  if (roleName === "System Administrator") {
    return null;
  }

  if (roleName === "Farm Inventory Manager" || roleName === "Inventory Staff") {
    return ["Inventory", "System"];
  }

  return [
    "Crop Reminder",
    "Robot Status",
    "System",
  ];
}

function isNoiseNotification(notification: AdminNotification) {
  const title = notification.title.trim().toLowerCase();
  const message = notification.message.trim().toLowerCase();

  return (
    [
      "login",
      "logout",
      "web login",
      "web logout",
      "notification read",
      "notification deleted",
    ].includes(title) ||
    message.includes("signed in") ||
    message.includes("signed out")
  );
}

export async function getNotificationsDashboard(profile?: AdminProfile) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      notifications: [],
      summary: null,
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("notifications")
    .select(
      "id, title, message, notification_type, is_read, action_route, created_at, recipient:profiles!notifications_recipient_id_fkey(first_name,last_name,full_name), actor:profiles!notifications_actor_id_fkey(first_name,last_name,full_name)",
    )
    .order("created_at", { ascending: false })
    .returns<NotificationRow[]>();

  if (error) {
    return {
      notifications: [],
      summary: null,
      error: error.message,
    };
  }

  const allowedTypes = profile ? allowedNotificationTypesFor(profile.roleName) : null;

  const notifications = (data ?? [])
    .map<AdminNotification>((row) => ({
      id: row.id,
      recipientName: recipientName(row) ?? "SeedRover user",
      actorName: profileDisplayName(profileFromRelation(row.actor)),
      title: row.title,
      message: row.message,
      notificationType: row.notification_type,
      isRead: row.is_read,
      actionRoute: row.action_route ?? "",
      createdAt: row.created_at,
      source: "notification",
    }))
    .filter(
      (notification) =>
        !isNoiseNotification(notification) &&
        (!allowedTypes || allowedTypes.includes(notification.notificationType)),
    );
  const combinedNotifications = notifications
    .sort(
      (left, right) =>
        new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime(),
    )
    .slice(0, 80);

  const summary: NotificationsSummary = {
    total: combinedNotifications.length,
    unread: combinedNotifications.filter((notification) => !notification.isRead).length,
    inventory: combinedNotifications.filter(
      (notification) => notification.notificationType === "Inventory",
    ).length,
    system: combinedNotifications.filter(
      (notification) => notification.notificationType === "System",
    ).length,
  };

  return {
    notifications: combinedNotifications,
    summary,
    error: null,
  };
}
