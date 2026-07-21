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
  const profile = await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const name = text(formData, "crop_name");
  if (!name) throw new Error("Crop name is required.");
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
  const { error } = await supabase.from("crops").update({
    crop_name: cropName,
    planting_date: plantingDate,
    estimated_harvest: estimatedHarvest || null,
    growth_stage: text(formData, "growth_stage"),
    crop_status: text(formData, "crop_status", "Active"),
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
  const id = text(formData, "id");
  const activity = text(formData, "activity");
  const note = text(formData, "notes", `${activity} recorded.`);
  const { data: crop, error: readError } = await supabase.from("crops").select("maintenance_notes").eq("id", id).single();
  if (readError) throw new Error(readError.message);
  const nextStatus = activity === "Harvested" ? "Completed" : activity === "Watered" || activity === "Fertilized" ? "Active" : undefined;
  const { error } = await supabase.from("crops").update({
    maintenance_notes: [crop.maintenance_notes, `${activity}: ${note}`].filter(Boolean).join("\n"),
    ...(nextStatus ? { crop_status: nextStatus } : {}),
    updated_at: new Date().toISOString(),
  }).eq("id", id);
  if (error) throw new Error(error.message);
  await logCropActivity(
    profile.id,
    "Crop activity recorded",
    `${profile.fullName} recorded ${activity} for a crop. Note: ${note}`,
  );
  revalidatePath("/crops");
}

export async function harvestCropToInventoryAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Planting Manager"]);

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
