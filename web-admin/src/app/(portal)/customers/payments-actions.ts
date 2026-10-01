"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { writeActivityLog } from "@/lib/activity-log";
import { parseDatabaseDecimal } from "@/lib/field-validation.mjs";

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

export async function createCustomerPaymentAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const customerName = text(formData, "customer_name");
  const amount = parseDatabaseDecimal(formData.get("amount"), "Amount");
  if (!customerName || amount <= 0) {
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
  await writeActivityLog(supabase, {
    userId: profile.id,
    activity: "Customer payment created",
    description: `A payment record for ${customerName} was created.`,
    module: "Customers",
  });
  revalidatePath("/customers");
}

export async function markCustomerPaymentPaidAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const paymentId = text(formData, "id");
  const { data: payment, error } = await supabase
    .from("customer_payments")
    .update({ status: "Paid", paid_at: new Date().toISOString() })
    .eq("id", paymentId)
    .select("customer_name, amount")
    .single<{ customer_name: string; amount: number }>();
  if (error) throw new Error(error.message);
  await writeActivityLog(supabase, {
    userId: profile.id,
    activity: "Customer payment marked paid",
    description: `A PHP ${Number(payment.amount).toFixed(2)} payment from ${payment.customer_name} was marked as paid.`,
    module: "Customers",
  });
  revalidatePath("/customers");
}

