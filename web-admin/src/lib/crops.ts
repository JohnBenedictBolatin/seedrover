import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropTask = { id: string; crop_id: string; task_type: string; title: string; recommendation: string; due_at: string; status: string; priority: string };

export type CropItem = {
  managerId: string | null;
  stages: string[];
  tasks: CropTask[];
  forecastConfidence: string;
  harvestedAt: string | null;
  lastObservedAt: string | null;
  weeklyActivities: number;
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
  nextCareTask: string | null;
  nextCareDueAt: string | null;
  latestSoilPercent: number | null;
  latestSoilAt: string | null;
  latestSoilSource: string | null;
  latestSoilCalibrated: boolean | null;
  latestSoilCalibrationVersion: string | null;
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
  soilRaw: number | null;
  soilMoisture: number | null;
  soilTemperature: number | null;
  environmentalTemperature: number | null;
  humidity: number | null;
  source: string;
  recordedAt: string;
  provenanceStatus: "verified_hardware" | "unverified" | "simulated" | "demo";
  soilMoistureCalibrated: boolean | null;
  calibrationVersion: string | null;
  fresh: boolean;
};

export type CropActivityRecord = {
  id: string;
  photos: { url: string; path: string }[];
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
  assigned_manager?: string | null;
  harvested_at?: string | null;
  forecast_confidence?: string;
  crop_profiles?: { stage_plan: { stage: string }[] } | null;
  id: string;
  batch_code?: string | null;
  crop_name: string;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  image_path: string | null;
  crop_status: string;
  crop_profile_key?: string | null;
  profiles: { full_name: string } | { full_name: string }[] | null;
  field_label?: string | null;
  harvest_window_start?: string | null;
  harvest_window_end?: string | null;
  expected_stage?: string | null;
  current_care_status?: string | null;
};

type SensorRow = { crop_id: string; calibrated_value: number | null; soil_moisture: number | null; recorded_at: string; source: string | null; provenance_status: CropSensorReading["provenanceStatus"] | null; soil_moisture_calibrated: boolean | null; calibration_version: string | null };
type TaskRow = CropTask;
type SeedImageRow = { profile_key: string; image_path: string };
type WeatherRow = { provider: string; precipitation_probability: number | null; temperature_c: number | null; condition: string | null; raw_payload: Record<string, unknown> | null; fetched_at: string };

