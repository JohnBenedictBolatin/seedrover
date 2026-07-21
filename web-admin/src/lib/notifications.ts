import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AdminProfile } from "@/lib/auth";

export type AdminNotification = {
  id: string;
  recipientName: string;
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
  profiles: { full_name: string } | { full_name: string }[] | null;
};

type ActivityNotificationRow = {
  id: string;
  activity: string;
  description: string | null;
  module: string;
  user_id: string | null;
  created_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function recipientName(row: NotificationRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "SeedRover user";
}

function activityUserName(row: ActivityNotificationRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "SeedRover user";
}

function allowedModulesFor(roleName: AdminProfile["roleName"]) {
  if (roleName === "System Administrator") {
    return null;
  }

  if (roleName === "Farm Inventory Manager") {
    return ["Inventory", "Stocks", "Sales", "Customers", "Discounts", "Reports"];
  }

  return ["Crops", "Planting", "Rover", "Rover Monitor"];
}

function allowedNotificationTypesFor(roleName: AdminProfile["roleName"]) {
  if (roleName === "System Administrator") {
    return null;
  }

  if (roleName === "Farm Inventory Manager") {
    return ["Inventory", "Stocks", "Sales", "Customers", "System"];
  }

  return ["Crops", "Planting", "Rover", "System"];
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

  const allowedTypes = profile ? allowedNotificationTypesFor(profile.roleName) : null;

  const notifications = (data ?? [])
    .map<AdminNotification>((row) => ({
    id: row.id,
    recipientName: recipientName(row),
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
        !allowedTypes || allowedTypes.includes(notification.notificationType),
    );

  let activityNotifications: AdminNotification[] = [];
  let activityError: string | null = null;

  if (profile) {
    let activityQuery = supabase
      .from("activity_logs")
      .select("id, activity, description, module, user_id, created_at, profiles(full_name)")
      .neq("user_id", profile.id);

    const modules = allowedModulesFor(profile.roleName);

    if (modules) {
      activityQuery = activityQuery.in("module", modules);
    }

    const { data: activityRows, error: logsError } = await activityQuery
      .order("created_at", { ascending: false })
      .limit(40)
      .returns<ActivityNotificationRow[]>();

    if (logsError) {
      activityError = logsError.message;
    }

    activityNotifications = (activityRows ?? []).map<AdminNotification>((row) => ({
      id: `activity-${row.id}`,
      recipientName: activityUserName(row),
      title: row.activity,
      message: row.description ?? `${activityUserName(row)} performed an action.`,
      notificationType: row.module,
      isRead: false,
      actionRoute: "",
      createdAt: row.created_at,
      source: "activity",
    }));
  }

  const combinedNotifications = [...notifications, ...activityNotifications]
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
    error: activityError,
  };
}
