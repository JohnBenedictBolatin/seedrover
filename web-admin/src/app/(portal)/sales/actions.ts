"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type SalesFormState = {
  message: string;
  receiptId?: string;
  receiptNumber?: string;
};

type SubmittedItem = {
  inventory_id: string;
  quantity: number;
  unit_price: number;
};

const paymentMethods = new Set(["Cash", "GCash", "Bank Transfer", "Card", "Other"]);

function parseNumber(value: FormDataEntryValue | null) {
  const parsed = Number(String(value ?? "").trim());
  return Number.isFinite(parsed) ? parsed : 0;
}

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function needsDiscountMigration(message: string) {
  return (
    message.includes("customer_discounts") ||
    message.includes("p_discount_code") ||
    message.includes("p_transaction_reference") ||
    message.includes("p_other_payment_method") ||
    message.includes("sales_orders.transaction_reference") ||
    message.includes("sales_orders.other_payment_method") ||
    message.includes("record_sales_order") ||
    message.includes("schema cache")
  );
}

function friendlySalesError(error: unknown, fallback = "Sales action failed.") {
  if (!(error instanceof Error)) {
    return fallback;
  }

  if (
    error.message.includes("schema cache") ||
    error.message.includes("function public.") ||
    error.message.includes("Could not find the function")
  ) {
    return "Sales database is not fully upgraded yet. Apply the latest Supabase migration and try again.";
  }

  return error.message || fallback;
}

export async function recordSalesOrderAction(
  _state: SalesFormState,
  formData: FormData,
): Promise<SalesFormState> {
  try {
    await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  } catch (error) {
    return {
      message:
        error instanceof Error
          ? error.message
          : "You do not have permission to record sales.",
    };
  }

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return { message: "Supabase is not configured." };
  }

  const inventoryIds = formData.getAll("inventory_id").map(String);
  const quantities = formData.getAll("quantity");
  const unitPrices = formData.getAll("unit_price");

  const items: SubmittedItem[] = inventoryIds
    .map((inventoryId, index) => ({
      inventory_id: inventoryId,
      quantity: parseNumber(quantities[index] ?? null),
      unit_price: parseNumber(unitPrices[index] ?? null),
    }))
    .filter((item) => item.inventory_id && item.quantity > 0);

  if (items.length === 0) {
    return { message: "Add at least one item with a valid quantity." };
  }

  const discountCode = text(formData, "discount_code").toUpperCase();
  const paymentMethod = text(formData, "payment_method", "Cash");
  const transactionReference = text(formData, "transaction_reference");
  const otherPaymentMethod = text(formData, "other_payment_method");

  if (!paymentMethods.has(paymentMethod)) {
    return { message: "Select a valid payment method." };
  }

  for (const item of items) {
    if (item.quantity <= 0) {
      return { message: "Sale quantity must be greater than zero." };
    }

    if (item.unit_price < 0) {
      return { message: "Unit price cannot be negative." };
    }
  }

  if (discountCode && !/^[A-Z0-9_-]{3,32}$/.test(discountCode)) {
    return { message: "Discount code format is invalid." };
  }

  if (paymentMethod === "Other" && !otherPaymentMethod) {
    return { message: "Enter the other payment method used." };
  }

  if (paymentMethod !== "Cash" && !transactionReference) {
    return { message: "Transaction ID is required for non-cash sales." };
  }

  const payload = {
    p_customer_name: String(formData.get("customer_name") ?? ""),
    p_customer_contact: String(formData.get("customer_contact") ?? ""),
    p_payment_method: paymentMethod,
    p_transaction_reference: transactionReference,
    p_other_payment_method: otherPaymentMethod,
    p_discount_type: "None",
    p_discount_value: 0,
    p_discount_code: discountCode,
    p_amount_paid:
      String(formData.get("amount_paid") ?? "").trim() === ""
        ? null
        : parseNumber(formData.get("amount_paid")),
    p_remarks: String(formData.get("remarks") ?? ""),
    p_items: items,
  };

  const { data, error } = await supabase
    .rpc("record_sales_order", payload)
    .single<{ id: string; receipt_number: string }>();

  if (error) {
    if (
      !discountCode &&
      error.message.includes("p_discount_code") &&
      !error.message.includes("p_transaction_reference") &&
      !error.message.includes("p_other_payment_method")
    ) {
      const {
        p_discount_code: _unusedDiscountCode,
        p_transaction_reference: _unusedTransactionReference,
        p_other_payment_method: _unusedOtherPaymentMethod,
        ...legacyPayload
      } = payload;
      const fallback = await supabase
        .rpc("record_sales_order", legacyPayload)
        .single<{ id: string; receipt_number: string }>();

      if (!fallback.error) {
        revalidatePath("/sales");
        revalidatePath("/inventory");
        revalidatePath("/customers");
        revalidatePath("/dashboard");

        return {
          message: `Receipt ${fallback.data.receipt_number} recorded.`,
          receiptId: fallback.data.id,
          receiptNumber: fallback.data.receipt_number,
        };
      }
    }

    if (needsDiscountMigration(error.message)) {
      return {
        message:
          "Sales database is not fully upgraded yet. Apply the latest Supabase migration before using discount codes or transaction IDs.",
      };
    }

    return { message: error.message };
  }

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/customers");
  revalidatePath("/dashboard");

  return {
    message: `Receipt ${data.receipt_number} recorded.`,
    receiptId: data.id,
    receiptNumber: data.receipt_number,
  };
}

export async function voidSalesRecordAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Sign in before voiding sales.");
  }

  const id = text(formData, "id");
  const source = text(formData, "source");
  const reason = text(formData, "reason", "Voided from Sales page.");

  if (!id) {
    throw new Error("Missing sales record.");
  }

  if (source !== "receipt" && source !== "market") {
    throw new Error("Unknown sales source.");
  }

  const { error } = await supabase.rpc("void_sales_record", {
    p_id: id,
    p_source: source,
    p_reason: reason,
  });

  if (error) {
    throw new Error(friendlySalesError(error, "Unable to void sale."));
  }

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/customers");
  revalidatePath("/dashboard");
}
