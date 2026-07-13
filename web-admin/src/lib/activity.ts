import { createSupabaseServerClient } from "@/lib/supabase/server";

export type ActivityLogItem = {
  id: string;
  activity: string;
  description: string;
  module: string;
  userName: string;
  createdAt: string;
};

export type ActivitySummary = {
  total: number;
  authentication: number;
  salesAndStocks: number;
  system: number;
};

type ActivityRow = {
  id: string;
  activity: string;
  description: string | null;
  module: string;
  created_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function userName(row: ActivityRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "System";
}

export async function getActivityDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      logs: [],
      summary: null,
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("activity_logs")
    .select("id, activity, description, module, created_at, profiles(full_name)")
    .order("created_at", { ascending: false })
    .limit(100)
    .returns<ActivityRow[]>();

  if (error) {
    return {
      logs: [],
      summary: null,
      error: error.message,
    };
  }

  const logs = (data ?? []).map<ActivityLogItem>((row) => ({
    id: row.id,
    activity: row.activity,
    description: row.description ?? "Activity recorded.",
    module: row.module,
    userName: userName(row),
    createdAt: row.created_at,
  }));

  const summary: ActivitySummary = {
    total: logs.length,
    authentication: logs.filter((log) => log.module === "Authentication").length,
    salesAndStocks: logs.filter((log) => ["Sales", "Stocks"].includes(log.module))
      .length,
    system: logs.filter((log) =>
      ["System", "Users", "Notifications"].includes(log.module),
    ).length,
  };

  return {
    logs,
    summary,
    error: null,
  };
}
