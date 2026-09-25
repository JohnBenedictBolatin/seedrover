"use server";

import { revalidatePath } from "next/cache";
import type { CropActivityRecord, CropSensorReading } from "@/lib/crops";
import { INVENTORY_UNIT } from "@/lib/inventory";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireAdminRole } from "@/lib/auth";

const CROP_IMAGE_BUCKET = "crop-images";
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export type PlantingRunHistoryRow = {
  id: string;
  cropId: string | null;
  runId: string | null;
  seedName: string;
  fieldLabel: string | null;
  plantingStatus: string;
  confirmationOutcome: string;
  targetCycles: number | null;
  completedCycles: number;
  operatorName: string;
  startedAt: string | null;
  completedAt: string | null;
  confirmedAt: string | null;
  soilCapturedAt: string | null;
  soilRaw: number | null;
  soilMoisturePercent: number | null;
  soilTemperatureC: number | null;
  airTemperatureC: number | null;
  humidityPercent: number | null;
  provenanceStatus: "verified_hardware" | "unverified";
  soilMoistureCalibrated: boolean | null;
  calibrationVersion: string | null;
  failureCode: string | null;
};

export async function getPlantingRunsAction(page = 1) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { rows: [] as PlantingRunHistoryRow[], total: 0, error: "Supabase is not configured." };
  const pageSize = 5;
  const safePage = Math.max(1, Math.floor(page));
  const { data, count, error } = await supabase
    .from("planting_logs")
    .select("id, crop_id, client_session_id, crop_name, field_label, planting_status, confirmation_outcome, target_drop_cycles, completed_drop_cycles, operator:profiles!planting_logs_operator_id_fkey(full_name), started_at, completed_at, confirmed_at, soil_captured_at, soil_raw, soil_moisture_percent, soil_temperature_c, air_temperature_c, humidity_percent, firmware_version, sync_payload, failure_code", { count: "exact" })
    .order("started_at", { ascending: false, nullsFirst: false })
    .range((safePage - 1) * pageSize, safePage * pageSize - 1);
  if (error) return { rows: [] as PlantingRunHistoryRow[], total: 0, error: error.message };
  const rows = (data ?? []).map((row) => {
    const operator = Array.isArray(row.operator) ? row.operator[0] : row.operator;
    return {
      id: row.id,
      cropId: row.crop_id,
      runId: row.client_session_id,
      seedName: row.crop_name,
      fieldLabel: row.field_label,
      plantingStatus: row.planting_status,
      confirmationOutcome: row.confirmation_outcome,
      targetCycles: row.target_drop_cycles,
      completedCycles: row.completed_drop_cycles,
      operatorName: operator?.full_name ?? "Former user",
      startedAt: row.started_at,
      completedAt: row.completed_at,
      confirmedAt: row.confirmed_at,
      soilCapturedAt: row.soil_captured_at,
      soilRaw: boundedSensorValue(row.soil_raw, 1, 4094),
      soilMoisturePercent: row.sync_payload?.status?.soil_moisture_calibrated === true && typeof row.sync_payload?.status?.calibration_version === "string" && row.sync_payload.status.calibration_version.trim() ? boundedSensorValue(row.soil_moisture_percent, 0, 100) : null,
      soilTemperatureC: boundedSensorValue(row.soil_temperature_c, -55, 125),
      airTemperatureC: boundedSensorValue(row.air_temperature_c, -40, 80),
      humidityPercent: boundedSensorValue(row.humidity_percent, 0, 100),
      provenanceStatus: row.firmware_version ? "verified_hardware" : "unverified",
      soilMoistureCalibrated: row.sync_payload?.status?.soil_moisture_calibrated === false ? false : row.sync_payload?.status?.soil_moisture_calibrated === true && typeof row.sync_payload?.status?.calibration_version === "string" && Boolean(row.sync_payload.status.calibration_version.trim()) ? true : null,
      calibrationVersion: row.sync_payload?.status?.calibration_version ?? null,
      failureCode: row.failure_code,
    } satisfies PlantingRunHistoryRow;
  });
  return { rows, total: count ?? 0, error: null };
}

