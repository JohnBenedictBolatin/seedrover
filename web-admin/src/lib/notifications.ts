import { createSupabaseServerClient } from "@/lib/supabase/server";

export type AdminNotification = {
  id: string;
  recipientName: string;
  title: string;
  message: string;
  notificationType: string;
  isRead: boolean;
  actionRoute: string;
  createdAt: string;
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
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function recipientName(row: NotificationRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "SeedRover user";
}

export async function getNotificationsDashboard() {
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
      "id, title, message, notification_type, is_read, action_route, created_at, profiles(full_name)",
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

  const notifications = (data ?? []).map<AdminNotification>((row) => ({
    id: row.id,
    recipientName: recipientName(row),
    title: row.title,
    message: row.message,
    notificationType: row.notification_type,
    isRead: row.is_read,
    actionRoute: row.action_route ?? "",
    createdAt: row.created_at,
  }));

  const summary: NotificationsSummary = {
    total: notifications.length,
    unread: notifications.filter((notification) => !notification.isRead).length,
    inventory: notifications.filter(
      (notification) => notification.notificationType === "Inventory",
    ).length,
    system: notifications.filter(
      (notification) => notification.notificationType === "System",
    ).length,
  };

  return {
    notifications,
    summary,
    error: null,
  };
}
