"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const receiptTypes = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);
const paymentMethods = new Set(["Cash", "GCash", "Bank Transfer", "Card", "Other"]);

function text(formData: FormData, key: string) { return String(formData.get(key) ?? "").trim(); }
function optionalNumber(formData: FormData, key: string) {
  const raw = text(formData, key);
  if (!raw) return null;
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0) throw new Error(`${key.replaceAll("_", " ")} must be a non-negative number.`);
  return value;
}

export async function createExpenseAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const id = randomUUID();
  const description = text(formData, "description");
  const amount = optionalNumber(formData, "amount");
  const quantity = optionalNumber(formData, "quantity");
  const unitCost = optionalNumber(formData, "unit_cost");
  const paymentMethod = text(formData, "payment_method") || "Cash";
  const expenseType = text(formData, "expense_type") || "One-time investment";
  const frequency = text(formData, "frequency");
  const nextDueDate = text(formData, "next_due_date");
  const endDate = text(formData, "end_date");

  if (!description || amount === null || amount <= 0) throw new Error("Description and a positive amount are required.");
  if (!paymentMethods.has(paymentMethod)) throw new Error("Choose a valid payment method.");
  if (quantity !== null && quantity <= 0) throw new Error("Quantity must be greater than zero.");
  if (expenseType === "Recurring expense" && (!frequency || !nextDueDate)) throw new Error("Frequency and next due date are required for recurring expenses.");
  if (endDate && nextDueDate && endDate < nextDueDate) throw new Error("End date cannot be before the next due date.");

  let receiptPath: string | null = null;
  const receipt = formData.get("receipt");
  if (receipt instanceof File && receipt.size > 0) {
    if (receipt.size > 5 * 1024 * 1024) throw new Error("Receipt must be 5MB or smaller.");
    if (!receiptTypes.has(receipt.type)) throw new Error("Receipt must be a JPG, PNG, WebP, or PDF file.");
    const extension = receipt.name.split(".").pop()?.toLowerCase() || "bin";
    receiptPath = `${id}/${Date.now()}-receipt.${extension}`;
    const { error: uploadError } = await supabase.storage.from("expense-receipts").upload(receiptPath, receipt, { contentType: receipt.type });
    if (uploadError) throw new Error(uploadError.message);
  }

  const { error } = await supabase.from("farm_expenses").insert({
    id,
    description,
    category: text(formData, "category") || "Other",
    amount,
    expense_date: text(formData, "expense_date") || new Date().toISOString().slice(0, 10),
    vendor: text(formData, "vendor") || null,
    payment_method: paymentMethod,
    reference_number: text(formData, "reference_number") || null,
    expense_type: expenseType,
    related_crop_id: text(formData, "related_crop_id") || null,
    related_inventory_id: text(formData, "related_inventory_id") || null,
    quantity,
    unit_cost: unitCost,
    receipt_path: receiptPath,
    notes: text(formData, "notes") || null,
    frequency: expenseType === "Recurring expense" ? frequency : null,
    next_due_date: expenseType === "Recurring expense" ? nextDueDate : null,
    end_date: expenseType === "Recurring expense" && endDate ? endDate : null,
    recorded_by: profile.id,
  });
  if (error) throw new Error(error.message);

  await supabase.from("activity_logs").insert({ user_id: profile.id, activity: "Farm investment recorded", description: `${profile.fullName} recorded ${description}.`, module: "Dashboard" });
  revalidatePath("/investments");
  revalidatePath("/dashboard");
}

export async function deleteExpenseAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const id = text(formData, "id");
  if (!id) throw new Error("Missing investment record.");

  const { data: expense } = await supabase.from("farm_expenses").select("description, receipt_path").eq("id", id).single<{ description: string; receipt_path: string | null }>();
  const { error } = await supabase.from("farm_expenses").delete().eq("id", id);
  if (error) throw new Error(error.message);
  if (expense?.receipt_path) await supabase.storage.from("expense-receipts").remove([expense.receipt_path]);
  await supabase.from("activity_logs").insert({ user_id: profile.id, activity: "Farm investment removed", description: `${profile.fullName} removed ${expense?.description ?? "an investment record"}.`, module: "Dashboard" });
  revalidatePath("/investments");
  revalidatePath("/dashboard");
}
