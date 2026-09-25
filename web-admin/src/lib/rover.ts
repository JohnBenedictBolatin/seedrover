import { createSupabaseServerClient } from "@/lib/supabase/server";

export type RoverStatus = {
  roverStatus: string | null;
  wifiConnected: boolean | null;
  currentActivity: string | null;
  emergencyStop: boolean | null;
  lastUpdated: string | null;
  heartbeatFresh: boolean | null;
};

export type RoverCommand = {
  id: string;
  command: string;
  payload: Record<string, unknown>;
  status: string;
  issuedBy: string;
  executedAt: string | null;
  createdAt: string;
  acknowledgedAt: string | null;
  failureDetails: string | null;
};

export type RoverSensorReading = {
  id: string;
  soilMoisture: number | null;
  soilTemperature: number | null;
  humidity: number | null;
  environmentalTemperature: number | null;
  soilRaw: number | null;
  recordedAt: string;
  source: string | null;
  provenanceStatus: "verified_hardware" | "unverified" | "simulated" | "demo";
  soilMoistureCalibrated: boolean | null;
  calibrationVersion: string | null;
  firmwareVersion: string | null;
  fresh: boolean;
};

type RoverStatusRow = {
  rover_status: string | null;
  wifi_connected: boolean | null;
  current_activity: string | null;
  emergency_stop: boolean | null;
  last_updated: string | null;
};

type RoverCommandRow = {
  id: string;
  command: string;
  payload: Record<string, unknown> | null;
  status: string;
  executed_at: string | null;
  created_at: string;
  acknowledged_at: string | null;
  failure_details: string | null;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

type SensorReadingRow = {
  id: string;
  soil_moisture: number | string | null;
  soil_raw: number | string | null;
  calibrated_value: number | string | null;
  soil_temperature: number | string | null;
  humidity: number | string | null;
  environmental_temperature: number | string | null;
  recorded_at: string;
  source: string | null;
  provenance_status: RoverSensorReading["provenanceStatus"] | null;
  soil_moisture_calibrated: boolean | null;
  calibration_version: string | null;
  firmware_version: string | null;
};

function profileName(row: RoverCommandRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name.trim() || "Unavailable";
}

function nullableNumber(value: number | string | null, minimum = Number.NEGATIVE_INFINITY, maximum = Number.POSITIVE_INFINITY) {
  if (value === null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= minimum && number <= maximum ? number : null;
}

function isFreshTimestamp(value: string | null, maxAgeMs: number) {
  if (!value) return false;
  const ageMs = Date.now() - new Date(value).getTime();
  return Number.isFinite(ageMs) && ageMs >= 0 && ageMs <= maxAgeMs;
}

export async function getRoverMonitor({ commandLimit = 8 }: { commandLimit?: number } = {}) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    const message = "Supabase is not configured.";
    return {
      status: null,
      commands: [],
      sensors: null,
      sensorHistory: [],
      statusError: message,
      commandError: message,
      sensorError: message,
      // Kept for existing dashboard and assistant consumers.
      error: message,
    };
  }

  const [statusResult, commandResult, sensorResult] = await Promise.all([
    supabase
      .from("robot_status")
      .select(
        "rover_status, wifi_connected, current_activity, emergency_stop, last_updated",
      )
      .eq("is_active", true)
      .limit(1)
      .returns<RoverStatusRow[]>(),
    supabase
      .from("robot_commands")
      .select("id, command, payload, status, executed_at, created_at, acknowledged_at, failure_details, profiles(full_name)")
      .order("created_at", { ascending: false })
      .limit(commandLimit)
      .returns<RoverCommandRow[]>(),
    supabase
      .from("sensor_readings")
      .select(
        "id, soil_moisture, calibrated_value, soil_raw, soil_temperature, humidity, environmental_temperature, recorded_at, source, provenance_status, soil_moisture_calibrated, calibration_version, firmware_version",
      )
      .order("recorded_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(100)
      .returns<SensorReadingRow[]>(),
  ]);

  const statusError = statusResult.error?.message ?? null;
  const commandError = commandResult.error?.message ?? null;
  const sensorError = sensorResult.error?.message ?? null;
  const statusRow = statusError ? null : statusResult.data?.[0];
  const history = (sensorError ? [] : sensorResult.data ?? []).map<RoverSensorReading>((row) => {
    const recordedAt = row.recorded_at;
    const sensorAgeMs = Date.now() - new Date(recordedAt).getTime();

    return {
      id: row.id,
      // A calibrated value takes precedence when present; null remains null,
      // while a real 0% reading remains exactly zero.
      soilMoisture: row.soil_moisture_calibrated && row.calibration_version ? nullableNumber(row.calibrated_value ?? row.soil_moisture, 0, 100) : null,
      soilTemperature: nullableNumber(row.soil_temperature, -55, 125),
      humidity: nullableNumber(row.humidity, 0, 100),
      environmentalTemperature: nullableNumber(row.environmental_temperature, -40, 80),
      soilRaw: nullableNumber(row.soil_raw, 1, 4094),
      recordedAt,
      source: row.source?.trim() || null,
      provenanceStatus: row.provenance_status ?? "unverified",
      soilMoistureCalibrated: row.soil_moisture_calibrated === false ? false : row.soil_moisture_calibrated === true && Boolean(row.calibration_version) ? true : null,
      calibrationVersion: row.calibration_version,
      firmwareVersion: row.firmware_version,
      fresh: Number.isFinite(sensorAgeMs) && sensorAgeMs >= 0 && sensorAgeMs <= 60_000,
    };
  });
  const sensor = history.find((reading) => reading.provenanceStatus === "verified_hardware" && reading.fresh) ?? null;
  const heartbeatFresh = statusRow?.last_updated
    ? isFreshTimestamp(statusRow.last_updated, 9_000)
    : null;

  return {
    status: statusRow
      ? {
          roverStatus: heartbeatFresh === false ? "Offline" : statusRow.rover_status?.trim() || null,
          wifiConnected: statusRow.wifi_connected,
          currentActivity: statusRow.current_activity?.trim() || null,
          emergencyStop: statusRow.emergency_stop,
          lastUpdated: statusRow.last_updated,
          heartbeatFresh,
        }
      : null,
    commands: (commandError ? [] : commandResult.data ?? []).map<RoverCommand>((row) => ({
      id: row.id,
      command: row.command,
      payload: row.payload ?? {},
      status: row.status,
      issuedBy: profileName(row),
      executedAt: row.executed_at,
      createdAt: row.created_at,
      acknowledgedAt: row.acknowledged_at,
      failureDetails: row.failure_details,
    })),
    sensors: sensor,
    sensorHistory: history,
    statusError,
    commandError,
    sensorError,
    // Preserve the original error field for callers that still depend on it.
    error: statusError,
  };
}
