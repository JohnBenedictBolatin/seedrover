import { createSupabaseServerClient } from "@/lib/supabase/server";
import { businessDateKey, startOfBusinessWeek } from "@/lib/business-time";

async function fetchAllPages<T>(
  fetchPage: (from: number, to: number) => PromiseLike<{
    data: T[] | null;
    error: { message: string } | null;
  }>,
) {
  const rows: T[] = [];
  const size = 500;
  for (let from = 0;; from += size) {
    const { data, error } = await fetchPage(from, from + size - 1);
    if (error) return { data: null, error };
    const page = data ?? [];
    rows.push(...page);
    if (page.length < size) return { data: rows, error: null };
  }
}

export type CropTask = { id: string; crop_id: string; task_type: string; title: string; recommendation: string; recommendation_data?: Record<string, unknown> | null; due_at: string; status: string; priority: string };

export type CropItem = {
  managerId: string | null;
  stages: string[];
  tasks: CropTask[];
  forecastConfidence: string;
  harvestedAt: string | null;
  harvestMode: "single" | "repeat";
  harvestCount: number;
  harvestedQuantity: number;
  cropProfileKey: string | null;
  lastObservedAt: string | null;
  weeklyActivities: number;
  id: string;
  batchCode: string;
  assignedPlantingName: string;
  customPlantingName: string | null;
  plantingNameVersion: number;
  displayName: string;
  cropName: string;
  managerName: string;
  plantedBy: string;
  plantingDate: string;
  estimatedHarvest: string | null;
  growthStage: string;
  cropStatus: string;
  maintenanceNotes: string;
  imagePath: string | null;
  imageUrl: string | null;
  fieldLabel: string;
  plantingTargetDrops: number | null;
  plantingCompletedDrops: number | null;
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

const cropStageImageKeys: Record<string, Record<string, string>> = {
  sitaw: {
    seeded: "seeded",
    germinating: "germinating",
    vegetative: "vegetative",
    trellising: "trellising",
    flowering: "flowering",
    fruiting: "pod_formation",
    "pod formation": "pod_formation",
    "first harvest": "harvest_ready",
    "harvest ready": "harvest_ready",
    "repeated harvest": "repeated_harvest",
    completed: "harvested",
  },
  calamansi: {
    seeded: "seedbed",
    seedbed: "seedbed",
    germinating: "germinating",
    "nursery seedling": "nursery_seedling",
    "transplant review": "transplant_review",
    establishing: "establishing",
    juvenile: "juvenile",
    "first bearing": "first_bearing",
    fruiting: "first_bearing",
    "harvest ready": "harvest_ready",
    completed: "harvested",
  },
  peanut: {
    seeded: "seeded",
    germinating: "germinating",
    vegetative: "vegetative",
    flowering: "flowering",
    fruiting: "pod_development",
    pegging: "pegging",
    "pod development": "pod_development",
    "maturity check": "maturity_check",
    "harvest ready": "harvest_ready",
    completed: "harvested",
  },
};

function cropStagePlaceholderImage(profileKey: string, stage: string, status: string) {
  const crop = profileKey.trim().toLowerCase();
  const stageKey = status.trim().toLowerCase() === "completed"
    ? "completed"
    : stage.trim().toLowerCase().replace(/[_-]+/g, " ").replace(/\s+/g, " ");
  const stageImages = cropStageImageKeys[crop];
  if (!stageImages) return null;
  const imageStage = stageImages[stageKey];
  return imageStage ? `/images/crops/${crop}_${imageStage}.webp` : `/images/crops/${crop}.webp`;
}

export type CropSummary = {
  activeCrops: number;
  needsAttention: number;
  upcomingHarvests: number;
};

export type CropWeatherStatus = {
  source: "WeatherAPI" | "Unavailable";
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
  harvest_mode?: "single" | "repeat" | null;
  forecast_confidence?: string;
  crop_profiles?: { stage_plan: { stage: string }[] } | null;
  id: string;
  batch_code?: string | null;
  crop_name: string;
  assigned_planting_name?: string | null;
  custom_planting_name?: string | null;
  planting_name_version?: number | null;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  image_path: string | null;
  crop_status: string;
  crop_profile_key?: string | null;
  profiles: { full_name: string } | { full_name: string }[] | null;
  field_label?: string | null;
  planting_log_id?: string | null;
  completed_drop_cycles?: number | null;
  harvest_window_start?: string | null;
  harvest_window_end?: string | null;
  expected_stage?: string | null;
  current_care_status?: string | null;
};

type SensorRow = { crop_id: string; calibrated_value: number | null; soil_moisture: number | null; recorded_at: string; source: string | null; provenance_status: CropSensorReading["provenanceStatus"] | null; soil_moisture_calibrated: boolean | null; calibration_version: string | null };
type TaskRow = CropTask;
type SeedImageRow = { profile_key: string; image_path: string };
export async function getWeatherApiForecast(): Promise<CropWeatherStatus | null> {
  const apiKey = process.env.WEATHERAPI_API_KEY?.trim();
  if (!apiKey) return null;

  const url = new URL("https://api.weatherapi.com/v1/forecast.json");
  url.searchParams.set("key", apiKey);
  url.searchParams.set("q", "13.634597,123.330082");
  url.searchParams.set("days", "2");
  url.searchParams.set("aqi", "no");
  url.searchParams.set("alerts", "no");

  try {
    const response = await fetch(url, {
      cache: "no-store",
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) return null;

    const payload = await response.json() as {
      current?: {
        condition?: { text?: unknown };
        temp_c?: unknown;
        last_updated_epoch?: unknown;
      };
      forecast?: {
        forecastday?: { hour?: { time_epoch?: unknown; chance_of_rain?: unknown; precip_mm?: unknown }[] }[];
      };
    };
    const current = payload.current;
    const now = Math.floor(Date.now() / 1000);
    const hours = (payload.forecast?.forecastday ?? []).flatMap((day) => day.hour ?? [])
      .filter((hour) => typeof hour.time_epoch === "number" && hour.time_epoch >= now - 3600 && hour.time_epoch <= now + 24 * 3600);
    const rainChances = hours.map((hour) => hour.chance_of_rain).filter((value): value is number => typeof value === "number" && Number.isFinite(value));
    const nextRain = hours.find((hour) =>
      (typeof hour.precip_mm === "number" && hour.precip_mm > 0.1) ||
      (typeof hour.chance_of_rain === "number" && hour.chance_of_rain >= 50),
    );
    const updatedEpoch = typeof current?.last_updated_epoch === "number" ? current.last_updated_epoch : now;

    return {
      source: "WeatherAPI",
      currentCondition: typeof current?.condition?.text === "string" ? current.condition.text : "Weather unavailable",
      temperatureC: typeof current?.temp_c === "number" && Number.isFinite(current.temp_c) ? current.temp_c : null,
      rainChancePercent: rainChances.length ? Math.max(...rainChances) : null,
      nextRainWindow: typeof nextRain?.time_epoch === "number" ? new Date(nextRain.time_epoch * 1000).toISOString() : null,
      fetchedAt: new Date(updatedEpoch * 1000).toISOString(),
      needsRefresh: false,
    };
  } catch {
    return null;
  }
}

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

function displayGrowthStage(stage: string, plannedStages: string[] = []) {
  if (stage === "First Harvest") return "Harvest Ready";

  // Rover planting records use the generic "Seeded" stage. Calamansi's
  // profile calls that same initial stage "Seedbed".
  if (stage.trim().toLowerCase() === "seeded") {
    return plannedStages.find((plannedStage) => plannedStage.trim().toLowerCase() === "seedbed") ?? stage;
  }

  return stage;
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
      recentHarvestMonths: [],
      harvestHistoryError: null,
    };
  }

  const assessmentNow = new Date();
  const weekStart = startOfBusinessWeek(assessmentNow);
  const nextTwoWeeksDate = businessDateKey(new Date(assessmentNow.getTime() + 14 * 86400000));
  const currentBusinessDate = businessDateKey(assessmentNow);
  const [businessYear, businessMonth] = currentBusinessDate.split("-").map(Number);
  const harvestPeriodStart = new Date(Date.UTC(businessYear, businessMonth - 6, 1)).toISOString().slice(0, 10);
  const harvestPeriodEnd = new Date(Date.UTC(businessYear, businessMonth, 1)).toISOString().slice(0, 10);

  const fetchCropRows = (columns: string) => fetchAllPages<CropRow>((from, to) => supabase
    .from("crops")
    .select(columns)
    .order("planting_date", { ascending: false })
    .order("id", { ascending: true })
    .range(from, to)
    .returns<CropRow[]>());
  let { data, error } = await fetchCropRows(
    "id, batch_code, crop_name, assigned_planting_name, custom_planting_name, planting_name_version, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, crop_profile_key, harvest_mode, field_label, planting_log_id, completed_drop_cycles, harvest_window_start, harvest_window_end, expected_stage, current_care_status, assigned_manager, harvested_at, forecast_confidence, crop_profiles(stage_plan), profiles(full_name)",
  );

  // Keep legacy crop records visible while the crop-monitoring migration is
  // being deployed. New monitoring fields use conservative display defaults.
  if (error && isMissingCropMonitoringSchema(error)) {
    const legacyResult = await fetchCropRows(
      "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, profiles(full_name)",
    );
    data = legacyResult.data;
    error = legacyResult.error;
  }

  if (error) {
    return {
      crops: [],
      summary: null,
      weather: null,
      error: error.message,
      recentHarvestMonths: [],
      harvestHistoryError: null,
    };
  }

  const cropIds = (data ?? []).map((row) => row.id);
  const { data: harvestSummaryRows } = cropIds.length === 0
    ? { data: [] }
    : await supabase.rpc("get_crop_harvest_summaries", { p_crop_ids: cropIds });
  const harvestSummaries = new Map<string, { harvest_count: number; total_quantity: number }>(
    ((harvestSummaryRows ?? []) as { crop_id: string; harvest_count: number; total_quantity: number }[])
      .map((summary) => [summary.crop_id, summary]),
  );
  const { data: harvestPeriodRows, error: harvestPeriodError } = await supabase
    .from("crop_harvests")
    .select("harvest_date, quantity")
    .gte("harvest_date", harvestPeriodStart)
    .lt("harvest_date", harvestPeriodEnd)
    .order("harvest_date", { ascending: true });
  const monthlyHarvests = new Map<string, { count: number; kilograms: number }>();
  for (const row of harvestPeriodRows ?? []) {
    const key = String(row.harvest_date).slice(0, 7);
    const current = monthlyHarvests.get(key) ?? { count: 0, kilograms: 0 };
    current.count += 1;
    current.kilograms += Number(row.quantity ?? 0);
    monthlyHarvests.set(key, current);
  }
  const recentHarvestMonths = Array.from({ length: 6 }, (_, index) => {
    const date = new Date(Date.UTC(businessYear, businessMonth - 6 + index, 1));
    const key = `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
    return { key, label: date.toLocaleDateString("en", { month: "short", timeZone: "UTC" }), ...(monthlyHarvests.get(key) ?? { count: 0, kilograms: 0 }) };
  });
  const plantingLogIds = [...new Set((data ?? []).map((row) => row.planting_log_id).filter((id): id is string => Boolean(id)))];
  const { data: plantingLogData } = plantingLogIds.length === 0
    ? { data: [] as { id: string; target_drop_cycles: number | null; completed_drop_cycles: number | null; field_label: string | null; profiles: { full_name: string } | { full_name: string }[] | null }[] }
    : await supabase.from("planting_logs").select("id, target_drop_cycles, completed_drop_cycles, field_label, profiles!planting_logs_operator_id_fkey(full_name)").in("id", plantingLogIds);
  const plantingLogs = new Map((plantingLogData ?? []).map((row) => [row.id, row]));
  const [sensorResult, taskResult, seedImageResult, activityResult, liveWeather] = await Promise.all([
    cropIds.length === 0
      ? Promise.resolve({ data: [] as SensorRow[], error: null })
      : fetchAllPages<SensorRow>((from, to) => supabase
          .from("sensor_readings")
          .select("id, crop_id, calibrated_value, soil_moisture, recorded_at, source, provenance_status, soil_moisture_calibrated, calibration_version")
          .in("crop_id", cropIds)
          .gte("recorded_at", new Date(assessmentNow.getTime() - 60_000).toISOString())
          .lt("recorded_at", assessmentNow.toISOString())
          .order("recorded_at", { ascending: false })
          .order("id", { ascending: true })
          .range(from, to)
          .returns<SensorRow[]>()),
    cropIds.length === 0
      ? Promise.resolve({ data: [] as TaskRow[], error: null })
      : fetchAllPages<TaskRow>((from, to) => supabase
          .from("crop_tasks")
          .select("id, crop_id, task_type, status, title, recommendation, recommendation_data, due_at, priority")
          .in("crop_id", cropIds)
          .in("status", ["Upcoming", "Due", "Overdue", "Postponed"])
          .order("due_at", { ascending: true })
          .order("id", { ascending: true })
          .range(from, to)
          .returns<TaskRow[]>()),
    supabase.from("crop_profile_images").select("profile_key, image_path").returns<SeedImageRow[]>(),
    cropIds.length === 0
      ? Promise.resolve({ data: [] as { crop_id: string; last_observed_at: string | null; weekly_activity_count: number; latest_drop_cycles: number | null }[], error: null })
      : supabase.rpc("get_crop_activity_summaries", {
          p_crop_ids: cropIds,
          p_week_start: weekStart.toISOString(),
          p_as_of: assessmentNow.toISOString(),
        }) as PromiseLike<{
          data: { crop_id: string; last_observed_at: string | null; weekly_activity_count: number; latest_drop_cycles: number | null }[] | null;
          error: { message: string } | null;
        }>,
    getWeatherApiForecast(),
  ]);
  const sensorData = sensorResult.data ?? [];
  const taskData = taskResult.data ?? [];
  const seedImageData = seedImageResult.data ?? [];
  const activityData = activityResult.data ?? [];
  const relatedDataError = sensorResult.error?.message ?? taskResult.error?.message ?? activityResult.error?.message ?? null;
  const rank = (priority: string) => priority === "Critical" ? 0 : priority === "Important" ? 1 : 2;
  taskData?.sort((a, b) => rank(a.priority) - rank(b.priority) || a.due_at.localeCompare(b.due_at));
  const latestSensor = new Map<string, SensorRow>();
  for (const sensor of sensorData ?? []) {
    const age = Date.now() - new Date(sensor.recorded_at).getTime();
    if (!latestSensor.has(sensor.crop_id) && sensor.provenance_status === "verified_hardware" && age >= 0 && age <= 60_000) latestSensor.set(sensor.crop_id, sensor);
  }
  const nextTask = new Map<string, TaskRow>();
  for (const task of taskData ?? []) if (!nextTask.has(task.crop_id)) nextTask.set(task.crop_id, task);
  const activitySummary = new Map(activityData.map((activity) => [activity.crop_id, activity]));
  const seedImages = new Map((seedImageData ?? []).map((row) => [row.profile_key, row.image_path]));
  const crops: CropItem[] = (data ?? []).map((row) => {
    const sensor = latestSensor.get(row.id);
    const task = nextTask.get(row.id);
    const plantingLog = row.planting_log_id ? plantingLogs.get(row.planting_log_id) : undefined;
    const seedKey = row.crop_profile_key ?? row.crop_name.toLowerCase();
    const imagePath = row.image_path ?? seedImages.get(seedKey) ?? null;
    const stages = [
      ...new Set((row.crop_profiles?.stage_plan ?? [])
        .map((stage) => displayGrowthStage(stage.stage))
        .filter((stage) => stage !== "Completed")),
    ];
    if (stages.length > 0 && !stages.some((stage) => stage.toLowerCase() === "harvest ready")) {
      const repeatedHarvestIndex = stages.findIndex(
        (stage) => stage.toLowerCase() === "repeated harvest",
      );
      stages.splice(
        repeatedHarvestIndex < 0 ? stages.length : repeatedHarvestIndex,
        0,
        "Harvest Ready",
      );
    }
    const growthStage = displayGrowthStage(row.growth_stage, stages);
    const cropStatus = row.crop_status;
    const localStageImage = cropStagePlaceholderImage(seedKey, growthStage, cropStatus);
    return {
      id: row.id,
      managerId: row.assigned_manager ?? null,
      stages,
      tasks: (taskData ?? []).filter((task) => task.crop_id === row.id),
      forecastConfidence: row.forecast_confidence ?? "Unavailable",
      harvestedAt: row.harvested_at ?? null,
      harvestMode: row.harvest_mode ?? (row.crop_profile_key === "sitaw" || row.crop_profile_key === "calamansi" ? "repeat" : "single"),
      harvestCount: Number(harvestSummaries.get(row.id)?.harvest_count ?? 0),
      harvestedQuantity: Number(harvestSummaries.get(row.id)?.total_quantity ?? 0),
      cropProfileKey: row.crop_profile_key ?? null,
      lastObservedAt: activitySummary.get(row.id)?.last_observed_at ?? null,
      weeklyActivities: Number(activitySummary.get(row.id)?.weekly_activity_count ?? 0),
      batchCode: row.batch_code?.trim() || fallbackBatchCode(row.id),
      cropName: row.crop_name,
      assignedPlantingName: row.assigned_planting_name?.trim() || `Garden ${row.crop_name}`,
      customPlantingName: row.custom_planting_name?.trim() || null,
      plantingNameVersion: row.planting_name_version ?? 0,
      displayName: row.custom_planting_name?.trim() || row.assigned_planting_name?.trim() || `Garden ${row.crop_name}`,
      managerName: managerName(row),
      plantedBy: (() => {
        const plantingLog = row.planting_log_id ? plantingLogs.get(row.planting_log_id) : undefined;
        const operator = Array.isArray(plantingLog?.profiles) ? plantingLog.profiles[0] : plantingLog?.profiles;
        return operator?.full_name ?? "Not recorded";
      })(),
      plantingDate: row.planting_date,
      estimatedHarvest: row.estimated_harvest,
      growthStage,
      cropStatus,
      maintenanceNotes: row.maintenance_notes ?? "No notes recorded.",
      imagePath,
      imageUrl: row.image_path
        ? supabase.storage.from("crop-images").getPublicUrl(row.image_path).data.publicUrl
        : localStageImage ?? (imagePath
          ? supabase.storage.from("crop-images").getPublicUrl(imagePath).data.publicUrl
          : null),
      fieldLabel: plantingLog?.field_label ?? row.field_label ?? "Field not labeled",
      plantingTargetDrops: plantingLog?.target_drop_cycles ?? null,
      plantingCompletedDrops: plantingLog?.completed_drop_cycles ?? row.completed_drop_cycles ?? null,
      harvestWindowStart: row.harvest_window_start ?? null,
      harvestWindowEnd: row.harvest_window_end ?? null,
      expectedStage: displayGrowthStage(row.expected_stage ?? row.growth_stage, stages),
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
  const weather: CropWeatherStatus = liveWeather ?? {
    source: "Unavailable",
    currentCondition: "Weather unavailable",
    temperatureC: null,
    rainChancePercent: null,
    nextRainWindow: null,
    fetchedAt: null,
    needsRefresh: true,
  };

  const activeCropIds = new Set(
    crops
      .filter((crop) => !["Completed", "Harvested", "Cancelled"].includes(crop.cropStatus))
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
          crop.harvestWindowStart.slice(0, 10) <= nextTwoWeeksDate &&
          !["Completed", "Harvested", "Cancelled"].includes(crop.cropStatus)),
    ).length,
  };

  return {
    crops,
    summary,
    weather,
      error: relatedDataError ?? (taskResult.error ? "Care tasks could not be loaded: " + taskResult.error.message : null),
    recentHarvestMonths,
    harvestHistoryError: harvestPeriodError?.message ?? null,
  };
}