function validSensorNumber(value: number | null, minimum: number, maximum: number) {
  return value != null && Number.isFinite(value) && value >= minimum && value <= maximum ? value : null;
}

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
      "id, batch_code, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, crop_profile_key, field_label, harvest_window_start, harvest_window_end, expected_stage, current_care_status, assigned_manager, harvested_at, forecast_confidence, crop_profiles(stage_plan), profiles(full_name)",
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
  const [{ data: sensorData }, { data: taskData, error: taskError }, { data: weatherData }, { data: seedImageData }, { data: activityData }] = await Promise.all([
    cropIds.length === 0
      ? Promise.resolve({ data: [] as SensorRow[] })
      : supabase.from("sensor_readings").select("crop_id, calibrated_value, soil_moisture, recorded_at, source, provenance_status, soil_moisture_calibrated, calibration_version").in("crop_id", cropIds).order("recorded_at", { ascending: false }).returns<SensorRow[]>(),
    cropIds.length === 0
      ? Promise.resolve({ data: [] as TaskRow[], error: null })
      : supabase.from("crop_tasks").select("id, crop_id, task_type, status, title, recommendation, due_at, priority").in("crop_id", cropIds).in("status", ["Upcoming", "Due", "Overdue", "Postponed"]).order("due_at", { ascending: true }).returns<TaskRow[]>(),
    supabase.from("weather_forecasts").select("provider, precipitation_probability, temperature_c, condition, raw_payload, fetched_at").order("fetched_at", { ascending: false }).limit(2).returns<WeatherRow[]>(),
    supabase.from("crop_profile_images").select("profile_key, image_path").returns<SeedImageRow[]>(),
    supabase.from("crop_activities").select("crop_id, activity_type, performed_at").order("performed_at", { ascending: false }),
  ]);
  const rank = (priority: string) => priority === "Critical" ? 0 : priority === "Important" ? 1 : 2;
  taskData?.sort((a, b) => rank(a.priority) - rank(b.priority) || a.due_at.localeCompare(b.due_at));
  const latestSensor = new Map<string, SensorRow>();
  for (const sensor of sensorData ?? []) {
    const age = Date.now() - new Date(sensor.recorded_at).getTime();
    if (!latestSensor.has(sensor.crop_id) && sensor.provenance_status === "verified_hardware" && age >= 0 && age <= 60_000) latestSensor.set(sensor.crop_id, sensor);
  }
  const nextTask = new Map<string, TaskRow>();
  for (const task of taskData ?? []) if (!nextTask.has(task.crop_id)) nextTask.set(task.crop_id, task);
  const seedImages = new Map((seedImageData ?? []).map((row) => [row.profile_key, row.image_path]));
  const crops: CropItem[] = (data ?? []).map((row) => {
    const sensor = latestSensor.get(row.id);
    const task = nextTask.get(row.id);
    const seedKey = row.crop_profile_key ?? row.crop_name.toLowerCase();
    const imagePath = row.image_path ?? seedImages.get(seedKey) ?? null;
    return {
      id: row.id,
      managerId: row.assigned_manager ?? null,
      stages: [...new Set([...(row.crop_profiles?.stage_plan ?? []).map((stage) => stage.stage), "Harvest Ready"])].filter((stage) => !["Completed", "Repeated Harvest"].includes(stage)),
      tasks: (taskData ?? []).filter((task) => task.crop_id === row.id),
      forecastConfidence: row.forecast_confidence ?? "Unavailable",
      harvestedAt: row.harvested_at ?? null,
      lastObservedAt: (activityData ?? []).find((a) => a.crop_id === row.id && ["Inspected", "Stage Observed"].includes(a.activity_type))?.performed_at ?? null,
      weeklyActivities: (activityData ?? []).filter((a) => a.crop_id === row.id && new Date(a.performed_at).getTime() >= Date.now() - 7 * 86400000).length,
      batchCode: row.batch_code?.trim() || fallbackBatchCode(row.id),
      cropName: row.crop_name,
      managerName: managerName(row),
      plantingDate: row.planting_date,
      estimatedHarvest: row.estimated_harvest,
      growthStage: row.growth_stage,
      cropStatus: row.crop_status,
      maintenanceNotes: row.maintenance_notes ?? "No notes recorded.",
      imagePath,
      imageUrl:
        imagePath === null
          ? null
          : supabase.storage.from("crop-images").getPublicUrl(imagePath).data
              .publicUrl,
      fieldLabel: row.field_label ?? "Field not labeled",
      harvestWindowStart: row.harvest_window_start ?? null,
      harvestWindowEnd: row.harvest_window_end ?? null,
      expectedStage: row.expected_stage ?? row.growth_stage,
      careStatus: row.current_care_status ?? "Review crop condition",
      nextCareTask: task?.title ?? null,
      nextCareDueAt: task?.due_at ?? null,
      latestSoilPercent: sensor?.soil_moisture_calibrated && sensor.calibration_version ? validSensorNumber(sensor.calibrated_value ?? sensor.soil_moisture, 0, 100) : null,
      latestSoilAt: sensor?.recorded_at ?? null,
      latestSoilSource: sensor?.source ?? null,
      latestSoilCalibrated: sensor?.soil_moisture_calibrated === false ? false : sensor?.soil_moisture_calibrated === true && sensor.calibration_version ? true : null,
      latestSoilCalibrationVersion: sensor?.calibration_version ?? null,
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
    error: taskError ? "Care tasks could not be loaded: " + taskError.message : null,
  };
}