type CropSensorReadingRow = {
  id: string;
  soil_raw: number | null;
  soil_moisture: number | null;
  calibrated_value: number | null;
  soil_temperature: number | null;
  environmental_temperature: number | null;
  humidity: number | null;
  source: string;
  recorded_at: string;
  provenance_status: CropSensorReading["provenanceStatus"] | null;
  soil_moisture_calibrated: boolean | null;
  calibration_version: string | null;
};

function boundedSensorValue(value: number | null, minimum: number, maximum: number) {
  return value !== null && Number.isFinite(value) && value >= minimum && value <= maximum ? value : null;
}

type CropActivityRow = {
  id: string;
  activity_type: string;
  performed_at: string;
  quantity: number | null;
  unit: string | null;
  material: string | null;
  notes: string | null;
  observed_stage: string | null;
  source: string;
  performer: { full_name: string } | { full_name: string }[] | null;
};

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function numberValue(formData: FormData, key: string, fallback = 0) {
  const value = Number(formData.get(key) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

async function logCropActivity(
  userIdValue: string,
  activity: string,
  description: string,
) {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return;

  try {
    await supabase.from("activity_logs").insert({
      user_id: userIdValue,
      activity,
      description,
      module: "Crops",
    });
  } catch {
    // Activity logging should not block the crop action itself.
  }
}

async function uploadCropImage(cropId: string, file: FormDataEntryValue | null) {
  if (!(file instanceof File) || file.size === 0) {
    return null;
  }

  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    throw new Error("Crop image must be 5MB or smaller.");
  }

  if (!ALLOWED_IMAGE_TYPES.has(file.type)) {
    throw new Error("Crop image must be a JPG, PNG, or WebP file.");
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const extension = file.name.toLowerCase().endsWith(".png")
    ? "png"
    : file.name.toLowerCase().endsWith(".webp")
      ? "webp"
      : "jpg";
  const safeName = file.name
    .replace(/\.[^.]+$/, "")
    .replace(/[^a-zA-Z0-9_.-]/g, "-")
    .toLowerCase();
  const path = `${cropId}/${Date.now()}-${safeName}.${extension}`;

  const { error } = await supabase.storage
    .from(CROP_IMAGE_BUCKET)
    .upload(path, file, {
      contentType: file.type || `image/${extension}`,
      upsert: true,
    });

  if (error) throw new Error(error.message);

  return path;
}

export async function updateCropAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const id = text(formData, "id");
  const cropName = text(formData, "crop_name");
  const plantingDate = text(formData, "planting_date");
  const estimatedHarvest = text(formData, "estimated_harvest");

  if (!id || !cropName || !plantingDate) {
    throw new Error("Crop name and planting date are required.");
  }

  if (estimatedHarvest && estimatedHarvest < plantingDate) {
    throw new Error("Estimated harvest cannot be before the planting date.");
  }

  const imagePath = await uploadCropImage(id, formData.get("image"));
  const submittedStatus = text(formData, "crop_status", "Active");
  const cropStatus = submittedStatus;
  const { error } = await supabase.from("crops").update({
    crop_name: cropName,
    planting_date: plantingDate,
    estimated_harvest: estimatedHarvest || null,
    growth_stage: text(formData, "growth_stage"),
    crop_status: cropStatus,
    maintenance_notes: text(formData, "maintenance_notes") || null,
    ...(imagePath ? { image_path: imagePath } : {}),
    updated_at: new Date().toISOString(),
  }).eq("id", id);
  if (error) throw new Error(error.message);
  await logCropActivity(
    profile.id,
    "Crop record updated",
    `${profile.fullName} updated the crop record for ${cropName}.`,
  );
  revalidatePath("/crops");
}

export async function cropMaintenanceAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const submissionId = text(formData, "submission_id");
  if (!/^[a-zA-Z0-9-]{16,100}$/.test(submissionId)) throw new Error("A valid submission ID is required.");
  const cropId = text(formData, "id");
  const activity = text(formData, "activity");
  const material = text(formData, "material").trim();
  if (activity === "Inspected" && !["Looks normal", "Issue noticed"].includes(material)) throw new Error("Choose whether the crop looks normal or has an issue.");
  if (activity === "Transplanted" && !material) throw new Error("Enter where the crop was transplanted.");
  const photoFiles = formData.getAll("photos").filter((file): file is File => file instanceof File && file.size > 0);
  if (photoFiles.length && activity !== "Stage Observed") throw new Error("Growth photos can only be attached to an observed growth stage.");
  const photos: string[] = [];
  for (const [index, file] of photoFiles.entries()) {
    if (file.size > MAX_IMAGE_SIZE_BYTES || !ALLOWED_IMAGE_TYPES.has(file.type)) throw new Error("Photos must be JPG, PNG or WebP, up to 5 MB each.");
    const path = `${profile.id}/${cropId}/${submissionId}-${index}.${file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg"}`;
    const { error } = await supabase.storage.from("crop-journal").upload(path, file, { contentType: file.type });
    if (error && !/already exists|duplicate/i.test(error.message)) throw new Error(error.message);
    photos.push(path);
  }
  const performedAt = text(formData, "performed_at");
  const { data, error } = await supabase.rpc("record_crop_entry", { p_entry: {
    crop_id: cropId, activity_type: activity, performed_at: performedAt,
    quantity: text(formData, "quantity") ? numberValue(formData, "quantity") : null,
    unit: activity === "Harvested" ? "kg" : text(formData, "unit") || null,
    material: material || null, notes: text(formData, "notes") || null,
    observed_stage: text(formData, "observed_stage") || null,
    task_id: text(formData, "task_id") || null, submission_id: submissionId, photos,
  } });
  if (error) throw new Error(error.message);
  for (const path of ["/crops", "/dashboard", "/inventory", "/crop-outcomes"]) revalidatePath(path);
  return { activityId: String(data) };
}

