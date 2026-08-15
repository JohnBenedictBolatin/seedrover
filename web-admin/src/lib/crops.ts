import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropItem = {
  id: string;
  cropName: string;
  managerName: string;
  variety: string;
  location: string;
  progress: number;
  plantingDate: string;
  estimatedHarvest: string | null;
  growthStage: string;
  cropStatus: string;
  maintenanceNotes: string;
  imagePath: string | null;
  imageUrl: string | null;
  updatedAt: string;
  plantingSource: string;
  fieldLabel: string;
  fieldAreaM2: number | null;
  completedDrops: number;
  estimatedSeedMin: number | null;
  estimatedSeedMax: number | null;
  harvestWindowStart: string | null;
  harvestWindowEnd: string | null;
  forecastConfidence: string;
  expectedStage: string;
  careStatus: string;
  propagationMethod: string;
  latestSoilPercent: number | null;
  latestSoilAt: string | null;
};

export type CropSummary = {
  totalCrops: number;
  activeCrops: number;
  needsAttention: number;
  harvestReady: number;
  completedCrops: number;
  wateringDue: number;
  careTasksDue: number;
  upcomingHarvests: number;
};

export type CropWeatherStatus = {
  currentCondition: string;
  temperatureC: number | null;
  humidityPercent: number | null;
  rainChancePercent: number | null;
  nextRainWindow: string | null;
  fetchedAt: string | null;
  needsRefresh: boolean;
};

export type HarvestInventoryOption = {
  id: string;
  itemName: string;
  category: string;
  unit: string;
};

type CropRow = {
  id: string;
  crop_name: string;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  image_path: string | null;
  crop_status: string;
  updated_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
  planting_source?: string | null;
  field_label?: string | null;
  field_area_m2?: number | null;
  completed_drop_cycles?: number | null;
  estimated_seed_count_min?: number | null;
  estimated_seed_count_max?: number | null;
  harvest_window_start?: string | null;
  harvest_window_end?: string | null;
  forecast_confidence?: string | null;
  expected_stage?: string | null;
  current_care_status?: string | null;
  propagation_method?: string | null;
};

type SensorRow = { crop_id: string; calibrated_value: number | null; soil_moisture: number; recorded_at: string };
type TaskRow = { crop_id: string; task_type: string; due_at: string; status: string };
type WeatherRow = { provider: string; precipitation_probability: number | null; temperature_c: number | null; humidity_percent: number | null; condition: string | null; raw_payload: Record<string, unknown> | null; fetched_at: string };

type HarvestInventoryRow = {
  id: string;
  item_name: string;
  category: string;
  unit: string;
};

function managerName(row: CropRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "Unassigned";
}

function progressFor(stage: string, status: string) {
  if (status === "Completed") return 1;
  return ({ Seeded: 0.12, Germinating: 0.24, Vegetative: 0.46, Flowering: 0.66, "Harvest Ready": 0.94 } as Record<string, number>)[stage] ?? 0.12;
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
      "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, harvest_window_end, forecast_confidence, expected_stage, current_care_status, propagation_method, profiles(full_name)",
    )
    .order("planting_date", { ascending: false })
    .returns<CropRow[]>();

  // Keep legacy crop records visible while the crop-monitoring migration is
  // being deployed. New monitoring fields use conservative display defaults.
  if (error && isMissingCropMonitoringSchema(error)) {
    const legacyResult = await supabase
      .from("crops")
      .select(
        "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, updated_at, profiles(full_name)",
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
      : supabase.from("crop_tasks").select("crop_id, task_type, due_at, status").in("crop_id", cropIds).in("status", ["Upcoming", "Due", "Overdue", "Postponed"]).returns<TaskRow[]>(),
    supabase.from("weather_forecasts").select("provider, precipitation_probability, temperature_c, humidity_percent, condition, raw_payload, fetched_at").order("fetched_at", { ascending: false }).limit(2).returns<WeatherRow[]>(),
  ]);
  const latestSensor = new Map<string, SensorRow>();
  for (const sensor of sensorData ?? []) if (!latestSensor.has(sensor.crop_id)) latestSensor.set(sensor.crop_id, sensor);

  const crops: CropItem[] = (data ?? []).map((row) => {
    const sensor = latestSensor.get(row.id);
    return ({
    id: row.id,
    cropName: row.crop_name,
    managerName: managerName(row),
    variety: "Farm Crop",
    location: "SeedRover field record",
    progress: progressFor(row.growth_stage, row.crop_status),
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
    updatedAt: row.updated_at,
    plantingSource: row.planting_source ?? "Legacy",
    fieldLabel: row.field_label ?? "Field not labeled",
    fieldAreaM2: row.field_area_m2 ?? null,
    completedDrops: row.completed_drop_cycles ?? 0,
    estimatedSeedMin: row.estimated_seed_count_min ?? null,
    estimatedSeedMax: row.estimated_seed_count_max ?? null,
    harvestWindowStart: row.harvest_window_start ?? null,
    harvestWindowEnd: row.harvest_window_end ?? null,
    forecastConfidence: row.forecast_confidence ?? "Low",
    expectedStage: row.expected_stage ?? row.growth_stage,
    careStatus: row.current_care_status ?? "Review crop condition",
    propagationMethod: row.propagation_method ?? "Unknown",
    latestSoilPercent: sensor?.calibrated_value ?? sensor?.soil_moisture ?? null,
    latestSoilAt: sensor?.recorded_at ?? null,
  }); });

  const pendingTasks = taskData ?? [];
  const now = new Date();
  const soon = new Date(now.getTime() + 14 * 86400000);
  const openMeteo = (weatherData ?? []).find((row) => row.provider === "Open-Meteo");
  const rawSummary = openMeteo?.raw_payload?.summary as Record<string, unknown> | undefined;
  const nextRainAt = typeof rawSummary?.nextRainAt === "string" ? rawSummary.nextRainAt : null;
  const weather: CropWeatherStatus = {
    currentCondition: openMeteo?.condition ?? "Weather unavailable",
    temperatureC: openMeteo?.temperature_c ?? null,
    humidityPercent: openMeteo?.humidity_percent ?? null,
    rainChancePercent: openMeteo?.precipitation_probability ?? null,
    nextRainWindow: nextRainAt,
    fetchedAt: openMeteo?.fetched_at ?? null,
    needsRefresh: typeof rawSummary?.currentCondition !== "string",
  };

  const summary: CropSummary = {
    totalCrops: crops.length,
    activeCrops: crops.filter((crop) => crop.cropStatus === "Active").length,
    needsAttention: crops.filter((crop) => crop.cropStatus === "Needs Attention")
      .length,
    harvestReady: crops.filter((crop) => crop.cropStatus === "Harvest Ready")
      .length,
    completedCrops: crops.filter((crop) => crop.cropStatus === "Completed").length,
    wateringDue: pendingTasks.filter((task) => task.task_type === "Water").length,
    careTasksDue: pendingTasks.length,
    upcomingHarvests: crops.filter((crop) => crop.harvestWindowStart && new Date(crop.harvestWindowStart) <= soon && crop.cropStatus === "Active").length,
  };

  return {
    crops,
    summary,
    weather,
    error: null,
  };
}

export async function getHarvestInventoryOptions() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  const { data } = await supabase
    .from("inventory")
    .select("id, item_name, category, unit")
    .order("item_name", { ascending: true })
    .returns<HarvestInventoryRow[]>();

  return (data ?? []).map<HarvestInventoryOption>((row) => ({
    id: row.id,
    itemName: row.item_name,
    category: row.category,
    unit: row.unit,
  }));
}
