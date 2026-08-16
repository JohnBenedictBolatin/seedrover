import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropItem = {
  id: string;
  batchCode: string;
  cropName: string;
  managerName: string;
  plantingDate: string;
  estimatedHarvest: string | null;
  growthStage: string;
  cropStatus: string;
  maintenanceNotes: string;
  imagePath: string | null;
  imageUrl: string | null;
  fieldLabel: string;
  harvestWindowStart: string | null;
  harvestWindowEnd: string | null;
  expectedStage: string;
  careStatus: string;
  latestSoilPercent: number | null;
  latestSoilAt: string | null;
};

export type CropSummary = {
  activeCrops: number;
  needsAttention: number;
  upcomingHarvests: number;
};

export type CropWeatherStatus = {
  currentCondition: string;
  temperatureC: number | null;
  rainChancePercent: number | null;
  nextRainWindow: string | null;
  fetchedAt: string | null;
  needsRefresh: boolean;
};

export type CropSensorReading = {
  id: string;
  soilMoisture: number;
  soilTemperature: number;
  environmentalTemperature: number;
  humidity: number;
  source: string;
  recordedAt: string;
};

export type CropActivityRecord = {
  id: string;
  activityType: string;
  performedAt: string;
  performedBy: string;
  quantity: number | null;
  unit: string | null;
  material: string | null;
  notes: string | null;
  observedStage: string | null;
  source: string;
};

type CropRow = {
  id: string;
  batch_code?: string | null;
  crop_name: string;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  image_path: string | null;
  crop_status: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
  field_label?: string | null;
  harvest_window_start?: string | null;
  harvest_window_end?: string | null;
  expected_stage?: string | null;
  current_care_status?: string | null;
};

type SensorRow = { crop_id: string; calibrated_value: number | null; soil_moisture: number; recorded_at: string };
type TaskRow = { crop_id: string; status: string };
type WeatherRow = { provider: string; precipitation_probability: number | null; temperature_c: number | null; condition: string | null; raw_payload: Record<string, unknown> | null; fetched_at: string };

function managerName(row: CropRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "Unassigned";
}

function fallbackBatchCode(id: string) {
  return `CRP-LEGACY-${id.replaceAll("-", "").slice(0, 8).toUpperCase()}`;
}

