"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { writeActivityLog } from "@/lib/activity-log";

const STOCK_IMAGE_BUCKET = "stock-images";
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function requiredText(formData: FormData, key: string, label: string) {
  const value = text(formData, key);
  if (!value) {
    throw new Error(`${label} is required.`);
  }
  return value;
}

function requiredNumber(formData: FormData, key: string, label: string) {
  const raw = text(formData, key);
  if (!raw) {
    throw new Error(`${label} is required.`);
  }

  const value = Number(raw);
  if (!Number.isFinite(value)) {
    throw new Error(`${label} must be a valid number.`);
  }
  return value;
}

function numberValue(formData: FormData, key: string, fallback = 0) {
  const raw = text(formData, key);
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${key.replaceAll("_", " ")} must be a valid number.`);
  return value;
}

function optionalNumber(formData: FormData, key: string) {
  const raw = text(formData, key);
  if (!raw) {
    return null;
  }

  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${key.replaceAll("_", " ")} must be a valid number.`);
  return value;
}

function validateQuantity(value: number, unit: string, label: string, allowZero = true) {
  if (!Number.isFinite(value) || value < 0 || (!allowZero && value === 0)) {
    throw new Error(`${label} must be a valid non-negative value.`);
  }
}

async function currentUserId() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return null;
  }

  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? null;
}

async function logInventoryActivity(
  supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>,
  activity: string,
  description: string,
  userId: string | null,
) {
  await writeActivityLog(supabase, { userId, activity, description, module: "Stocks" });
}

async function uploadImage(inventoryId: string, file: FormDataEntryValue | null) {
  if (!(file instanceof File) || file.size === 0) {
    return null;
  }

  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    throw new Error("Stock image must be 5MB or smaller.");
  }

  if (!ALLOWED_IMAGE_TYPES.has(file.type)) {
    throw new Error("Stock image must be a JPG, PNG, or WebP file.");
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const extension = file.name.toLowerCase().endsWith(".png")
    ? "png"
    : file.name.toLowerCase().endsWith(".webp")
      ? "webp"
      : "jpg";
  const safeName = file.name
    .replace(/\.[^.]+$/, "")
    .replace(/[^a-zA-Z0-9_.-]/g, "-")
    .toLowerCase();
  const path = `${inventoryId}/${Date.now()}-${safeName}.${extension}`;

  const { error } = await supabase.storage
    .from(STOCK_IMAGE_BUCKET)
    .upload(path, file, {
      contentType: file.type || `image/${extension}`,
      upsert: true,
    });

  if (error) {
    throw new Error(error.message);
  }

  return path;
}

function inventoryPayload(formData: FormData, options?: { includeQuantity?: boolean }) {
  const isCreate = options?.includeQuantity === true;
  const unit = (isCreate ? requiredText(formData, "unit", "Unit") : text(formData, "unit", "kg")).toLowerCase();
  if (unit !== "kg") {
    throw new Error("Inventory quantities must use kg as the unit.");
  }
  const quantity = isCreate
    ? requiredNumber(formData, "quantity", "Quantity")
    : numberValue(formData, "quantity");
  const minimumQuantity = isCreate
    ? requiredNumber(formData, "minimum_quantity", "Minimum stock level")
    : numberValue(formData, "minimum_quantity");
  const unitCost = isCreate
    ? requiredNumber(formData, "unit_cost", "Unit cost")
    : optionalNumber(formData, "unit_cost");
  const sellingPrice = isCreate
    ? requiredNumber(formData, "selling_price", "Selling price")
    : optionalNumber(formData, "selling_price");

  if (options?.includeQuantity) validateQuantity(quantity, unit, "Current quantity");
  validateQuantity(minimumQuantity, unit, "Minimum quantity");

  if (unitCost !== null && unitCost < 0) {
    throw new Error("Unit cost cannot be negative.");
  }

  if (sellingPrice !== null && sellingPrice < 0) {
    throw new Error("Selling price cannot be negative.");
  }

  return {
    item_name: isCreate
      ? requiredText(formData, "item_name", "Item name")
      : text(formData, "item_name"),
    category: isCreate
      ? requiredText(formData, "category", "Category")
      : text(formData, "category", "Fruit Vegetables"),
    ...(options?.includeQuantity ? { quantity } : {}),
    unit,
    minimum_quantity: minimumQuantity,
    storage_location: isCreate
      ? requiredText(formData, "storage_location", "Storage location")
      : text(formData, "storage_location", "Unassigned"),
    notes: text(formData, "notes").trim() || null,
    unit_cost: unitCost,
    selling_price: sellingPrice,
  };
}