export async function getHarvestDestinationAction(cropId: string) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { data, error } = await supabase.rpc("crop_harvest_destination", { p_crop_id: cropId });
  if (error) throw new Error(error.message);
  return data as { id: string; name: string; unit: string };
}

export async function getCropManagersAction() {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { data, error } = await supabase.from("profiles").select("id, full_name, roles!inner(role_name)").eq("is_active", true).in("roles.role_name", ["System Administrator", "Farm Planting Manager", "Planting Staff"]);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({ id: row.id, name: row.full_name }));
}

export async function assignCropManagerAction(cropId: string, managerId: string) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const managers = await getCropManagersAction();
  if (!managers.some((manager) => manager.id === managerId)) throw new Error("Choose an active planting manager or worker.");
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { error } = await supabase.from("crops").update({ assigned_manager: managerId }).eq("id", cropId).in("crop_status", ["Active", "Needs Attention", "Harvest Ready"]);
  if (error) throw new Error(error.message);
  revalidatePath("/crops");
}

export async function cropDigestPreferencesAction(values?: { digest_enabled: boolean; digest_hour: number; quiet_start: number; quiet_end: number }) {
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  if (values) {
    const { error } = await supabase.from("crop_notification_preferences").upsert({ user_id: profile.id, ...values });
    if (error) throw new Error(error.message);
  }
  const { data, error } = await supabase.from("crop_notification_preferences").select("digest_enabled, digest_hour, quiet_start, quiet_end").eq("user_id", profile.id).maybeSingle();
  if (error) throw new Error(error.message);
  return data ?? { digest_enabled: true, digest_hour: 6, quiet_start: 21, quiet_end: 6 };
}

export async function refreshCropWeatherAction() {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const { error } = await supabase.functions.invoke("crop-monitor", { body: { weatherOnly: true } });
  if (error) throw new Error(error.message);

  revalidatePath("/crops");
}