function isMissingCropMonitoringSchema(error: { code?: string; message?: string }) {
  const message = error.message ?? "";
  return (
    error.code === "PGRST204" ||
    /column crops\.[a-z0-9_]+ does not exist/i.test(message) ||
    /could not find the ['\"]?[a-z0-9_]+['\"]? column of ['\"]?crops['\"]? in the schema cache/i.test(message)
  );
}

export async function getCropsDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      crops: [],
      summary: null,
      weather: null,
      error: "Supabase is not configured.",
    };
  }

  let { data, error } = await supabase
    .from("crops")
    .select(
      "id, batch_code, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, field_label, harvest_window_start, harvest_window_end, expected_stage, current_care_status, profiles(full_name)",
    )
    .order("planting_date", { ascending: false })
    .returns<CropRow[]>();

  // Keep legacy crop records visible while the crop-monitoring migration is
  // being deployed. New monitoring fields use conservative display defaults.
  if (error && isMissingCropMonitoringSchema(error)) {
    const legacyResult = await supabase
      .from("crops")
      .select(
        "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, profiles(full_name)",
      )
      .order("planting_date", { ascending: false })
      .returns<CropRow[]>();
    data = legacyResult.data;
    error = legacyResult.error;
  }

  if (error) {
    return {
      crops: [],
      summary: null,
      weather: null,
      error: error.message,
    };
  }

  const cropIds = (data ?? []).map((row) => row.id);
  const [{ data: sensorData }, { data: taskData }, { data: weatherData }] = await Promise.all([
    cropIds.length === 0
      ? Promise.resolve({ data: [] as SensorRow[] })
      : supabase.from("sensor_readings").select("crop_id, calibrated_value, soil_moisture, recorded_at").in("crop_id", cropIds).order("recorded_at", { ascending: false }).returns<SensorRow[]>(),
    cropIds.length === 0
      ? Promise.resolve({ data: [] as TaskRow[] })
      : supabase.from("crop_tasks").select("crop_id, status").in("crop_id", cropIds).in("status", ["Upcoming", "Due", "Overdue", "Postponed"]).returns<TaskRow[]>(),
    supabase.from("weather_forecasts").select("provider, precipitation_probability, temperature_c, condition, raw_payload, fetched_at").order("fetched_at", { ascending: false }).limit(2).returns<WeatherRow[]>(),
  ]);
  const latestSensor = new Map<string, SensorRow>();
  for (const sensor of sensorData ?? []) if (!latestSensor.has(sensor.crop_id)) latestSensor.set(sensor.crop_id, sensor);

  const crops: CropItem[] = (data ?? []).map((row) => {
    const sensor = latestSensor.get(row.id);
    return {
      id: row.id,
      batchCode: row.batch_code?.trim() || fallbackBatchCode(row.id),
      cropName: row.crop_name,
      managerName: managerName(row),
      plantingDate: row.planting_date,
      estimatedHarvest: row.estimated_harvest,
      growthStage: row.growth_stage,
      cropStatus: row.crop_status,
      maintenanceNotes: row.maintenance_notes ?? "No notes recorded.",
      imagePath: row.image_path,
      imageUrl:
        row.image_path === null
          ? null
          : supabase.storage.from("crop-images").getPublicUrl(row.image_path).data
              .publicUrl,
      fieldLabel: row.field_label ?? "Field not labeled",
      harvestWindowStart: row.harvest_window_start ?? null,
      harvestWindowEnd: row.harvest_window_end ?? null,
      expectedStage: row.expected_stage ?? row.growth_stage,
      careStatus: row.current_care_status ?? "Review crop condition",
      latestSoilPercent: sensor?.calibrated_value ?? sensor?.soil_moisture ?? null,
      latestSoilAt: sensor?.recorded_at ?? null,
    };
  });

  const pendingTasks = taskData ?? [];
  const now = new Date();
  const soon = new Date(now.getTime() + 14 * 86400000);
  const openMeteo = (weatherData ?? []).find((row) => row.provider === "Open-Meteo");
  const rawSummary = openMeteo?.raw_payload?.summary as Record<string, unknown> | undefined;
  const nextRainAt = typeof rawSummary?.nextRainAt === "string" ? rawSummary.nextRainAt : null;
  const weather: CropWeatherStatus = {
    currentCondition: openMeteo?.condition ?? "Weather unavailable",
    temperatureC: openMeteo?.temperature_c ?? null,
    rainChancePercent: openMeteo?.precipitation_probability ?? null,
    nextRainWindow: nextRainAt,
    fetchedAt: openMeteo?.fetched_at ?? null,
    needsRefresh: typeof rawSummary?.currentCondition !== "string",
  };

  const activeCropIds = new Set(
    crops
      .filter((crop) => crop.cropStatus !== "Completed" && crop.cropStatus !== "Cancelled")
      .map((crop) => crop.id),
  );
  const attentionCropIds = new Set(
    pendingTasks
      .filter(
        (task) =>
          activeCropIds.has(task.crop_id) &&
          (task.status === "Due" || task.status === "Overdue"),
      )
      .map((task) => task.crop_id),
  );
  for (const crop of crops) {
    if (activeCropIds.has(crop.id) && crop.cropStatus === "Needs Attention") {
      attentionCropIds.add(crop.id);
    }
  }

  const summary: CropSummary = {
    activeCrops: activeCropIds.size,
    needsAttention: attentionCropIds.size,
    upcomingHarvests: crops.filter(
      (crop) =>
        crop.cropStatus === "Harvest Ready" ||
        (crop.harvestWindowStart !== null &&
          new Date(crop.harvestWindowStart) <= soon &&
          crop.cropStatus !== "Completed" &&
          crop.cropStatus !== "Cancelled"),
    ).length,
  };

  return {
    crops,
    summary,
    weather,
    error: null,
  };
}
