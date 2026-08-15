"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const CROP_IMAGE_BUCKET = "crop-images";
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function numberValue(formData: FormData, key: string, fallback = 0) {
  const value = Number(formData.get(key) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

function localDateInputValue() {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function userId() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return null;
  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? null;
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

async function ensureCropOutcome({ cropId, cropName, outcome, quantity, reason, recordedBy }: { cropId: string; cropName: string; outcome: "Failed" | "Harvested"; quantity?: number | null; reason: string; recordedBy: string }) {
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { data: existing, error: readError } = await supabase.from("crop_outcomes").select("id").eq("crop_id", cropId).limit(1).maybeSingle<{ id: string }>();
  if (readError) throw new Error(readError.message);
  if (existing) {
    const { error } = await supabase.from("crop_outcomes").update({ crop_name: cropName, outcome, quantity: quantity ?? null, reason, recorded_by: recordedBy }).eq("id", existing.id);
    if (error) throw new Error(error.message);
    return;
  }
  const { error } = await supabase.from("crop_outcomes").insert({ crop_id: cropId, crop_name: cropName, outcome, quantity: quantity ?? null, reason, recorded_by: recordedBy });
  if (error) throw new Error(error.message);
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

export async function createCropAction(formData: FormData) {
  const profile = await requireAdminRole(["Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const name = text(formData, "crop_name");
  if (!name) throw new Error("Crop name is required.");
  const manualReason = text(formData, "manual_creation_reason");
  if (!manualReason) throw new Error("Explain why this crop was added without a rover planting receipt.");
  const plantingDate = text(formData, "planting_date", localDateInputValue());
  const estimatedHarvest = text(formData, "estimated_harvest");

  if (estimatedHarvest && estimatedHarvest < plantingDate) {
    throw new Error("Estimated harvest cannot be before the planting date.");
  }

  const id = randomUUID();
  const imagePath = await uploadCropImage(id, formData.get("image"));

  const { error } = await supabase.from("crops").insert({
    id,
    crop_name: name,
    assigned_manager: await userId(),
    planting_date: plantingDate,
    estimated_harvest: estimatedHarvest || null,
    growth_stage: text(formData, "growth_stage", "Seeded"),
    crop_status: "Active",
    planting_source: "Manual",
    manual_creation_reason: manualReason,
    field_label: text(formData, "field_label") || null,
    field_area_m2: numberValue(formData, "field_area_m2") || null,
    propagation_method: text(formData, "propagation_method", "Direct seed"),
    crop_profile_key: text(formData, "crop_profile_key") || null,
    maintenance_notes: text(formData, "maintenance_notes") || null,
    ...(imagePath ? { image_path: imagePath } : {}),
  }).select("id").single();
  if (error) throw new Error(error.message);
  await logCropActivity(
    profile.id,
    "Crop record created",
    `${profile.fullName} created the crop record for ${name}.`,
  );
  revalidatePath("/crops");
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
  const cropStatus = submittedStatus === "Not Harvested" ? "Cancelled" : submittedStatus;
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
  if (cropStatus === "Cancelled") {
    await ensureCropOutcome({ cropId: id, cropName, outcome: "Failed", reason: text(formData, "maintenance_notes") || "Marked as not harvested.", recordedBy: profile.id });
  }
  await logCropActivity(
    profile.id,
    "Crop record updated",
    `${profile.fullName} updated the crop record for ${cropName}.`,
  );
  revalidatePath("/crops");
}

export async function cropMaintenanceAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const id = text(formData, "id");
  const activity = text(formData, "activity");
  const supportedActivities = new Set(["Watered", "Fertilized", "Inspected", "Transplanted"]);
  if (!supportedActivities.has(activity)) {
    throw new Error("Choose a valid crop activity.");
  }
  const note = text(formData, "notes", `${activity} recorded.`);
  const quantity = numberValue(formData, "quantity", 0);
  if (quantity < 0) throw new Error("Activity quantity cannot be negative.");
  const { error } = await supabase.rpc("record_crop_activity", {
    p_crop_id: id,
    p_activity_type: activity,
    p_performed_at: new Date().toISOString(),
    p_quantity: quantity || null,
    p_unit: text(formData, "unit") || null,
    p_material: text(formData, "material") || null,
    p_notes: note,
    p_observed_stage: text(formData, "observed_stage") || null,
    p_task_id: text(formData, "task_id") || null,
    p_idempotency_key: `web:${randomUUID()}`,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/crops");
}

export async function refreshCropWeatherAction() {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const { error } = await supabase.functions.invoke("crop-monitor", { body: {} });
  if (error) throw new Error(error.message);

  revalidatePath("/crops");
}

export async function markCropNotHarvestedAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const cropId = text(formData, "id");
  const reason = text(formData, "reason", "Marked as not harvested.");
  if (!cropId) throw new Error("Crop record is required.");

  const { data: crop, error: readError } = await supabase.from("crops").select("crop_name, maintenance_notes, crop_status").eq("id", cropId).single<{ crop_name: string; maintenance_notes: string | null; crop_status: string }>();
  if (readError) throw new Error(readError.message);
  if (crop.crop_status === "Completed") throw new Error("A harvested crop cannot be marked as not harvested.");

  const { error } = await supabase.from("crops").update({
    crop_status: "Cancelled",
    growth_stage: "Completed",
    maintenance_notes: [crop.maintenance_notes, `Not harvested: ${reason}`].filter(Boolean).join("\n"),
    updated_at: new Date().toISOString(),
  }).eq("id", cropId);
  if (error) throw new Error(error.message);

  await ensureCropOutcome({ cropId, cropName: crop.crop_name, outcome: "Failed", reason, recordedBy: profile.id });
  await logCropActivity(profile.id, "Crop marked not harvested", `${profile.fullName} marked ${crop.crop_name} as not harvested. Reason: ${reason}`);
  revalidatePath("/crops");
  revalidatePath("/dashboard");
}

export async function harvestCropToInventoryAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const cropId = text(formData, "crop_id");
  const inventoryId = text(formData, "inventory_id");
  const quantity = numberValue(formData, "quantity");
  const harvestDate = text(formData, "harvest_date", localDateInputValue());
  const remarks = text(formData, "remarks", "Harvest recorded.");

  if (!cropId || !inventoryId) {
    throw new Error("Choose the crop and inventory item for this harvest.");
  }

  if (quantity <= 0) {
    throw new Error("Harvest quantity must be greater than zero.");
  }

  if (harvestDate > localDateInputValue()) {
    throw new Error("Harvest date cannot be in the future.");
  }

  const { error } = await supabase.rpc("harvest_crop_to_inventory", {
    p_crop_id: cropId,
    p_inventory_id: inventoryId,
    p_quantity: quantity,
    p_harvest_date: harvestDate,
    p_remarks: remarks,
  });

  if (error) {
    if (
      error.message.includes("schema cache") ||
      error.message.includes("harvest_crop_to_inventory") ||
      error.message.includes("Could not find the function")
    ) {
      throw new Error("Crop harvest database is not fully upgraded yet. Apply the latest Supabase migration and try again.");
    }

    throw new Error(error.message);
  }

  const { data: harvestedCrop, error: cropReadError } = await supabase.from("crops").select("crop_name").eq("id", cropId).single<{ crop_name: string }>();
  if (cropReadError) throw new Error(cropReadError.message);
  await ensureCropOutcome({ cropId, cropName: harvestedCrop.crop_name, outcome: "Harvested", quantity, reason: remarks, recordedBy: profile.id });

  revalidatePath("/crops");
  revalidatePath("/inventory");
  revalidatePath("/dashboard");
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
