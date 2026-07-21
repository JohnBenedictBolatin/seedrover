"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const STOCK_IMAGE_BUCKET = "stock-images";
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024;
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function optionalText(formData: FormData, key: string) {
  const value = text(formData, key);
  return value.length === 0 ? null : value;
}

function numberValue(formData: FormData, key: string, fallback = 0) {
  const value = Number(formData.get(key) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

function optionalNumber(formData: FormData, key: string) {
  const raw = text(formData, key);
  if (!raw) {
    return null;
  }

  const value = Number(raw);
  return Number.isFinite(value) ? value : null;
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
  activity: string,
  description: string,
  userId: string | null,
) {
  const supabase = await createSupabaseServerClient();
  if (!supabase || !userId) {
    return;
  }

  try {
    await supabase.from("activity_logs").insert({
      user_id: userId,
      activity,
      description,
      module: "Stocks",
    });
  } catch {
    // Activity logging should not block the inventory action itself.
  }
}

type StockSnapshot = {
  item_name: string;
  quantity: number;
  minimum_quantity: number;
  unit: string;
};

function stockStatus(snapshot: StockSnapshot | null) {
  if (!snapshot) {
    return "Unknown";
  }

  if (snapshot.quantity <= 0) {
    return "Out of Stock";
  }

  if (snapshot.minimum_quantity > 0 && snapshot.quantity <= snapshot.minimum_quantity * 0.5) {
    return "Critical Stock";
  }

  if (snapshot.minimum_quantity > 0 && snapshot.quantity <= snapshot.minimum_quantity) {
    return "Low Stock";
  }

  return "In Stock";
}

async function stockSnapshot(inventoryId: string) {
  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return null;
  }

  const { data } = await supabase
    .from("inventory")
    .select("item_name, quantity, minimum_quantity, unit")
    .eq("id", inventoryId)
    .single<StockSnapshot>();

  return data ?? null;
}

async function notifyIfStockNeedsReplenishment(
  inventoryId: string,
  userId: string | null,
  previous: StockSnapshot | null,
) {
  if (!userId) {
    return;
  }

  const current = await stockSnapshot(inventoryId);
  const previousStatus = stockStatus(previous);
  const currentStatus = stockStatus(current);
  const alertStatuses = new Set(["Low Stock", "Critical Stock", "Out of Stock"]);

  if (!current || !alertStatuses.has(currentStatus) || previousStatus === currentStatus) {
    return;
  }

  const minimumText =
    current.minimum_quantity > 0
      ? ` Minimum level is ${current.minimum_quantity} ${current.unit}.`
      : "";

  try {
    const supabase = await createSupabaseServerClient();
    await supabase?.from("notifications").insert({
      recipient_id: userId,
      title: `${currentStatus}: ${current.item_name}`,
      message: `${current.item_name} needs replenishment. Current stock is ${current.quantity} ${current.unit}.${minimumText}`,
      notification_type: "Inventory",
      action_route: "/inventory",
    });
  } catch {
    // Notifications should not block the stock action itself.
  }
}

async function nextStockCode() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const { data } = await supabase.from("inventory").select("stock_code");
  let max = 0;

  for (const row of data ?? []) {
    const match = /^STK-(\d+)$/.exec(String(row.stock_code ?? ""));
    const value = Number(match?.[1] ?? 0);
    if (value > max) {
      max = value;
    }
  }

  return `STK-${String(max + 1).padStart(3, "0")}`;
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
  const quantity = numberValue(formData, "quantity");
  const minimumQuantity = numberValue(formData, "minimum_quantity");
  const unitCost = optionalNumber(formData, "unit_cost");
  const sellingPrice = optionalNumber(formData, "selling_price");

  if (options?.includeQuantity && quantity < 0) {
    throw new Error("Current quantity cannot be negative.");
  }

  if (minimumQuantity < 0) {
    throw new Error("Minimum quantity cannot be negative.");
  }

  if (unitCost !== null && unitCost < 0) {
    throw new Error("Unit cost cannot be negative.");
  }

  if (sellingPrice !== null && sellingPrice < 0) {
    throw new Error("Selling price cannot be negative.");
  }

  return {
    item_name: text(formData, "item_name"),
    category: text(formData, "category", "Fruit Vegetables"),
    ...(options?.includeQuantity ? { quantity } : {}),
    unit: text(formData, "unit", "kg"),
    minimum_quantity: minimumQuantity,
    storage_location: text(formData, "storage_location", "Unassigned"),
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

  if (!payload.item_name) {
    throw new Error("Item name is required.");
  }

  const imagePath = await uploadImage(id, formData.get("image"));

  const { error } = await supabase
    .from("inventory")
    .insert({
      id,
      ...payload,
      stock_code: await nextStockCode(),
      ...(imagePath ? { image_path: imagePath } : {}),
      updated_by: userId,
    })
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  await logInventoryActivity(
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
    "Inventory item deleted",
    `${item?.item_name ?? "Inventory item"} was removed from the stock list.`,
    userId,
  );

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
}

export async function stockInAction(formData: FormData) {
  const quantity = numberValue(formData, "quantity");
  if (quantity <= 0) throw new Error("Stock in quantity must be greater than zero.");
  await createMovement(formData, "IN", quantity);
}

export async function stockOutAction(formData: FormData) {
  const quantity = numberValue(formData, "quantity");
  if (quantity <= 0) throw new Error("Stock out quantity must be greater than zero.");
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
  const combinedRemarks = reason ? `${reason} - ${remarks}` : remarks;
  const inventoryId = text(formData, "id");
  const previousStock = await stockSnapshot(inventoryId);

  if (!userId) {
    throw new Error("Sign in before changing inventory.");
  }

  const { error } = await supabase.from("inventory_transactions").insert({
    inventory_id: inventoryId,
    transaction_type: transactionType,
    quantity,
    remarks: combinedRemarks,
    performed_by: userId,
  });

  if (error) {
    throw new Error(error.message);
  }

  const { data: item } = await supabase
    .from("inventory")
    .select("item_name, unit")
    .eq("id", inventoryId)
    .single<{ item_name: string; unit: string }>();

  await logInventoryActivity(
    transactionType === "IN"
      ? "Stock in recorded"
      : transactionType === "OUT"
        ? "Stock out recorded"
        : "Stock quantity adjusted",
    `${item?.item_name ?? "Inventory item"} ${
      transactionType === "ADJUSTMENT" ? "was adjusted to" : "moved"
    } ${quantity} ${item?.unit ?? "unit"}. Reason: ${combinedRemarks}`,
    userId,
  );

  await notifyIfStockNeedsReplenishment(inventoryId, userId, previousStock);

  revalidatePath("/inventory");
  revalidatePath("/dashboard");
  revalidatePath("/notifications");
  revalidatePath("/", "layout");
}

export async function recordInventorySaleAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const payload = {
    p_inventory_id: text(formData, "id"),
    p_quantity_sold: numberValue(formData, "quantity"),
    p_unit_price: numberValue(formData, "unit_price"),
    p_sale_date: text(formData, "sale_date", new Date().toISOString()),
    p_customer_name: optionalText(formData, "customer_name"),
    p_remarks: optionalText(formData, "remarks"),
  };
  const paymentMethod = text(formData, "payment_method", "Cash");
  const transactionReference = optionalText(formData, "transaction_reference");
  const otherPaymentMethod = optionalText(formData, "other_payment_method");

  if (payload.p_quantity_sold <= 0) {
    throw new Error("Sale quantity must be greater than zero.");
  }

  if (payload.p_unit_price < 0) {
    throw new Error("Sale unit price cannot be negative.");
  }

  if (paymentMethod === "Other" && !otherPaymentMethod) {
    throw new Error("Enter the other payment method used.");
  }

  if (paymentMethod !== "Cash" && !transactionReference) {
    throw new Error("Transaction ID is required for non-cash market distribution sales.");
  }

  const { error } = await supabase.rpc("record_inventory_sale", {
    ...payload,
    p_payment_method: paymentMethod,
    p_transaction_reference: transactionReference,
    p_other_payment_method: otherPaymentMethod,
  });

  if (error) {
    const canRetryWithoutTransactionReference =
      error.message.includes("record_inventory_sale") &&
      (error.message.includes("p_transaction_reference") ||
        error.message.includes("p_other_payment_method"));
  
    if (canRetryWithoutTransactionReference && paymentMethod !== "Other") {
      const fallback = await supabase.rpc("record_inventory_sale", {
        ...payload,
        p_payment_method: paymentMethod,
      });

      if (!fallback.error) {
        revalidatePath("/inventory");
        revalidatePath("/sales");
        revalidatePath("/customers");
        revalidatePath("/dashboard");
        return;
      }

      throw new Error(fallback.error.message);
    }

    const canRetryWithoutPayment =
      error.message.includes("record_inventory_sale") &&
      error.message.includes("p_payment_method");

    if (canRetryWithoutPayment) {
      const fallback = await supabase.rpc("record_inventory_sale", payload);

      if (!fallback.error) {
        revalidatePath("/inventory");
        revalidatePath("/sales");
        revalidatePath("/customers");
        revalidatePath("/dashboard");
        return;
      }

      throw new Error(fallback.error.message);
    }

    throw new Error(error.message);
  }

  revalidatePath("/inventory");
  revalidatePath("/sales");
  revalidatePath("/customers");
  revalidatePath("/dashboard");
}
