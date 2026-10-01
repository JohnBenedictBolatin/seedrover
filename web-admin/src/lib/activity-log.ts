import type { createSupabaseServerClient } from "@/lib/supabase/server";

type ActivitySupabase = NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>;

export type ActivityModule =
  | "Authentication"
  | "Dashboard"
  | "Rover"
  | "Rover Monitor"
  | "Planting"
  | "Crops"
  | "Inventory"
  | "Stocks"
  | "Sales"
  | "Customers"
  | "Discounts"
  | "Reports"
  | "Notifications"
  | "Profile"
  | "Users"
  | "System";

export async function writeActivityLog(
  supabase: ActivitySupabase,
  entry: {
    userId: string | null;
    activity: string;
    description: string;
    module: ActivityModule;
  },
): Promise<boolean> {
  try {
    const { error } = await supabase.from("activity_logs").insert({
      user_id: entry.userId,
      activity: entry.activity,
      description: entry.description,
      module: entry.module,
    });

    if (error) {
      console.error("Activity log insert failed.", {
        activity: entry.activity,
        module: entry.module,
        message: error.message,
      });
      return false;
    }
    return true;
  } catch (error) {
    console.error("Activity log insert failed.", {
      activity: entry.activity,
      module: entry.module,
      message: error instanceof Error ? error.message : "Unknown activity log error.",
    });
    return false;
  }
}
