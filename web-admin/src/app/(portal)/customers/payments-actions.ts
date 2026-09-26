"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { writeActivityLog } from "@/lib/activity-log";

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

const receiptTypes = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);

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

export async function recordInstallmentPaymentAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");

  const scheduleId = text(formData, "schedule_id");
  const amount = Number(formData.get("amount"));
  const paymentDate = text(formData, "payment_date");
  const paymentMethod = text(formData, "payment_method", "Cash");
  const transactionReference = text(formData, "transaction_reference") || null;
  const otherPaymentMethod = text(formData, "other_payment_method") || null;
  const notes = text(formData, "notes") || null;

  if (!scheduleId || !Number.isFinite(amount) || amount <= 0 || !paymentDate) {
    throw new Error("The installment period, amount, and payment date are required.");
  }

  if (!["Cash", "GCash", "Bank Transfer", "Card", "Other"].includes(paymentMethod)) {
    throw new Error("Choose a valid payment method.");
  }

  if (paymentMethod !== "Cash" && !transactionReference) {
    throw new Error("A transaction ID is required for non-cash payments.");
  }

  if (paymentMethod === "Other" && !otherPaymentMethod) {
    throw new Error("Describe the other payment method used.");
  }

  const { data: scheduleInfo } = await supabase
    .from("installment_schedule")
    .select("installment_number")
    .eq("id", scheduleId)
    .maybeSingle<{ installment_number: number }>();

  let receiptPath: string | null = null;
  const receipt = formData.get("receipt");
  if (receipt instanceof File && receipt.size > 0) {
    if (receipt.size > 5 * 1024 * 1024) throw new Error("Receipt must be 5MB or smaller.");
    if (!receiptTypes.has(receipt.type)) throw new Error("Receipt must be a JPG, PNG, WebP, or PDF file.");
    const extension = receipt.name.split(".").pop()?.toLowerCase() || "bin";
    receiptPath = `${scheduleId}/${randomUUID()}-receipt.${extension}`;
    const { error: uploadError } = await supabase.storage.from("installment-receipts").upload(receiptPath, receipt, { contentType: receipt.type });
    if (uploadError) throw new Error(uploadError.message);
  }

  const { error } = await supabase.rpc("record_installment_payment", {
    p_schedule_id: scheduleId,
    p_amount: amount,
    p_payment_date: paymentDate,
    p_payment_method: paymentMethod,
    p_transaction_reference: paymentMethod === "Cash" ? null : transactionReference,
    p_other_payment_method: paymentMethod === "Other" ? otherPaymentMethod : null,
    p_notes: notes,
    p_receipt_path: receiptPath,
  });

  if (error) {
    if (receiptPath) await supabase.storage.from("installment-receipts").remove([receiptPath]);
    if (error.message.includes("record_installment_payment") || error.message.includes("schema cache")) {
      throw new Error("Installment payment support is not deployed yet. Apply the latest Supabase migration, then try again.");
    }
    throw new Error(error.message);
  }

  await writeActivityLog(supabase, {
    userId: profile.id,
    activity: "Installment payment recorded",
    description: `${profile.fullName} recorded PHP ${amount.toFixed(2)} for installment period ${scheduleInfo?.installment_number ?? "selected"}.${receiptPath ? " A receipt was attached." : ""}`,
    module: "Customers",
  });

  revalidatePath("/customers");
  revalidatePath("/sales");
  revalidatePath("/sales", "layout");
  const saleId = text(formData, "sales_order_id");
  if (saleId) revalidatePath(`/sales/${saleId}`);
}
