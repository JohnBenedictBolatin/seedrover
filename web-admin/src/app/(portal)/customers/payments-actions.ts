"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

export async function createCustomerPaymentAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const customerName = text(formData, "customer_name");
  const amount = Number(formData.get("amount"));
  if (!customerName || !Number.isFinite(amount) || amount <= 0) {
    throw new Error("Customer name and a positive amount are required.");
  }

  const { error } = await supabase.from("customer_payments").insert({
    customer_key: customerName.toLowerCase(),
    customer_name: customerName,
    sale_reference: text(formData, "sale_reference") || null,
    amount,
    due_date: text(formData, "due_date") || null,
    notes: text(formData, "notes") || null,
    recorded_by: profile.id,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/customers");
}

export async function markCustomerPaymentPaidAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { error } = await supabase
    .from("customer_payments")
    .update({ status: "Paid", paid_at: new Date().toISOString() })
    .eq("id", text(formData, "id"));
  if (error) throw new Error(error.message);
  revalidatePath("/customers");
}