export async function getCropSensorHistoryAction(cropId: string) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  if (!cropId.trim()) {
    throw new Error("Crop record is required.");
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const { data, error } = await supabase
    .from("sensor_readings")
    .select(
      "id, soil_raw, soil_moisture, calibrated_value, soil_temperature, environmental_temperature, humidity, source, recorded_at, provenance_status, soil_moisture_calibrated, calibration_version",
    )
    .eq("crop_id", cropId)
    .order("recorded_at", { ascending: false })
    .limit(100)
    .returns<CropSensorReadingRow[]>();

  if (error) {
    if (
      error.message.includes("crop_id") ||
      error.message.includes("schema cache")
    ) {
      throw new Error("Crop-linked sensor history requires the latest Supabase migration.");
    }
    throw new Error(error.message);
  }

  return (data ?? []).map<CropSensorReading>((reading) => ({
    id: reading.id,
    soilRaw: boundedSensorValue(reading.soil_raw, 1, 4094),
    soilMoisture: reading.soil_moisture_calibrated && reading.calibration_version ? boundedSensorValue(reading.calibrated_value ?? reading.soil_moisture, 0, 100) : null,
    soilTemperature: boundedSensorValue(reading.soil_temperature, -55, 125),
    environmentalTemperature: boundedSensorValue(reading.environmental_temperature, -40, 80),
    humidity: boundedSensorValue(reading.humidity, 0, 100),
    source: reading.source,
    recordedAt: reading.recorded_at,
    provenanceStatus: reading.provenance_status ?? "unverified",
    soilMoistureCalibrated: reading.soil_moisture_calibrated === false ? false : reading.soil_moisture_calibrated === true && Boolean(reading.calibration_version) ? true : null,
    calibrationVersion: reading.calibration_version,
    fresh: Date.now() - new Date(reading.recorded_at).getTime() >= 0 && Date.now() - new Date(reading.recorded_at).getTime() <= 60_000,
  }));
}

export async function getCropActivityHistoryAction(cropId: string) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  if (!cropId.trim()) {
    throw new Error("Crop record is required.");
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const { data, error } = await supabase
    .from("crop_activities")
    .select(
      "id, activity_type, performed_at, quantity, unit, material, notes, observed_stage, source, performer:profiles!crop_activities_performed_by_fkey(full_name)",
    )
    .eq("crop_id", cropId)
    .order("performed_at", { ascending: false })
    .returns<CropActivityRow[]>();

  if (error) {
    if (error.message.includes("crop_activities") || error.message.includes("schema cache")) {
      throw new Error("Crop activity history requires the latest Supabase migration.");
    }
    throw new Error(error.message);
  }

  return Promise.all((data ?? []).map(async (activity): Promise<CropActivityRecord> => {
    const { data: attachments, error: photoError } = await supabase.from("crop_activity_photos").select("path").eq("activity_id", activity.id);
    const missingPhotoTable = photoError?.message.includes("crop_activity_photos") === true;
    if (photoError && !missingPhotoTable) throw new Error(photoError.message);
    const photos = await Promise.all((attachments ?? []).map(async ({ path }) => {
      const { data: signed, error } = await supabase.storage.from("crop-journal").createSignedUrl(path, 3600);
      if (error) throw new Error(error.message);
      return { path, url: signed.signedUrl };
    }));
    const performer = Array.isArray(activity.performer) ? activity.performer[0] : activity.performer;
    return {
      id: activity.id,
      photos,
      activityType: activity.activity_type,
      performedAt: activity.performed_at,
      performedBy: performer?.full_name ?? (activity.source === "Rover" ? "SeedRover" : "Unknown user"),
      quantity: activity.quantity === null ? null : Number(activity.quantity),
      unit: activity.activity_type === "Harvested" ? INVENTORY_UNIT : activity.unit,
      material: activity.material,
      notes: activity.notes,
      observedStage: activity.observed_stage,
      source: activity.source,
    };
  }));
}

export async function deleteCropAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const id = text(formData, "id");
  const { data: crop } = await supabase
    .from("crops")
    .select("crop_name")
    .eq("id", id)
    .single<{ crop_name: string }>();
  const { error } = await supabase.from("crops").delete().eq("id", id);
  if (error) throw new Error(error.message);
  await logCropActivity(
    profile.id,
    "Crop record deleted",
    `${profile.fullName} deleted ${crop?.crop_name ?? "a crop record"}.`,
  );
  revalidatePath("/crops");
}
