import { createSupabaseServerClient } from "@/lib/supabase/server";

export type RoverStatus = {
  batteryLevel: number;
  seedLevel: number;
  roverStatus: string;
  wifiConnected: boolean;
  bluetoothConnected: boolean;
  cameraConnected: boolean;
  currentActivity: string;
  speed: number;
  emergencyStop: boolean;
  lastUpdated: string;
};

export type RoverCommand = {
  id: string;
  command: string;
  status: string;
  issuedBy: string;
  executedAt: string | null;
  createdAt: string;
};

type RoverStatusRow = {
  battery_level: number;
  seed_level: number;
  rover_status: string;
  wifi_connected: boolean;
  bluetooth_connected: boolean;
  camera_connected: boolean;
  current_activity: string;
  speed: number;
  emergency_stop: boolean;
  last_updated: string;
};

type RoverCommandRow = {
  id: string;
  command: string;
  status: string;
  executed_at: string | null;
  created_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function profileName(row: RoverCommandRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "SeedRover user";
}

export async function getRoverMonitor() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      status: null,
      commands: [],
      error: "Supabase is not configured.",
    };
  }

  const [{ data: statusRows, error: statusError }, { data: commandRows }] =
    await Promise.all([
      supabase
        .from("robot_status")
        .select(
          "battery_level, seed_level, rover_status, wifi_connected, bluetooth_connected, camera_connected, current_activity, speed, emergency_stop, last_updated",
        )
        .eq("is_active", true)
        .limit(1)
        .returns<RoverStatusRow[]>(),
      supabase
        .from("robot_commands")
        .select("id, command, status, executed_at, created_at, profiles(full_name)")
        .order("created_at", { ascending: false })
        .limit(8)
        .returns<RoverCommandRow[]>(),
    ]);

  if (statusError) {
    return {
      status: null,
      commands: [],
      error: statusError.message,
    };
  }

  const statusRow = statusRows?.[0];

  return {
    status: statusRow
      ? {
          batteryLevel: statusRow.battery_level,
          seedLevel: statusRow.seed_level,
          roverStatus: statusRow.rover_status,
          wifiConnected: statusRow.wifi_connected,
          bluetoothConnected: statusRow.bluetooth_connected,
          cameraConnected: statusRow.camera_connected,
          currentActivity: statusRow.current_activity,
          speed: statusRow.speed,
          emergencyStop: statusRow.emergency_stop,
          lastUpdated: statusRow.last_updated,
        }
      : null,
    commands: (commandRows ?? []).map<RoverCommand>((row) => ({
      id: row.id,
      command: row.command,
      status: row.status,
      issuedBy: profileName(row),
      executedAt: row.executed_at,
      createdAt: row.created_at,
    })),
    error: null,
  };
}