export async function createInventoryItemAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const userId = await currentUserId();
  const payload = inventoryPayload(formData, { includeQuantity: true });
  const id = randomUUID();

  const { data: existingItems, error: duplicateLookupError } = await supabase
    .from("inventory")
    .select("id, item_name");

  if (duplicateLookupError) {
    throw new Error(duplicateLookupError.message);
  }

  const normalizedName = payload.item_name.toLocaleLowerCase();
  if (
    (existingItems ?? []).some(
      (item) => item.item_name.trim().toLocaleLowerCase() === normalizedName,
    )
  ) {
    throw new Error("An inventory item with this name already exists.");
  }

  const image = formData.get("image");
  if (!(image instanceof File) || image.size === 0) {
    throw new Error("Stock image is required.");
  }

  const imagePath = await uploadImage(id, image);

  const { error } = await supabase
    .from("inventory")
    .insert({
      id,
      ...payload,
      image_path: imagePath,
      updated_by: userId,
    })
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  await logInventoryActivity(
    supabase,
    "Inventory item created",
    `${payload.item_name} was added to the stock list with ${payload.quantity} ${payload.unit}.`,
    userId,
  );

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
}

export async function updateInventoryItemAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const id = text(formData, "id");
  const userId = await currentUserId();
  const imagePath = await uploadImage(id, formData.get("image"));

  const { error } = await supabase
    .from("inventory")
    .update({
      ...inventoryPayload(formData),
      ...(imagePath ? { image_path: imagePath } : {}),
      updated_by: userId,
    })
    .eq("id", id);

  if (error) {
    throw new Error(error.message);
  }

  await logInventoryActivity(
    supabase,
    "Inventory item updated",
    `${inventoryPayload(formData).item_name || "Inventory item"} profile was updated.`,
    userId,
  );

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
}

export async function deleteInventoryItemAction(formData: FormData) {
  await requireAdminRole(["System Administrator"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const id = text(formData, "id");
  const userId = await currentUserId();
  const { data: item } = await supabase
    .from("inventory")
    .select("item_name")
    .eq("id", id)
    .single<{ item_name: string }>();
  const { error } = await supabase.rpc("force_delete_inventory_item", {
    p_inventory_id: id,
  });

  if (error) {
    throw new Error(error.message);
  }

  await logInventoryActivity(
    supabase,
    "Inventory item deleted",
    `${item?.item_name ?? "Inventory item"} was removed from the stock list.`,
    userId,
  );

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
}

export async function stockInAction(formData: FormData) {
  const quantity = numberValue(formData, "quantity");
  if (quantity <= 0) throw new Error("Quantity must be greater than zero.");
  await createMovement(formData, "IN", quantity);
}

export async function stockOutAction(formData: FormData) {
  const quantity = numberValue(formData, "quantity");
  if (quantity <= 0) throw new Error("Quantity must be greater than zero.");
  await createMovement(formData, "OUT", quantity);
}

export async function adjustStockAction(formData: FormData) {
  const quantity = numberValue(formData, "new_quantity");
  if (quantity < 0) throw new Error("Adjusted quantity cannot be negative.");
  await createMovement(formData, "ADJUSTMENT", quantity);
}

async function createMovement(
  formData: FormData,
  transactionType: "IN" | "OUT" | "ADJUSTMENT",
  quantity: number,
) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const userId = await currentUserId();
  const reason = text(formData, "reason");
  const remarks = text(formData, "remarks", "Inventory updated.");
  const inventoryId = text(formData, "id");

  const { data: movementItem, error: movementItemError } = await supabase
    .from("inventory")
    .select("unit")
    .eq("id", inventoryId)
    .single<{ unit: string }>();
  if (movementItemError) throw new Error(movementItemError.message);
  if (movementItem?.unit !== "kg") {
    throw new Error("Inventory quantities must use kg as the unit. Update this item before stocking it.");
  }
  validateQuantity(quantity, movementItem?.unit ?? "kg", "Quantity", transactionType !== "ADJUSTMENT");

  if (!userId) {
    throw new Error("Sign in before changing inventory.");
  }

  const { error } = await supabase.rpc("record_inventory_movement", {
    p_inventory_id: inventoryId,
    p_transaction_type: transactionType,
    p_quantity: quantity,
    p_reason: reason || null,
    p_remarks: remarks || null,
  });

  if (error) {
    if (error.message.includes("record_inventory_movement") || error.message.includes("schema cache")) {
      throw new Error("Inventory movement support is not deployed yet. Apply the latest Supabase migration, then try again.");
    }
    throw new Error(error.message);
  }

  const { data: item } = await supabase
    .from("inventory")
    .select("item_name, unit")
    .eq("id", inventoryId)
    .single<{ item_name: string; unit: string }>();

  await logInventoryActivity(
    supabase,
    transactionType === "IN"
      ? "Receive stock recorded"
      : transactionType === "OUT"
        ? "Issue stock recorded"
        : "Stock quantity adjusted",
    `${item?.item_name ?? "Inventory item"} ${
      transactionType === "ADJUSTMENT" ? "was adjusted to" : "moved"
    } ${quantity} ${item?.unit ?? "unit"}. ${reason ? `${transactionType === "IN" ? "Source" : "Reason"}: ${reason}. ` : ""}${remarks}`,
    userId,
  );

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
  revalidatePath("/notifications");
  revalidatePath("/", "layout");
}
