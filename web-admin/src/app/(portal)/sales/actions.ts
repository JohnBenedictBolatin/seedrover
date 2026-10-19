"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { normalizeContactNumber } from "@/lib/contact-number.mjs";
import { parseDatabaseDecimal } from "@/lib/field-validation.mjs";

export type SalesFormState = {
  message: string;
  receiptId?: string;
  receiptNumber?: string;
};

type SubmittedItem = {
  inventory_id: string;
  quantity: number;
  unit_price: number;
  batch_id: string | null;
};

const paymentMethods = new Set(["Cash", "GCash", "Bank Transfer", "Card", "Other"]);

function parseNumber(value: FormDataEntryValue | null, label: string) {
  if (value === null || String(value).trim() === "") {
    throw new Error(`${label} is required.`);
  }
  return parseDatabaseDecimal(value, label);
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

  const submissionId = text(formData, "idempotency_key");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(submissionId)) {
    return { message: "The sale could not be saved safely. Review the form and submit it again." };
  }

  const inventoryIds = formData.getAll("inventory_id").map(String);
  const batchIds = formData.getAll("batch_id").map(String);
  const quantities = formData.getAll("quantity");
  const unitPrices = formData.getAll("unit_price");

  let items: SubmittedItem[];
  try {
    items = inventoryIds.map((inventoryId, index) => ({
      inventory_id: inventoryId,
      quantity: parseNumber(quantities[index] ?? null, "Quantity"),
      unit_price: parseNumber(unitPrices[index] ?? null, "Unit price"),
      batch_id: batchIds[index] || null,
    }));
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Enter valid sale quantities." };
  }
  items = items.filter((item) => item.inventory_id && item.quantity > 0);

  if (items.length === 0) {
    return { message: "Add at least one sale item with a quantity greater than zero." };
  }
  if (new Set(items.map((item) => item.inventory_id)).size !== items.length) {
    return { message: "Choose each inventory item only once in a sale." };
  }

  const discountCode = text(formData, "discount_code").toUpperCase();
  const customerMode = text(formData, "customer_mode", "new");
  if (customerMode !== "new" && customerMode !== "existing") {
    return { message: "Select whether this is a new or existing customer." };
  }
  const customerName = customerMode === "existing"
    ? text(formData, "existing_customer_name")
    : [
        text(formData, "customer_first_name"),
        text(formData, "customer_middle_initial").replace(/[^a-z]/gi, "").slice(0, 1).toUpperCase(),
        text(formData, "customer_last_name"),
      ].filter(Boolean).join(" ");
  const submittedCustomerContact = text(formData, "customer_contact");
  let customerContact: string;
  try {
    customerContact = normalizeContactNumber(submittedCustomerContact, { required: true })!;
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Enter an 11-digit contact number." };
  }
  const selectedCustomerId = text(formData, "existing_customer_id") || null;
  if (customerMode === "existing") {
    const customerKey = text(formData, "existing_customer_key");
    if (!customerKey || !customerName) {
      return { message: "Select an existing customer for this sale." };
    }
    const [orderMatch, marketMatch] = await Promise.all([
      selectedCustomerId
        ? supabase.from("sales_orders").select("customer_id, customer_name").eq("status", "Completed").eq("customer_id", selectedCustomerId)
            .returns<Array<{ customer_id: string | null; customer_name: string | null }>>()
        : supabase.from("sales_orders").select("customer_id, customer_name").eq("status", "Completed").eq("customer_contact", submittedCustomerContact)
            .returns<Array<{ customer_id: string | null; customer_name: string | null }>>(),
      supabase
        .from("sales_transactions")
        .select("customer_id, customer_name")
        .eq("status", "Completed")
        .eq("customer_contact", submittedCustomerContact)
        .returns<Array<{ customer_id: string | null; customer_name: string | null }>>(),
    ]);
    if (orderMatch.error || marketMatch.error) {
      return { message: orderMatch.error?.message ?? marketMatch.error?.message ?? "Unable to verify the selected customer." };
    }
    const normalizedName = customerName.toLowerCase().replace(/\s+/g, " ").trim();
    const wasCustomerSoldTo = [...(orderMatch.data ?? []), ...(marketMatch.data ?? [])].some(
      (record) => record.customer_name?.toLowerCase().replace(/\s+/g, " ").trim() === normalizedName,
    );
    if (!wasCustomerSoldTo) {
      return { message: "The selected customer is no longer available. Refresh the page and select them again." };
    }
  }
  const paymentMethod = text(formData, "payment_method", "Cash");
  const transactionReference = text(formData, "transaction_reference");
  const otherPaymentMethod = text(formData, "other_payment_method");

  if (!customerName) {
    return { message: "Customer name is required." };
  }

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

  const { data: inventoryRows } = await supabase
    .from("inventory")
    .select("id, unit, selling_price")
    .in("id", items.map((item) => item.inventory_id));
  const inventoryById = new Map((inventoryRows ?? []).map((item) => [item.id, item]));
  for (const item of items) {
    const inventory = inventoryById.get(item.inventory_id);
    if (!inventory) {
      return { message: "One of the selected inventory items is no longer available." };
    }

    const unit = inventory.unit ?? "kg";
    if (unit !== "kg") {
      return { message: "Inventory quantities must use kg as the unit." };
    }

    item.unit_price = Number(inventory.selling_price ?? 0);
  }

  let expectedSaleTotal = items.reduce((sum, item) => sum + item.quantity * item.unit_price, 0);

  if (discountCode && !/^[A-Z0-9_-]{3,32}$/.test(discountCode)) {
    return { message: "Discount code format is invalid." };
  }

  if (discountCode) {
    const { data: discount, error: discountError } = await supabase
      .from("customer_discounts")
      .select("discount_type, discount_value")
      .eq("discount_code", discountCode)
      .eq("status", "Released")
      .maybeSingle();
    if (discountError) return { message: discountError.message };
    if (discount) {
      const value = Number(discount.discount_value);
      const amount = discount.discount_type === "Amount"
        ? Math.min(value, expectedSaleTotal)
        : expectedSaleTotal * Math.min(value, 100) / 100;
      expectedSaleTotal = Math.max(expectedSaleTotal - amount, 0);
    }
  }

  if (paymentMethod === "Other" && !otherPaymentMethod) {
    return { message: "Enter the other payment method used." };
  }

  if (paymentMethod !== "Cash" && !transactionReference) {
    return { message: "Transaction ID is required for non-cash sales." };
  }
  const amountPaidRaw = text(formData, "amount_paid");
  if (!amountPaidRaw) {
    return { message: "Enter the amount paid." };
  }

  let amountPaid: number;
  try {
    amountPaid = parseNumber(formData.get("amount_paid"), "Amount paid");
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Enter valid payment amounts." };
  }
  if (amountPaid < 0) {
    return { message: "Amount paid cannot be negative." };
  }
  if (amountPaid < expectedSaleTotal) {
    return { message: "Amount paid cannot be lower than the total." };
  }
  if (paymentMethod !== "Cash" && amountPaid > expectedSaleTotal) {
    return { message: "Non-cash payment cannot exceed the sale total." };
  }

  const { data: order, error } = await supabase.rpc("record_sales_order_v2", {
    p_entry: {
      submission_id: submissionId,
      customer_name: customerName,
      customer_contact: customerContact,
      payment_method: paymentMethod,
      transaction_reference: transactionReference || null,
      other_payment_method: otherPaymentMethod || null,
      discount_type: "None",
      discount_value: 0,
      discount_code: discountCode || null,
      amount_paid: amountPaid,
      remarks: String(formData.get("remarks") ?? ""),
      items,
    },
  });
  const data = order as { id: string; receipt_number: string } | null;
  if (error) {
    if (error.message.includes("Transaction ID has already been used")) {
      return { message: "This transaction ID is already recorded on another sale. Check the existing receipt and enter a different ID." };
    }
    const message = error.message.includes("record_sales_order_v2") || error.message.includes("Could not find the function")
      ? "Sales saving needs the latest database update. Ask the system administrator to apply the approved migration."
      : error.message;
    if (needsDiscountMigration(message)) {
      return { message: "Sales database is not fully upgraded yet. Apply the latest approved Supabase migration before using discounts or transaction IDs." };
    }
    return { message };
  }

  if (!data) {
    return { message: "The sale could not be recorded. Please try again." };
  }

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/customers");
  revalidatePath("/dashboard");

  return {
    message: `Sale ${data.receipt_number} recorded.`,
    receiptId: data.id,
    receiptNumber: data.receipt_number,
  };
}

export async function voidSalesRecordAction(formData: FormData) {
  const profile = await requireAdminRole([
    "System Administrator",
    "Farm Inventory Manager",
  ]);
  if (
    !["System Administrator", "Farm Inventory Manager"].includes(
      profile.roleName,
    )
  ) {
    throw new Error("Only an administrator or inventory manager can void sales.");
  }

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Sign in before cancelling sales.");
  }

  const id = text(formData, "id");
  const source = text(formData, "source");
  const reason = text(formData, "reason", "Voided from Sales page.");
  const submissionId = text(formData, "submission_id");

  if (!id) {
    throw new Error("Missing sales record.");
  }

  if (source !== "receipt" && source !== "market") {
    throw new Error("Unknown sales source.");
  }

  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(submissionId)) {
    throw new Error("The cancellation could not be saved safely. Reopen the sale and try again.");
  }

  const { error } = await supabase.rpc("void_sales_record_v2", {
    p_entry: {
      id,
      source,
      reason,
      submission_id: submissionId,
    },
  });

  if (error) {
    throw new Error(friendlySalesError(error, "Unable to void sale."));
  }

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/customers");
  revalidatePath("/dashboard");
}
