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

const paymentMethods = new Set(["Cash", "GCash", "Bank Transfer", "Card", "Installment", "Other"]);
const installmentFrequencies = new Set(["Weekly", "Monthly", "Yearly"]);

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
  let adminProfile: Awaited<ReturnType<typeof requireAdminRole>>;
  try {
    adminProfile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
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
  const customerFirstName = text(formData, "customer_first_name");
  const customerMiddleInitial = text(formData, "customer_middle_initial").replace(/[^a-z]/gi, "").slice(0, 1).toUpperCase();
  const customerLastName = text(formData, "customer_last_name");
  const customerName = [customerFirstName, customerMiddleInitial ? `${customerMiddleInitial}.` : "", customerLastName].filter(Boolean).join(" ");
  const customerContact = text(formData, "customer_contact");
  const paymentMethod = text(formData, "payment_method", "Cash");
  const transactionReference = text(formData, "transaction_reference");
  const otherPaymentMethod = text(formData, "other_payment_method");

  if (!customerName) {
    return { message: "Customer name is required." };
  }

  if (!customerContact) {
    return { message: "Customer contact is required." };
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

  if (discountCode && !/^[A-Z0-9_-]{3,32}$/.test(discountCode)) {
    return { message: "Discount code format is invalid." };
  }

  if (paymentMethod === "Other" && !otherPaymentMethod) {
    return { message: "Enter the other payment method used." };
  }

  if (paymentMethod !== "Cash" && !transactionReference) {
    if (paymentMethod === "Installment") {
      // Installment plans do not require a payment transaction reference.
    } else {
    return { message: "Transaction ID is required for non-cash sales." };
    }
  }

  const installmentFrequency = text(formData, "installment_frequency");
  const installmentAmountRaw = text(formData, "installment_amount");
  const installmentAmount = parseNumber(formData.get("installment_amount"));
  const amountPaidRaw = text(formData, "amount_paid");
  const initialPayment = amountPaidRaw ? parseNumber(formData.get("amount_paid")) : null;
  const initialPaymentMethod = text(formData, "initial_payment_method", "Cash");

  if (initialPayment !== null && initialPayment < 0) {
    return { message: "Amount paid cannot be negative." };
  }

  if (paymentMethod === "Installment" && !installmentFrequencies.has(installmentFrequency)) {
    return { message: "Select a valid installment payment frequency." };
  }

  if (paymentMethod === "Installment" && (!installmentAmountRaw || installmentAmount <= 0)) {
    return { message: "Enter an installment amount greater than zero." };
  }

  if (
    paymentMethod === "Installment" &&
    !new Set(["Cash", "GCash", "Bank Transfer", "Card", "Other"]).has(initialPaymentMethod)
  ) {
    return { message: "Select a valid initial payment method." };
  }

  const payload = {
    p_customer_name: customerName,
    p_customer_contact: customerContact,
    // The legacy sales RPC does not accept Installment yet. Record the sale
    // through its Cash path, then normalize the saved order below.
    p_payment_method: paymentMethod === "Installment" ? "Cash" : paymentMethod,
    p_transaction_reference: transactionReference,
    p_other_payment_method: paymentMethod === "Installment" ? null : otherPaymentMethod,
    p_discount_type: "None",
    p_discount_value: 0,
    p_discount_code: discountCode,
    // The legacy RPC treats any non-null amount as a full payment. For an
    // installment sale, save the initial payment after the order is created
    // so a valid partial payment is not rejected by that legacy check.
    p_amount_paid: paymentMethod === "Installment" ? null : initialPayment,
    p_remarks: String(formData.get("remarks") ?? ""),
    p_items: items,
  };

  let { data, error } = await supabase
    .rpc("record_sales_order", payload)
    .single<{ id: string; receipt_number: string }>();

  if (error) {
    if (
      !discountCode &&
      error.message.includes("p_discount_code") &&
      !error.message.includes("p_transaction_reference") &&
      !error.message.includes("p_other_payment_method")
    ) {
      const legacyPayload = Object.fromEntries(
        Object.entries(payload).filter(
          ([key]) =>
            ![
              "p_discount_code",
              "p_transaction_reference",
              "p_other_payment_method",
            ].includes(key),
        ),
      );
      const fallback = await supabase
        .rpc("record_sales_order", legacyPayload)
        .single<{ id: string; receipt_number: string }>();

      if (!fallback.error) {
        data = fallback.data;
        error = null;
      }
    }

    if (error && needsDiscountMigration(error.message)) {
      return {
        message:
          "Sales database is not fully upgraded yet. Apply the latest Supabase migration before using discount codes or transaction IDs.",
      };
    }

    if (error) {
      return { message: error.message };
    }
  }

  if (!data) {
    return { message: "The sale could not be recorded. Please try again." };
  }

  if (paymentMethod === "Installment") {
    const { error: installmentPlanError } = await supabase.rpc(
      "create_installment_plan",
      {
        p_sales_order_id: data.id,
        p_frequency: installmentFrequency,
        p_payment_amount: installmentAmount,
        p_initial_payment: initialPayment ?? 0,
        p_initial_payment_method: initialPaymentMethod,
      },
    );

    if (installmentPlanError) {
      const { error: rollbackError } = await supabase.rpc("void_sales_record", {
        p_id: data.id,
        p_source: "receipt",
        p_reason: "Installment schedule creation failed; receipt rolled back.",
      });

      if (
        installmentPlanError.message.includes("create_installment_plan") ||
        installmentPlanError.message.includes("schema cache")
      ) {
        return {
          message:
            rollbackError
              ? "Installment sales database support is not deployed yet, and the receipt could not be rolled back. Do not retry until the latest Supabase migrations are applied."
              : "Installment sales database support is not deployed yet. The receipt was rolled back; apply the latest Supabase migrations, then try again.",
        };
      }

      return {
        message: rollbackError
          ? `The installment schedule could not be created, and the receipt could not be rolled back: ${installmentPlanError.message}`
          : `The installment schedule could not be created. The receipt was rolled back: ${installmentPlanError.message}`,
      };
    }

    await supabase.from("activity_logs").insert({
      user_id: adminProfile.id,
      activity: "Installment plan created",
      description: `${adminProfile.fullName} created an installment plan for receipt ${data.receipt_number}${initialPayment && initialPayment > 0 ? ` with an initial payment of PHP ${initialPayment.toFixed(2)}` : ""}.`,
      module: "Sales",
    });
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
  const profile = await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

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

  const { data: installmentPlan } = await supabase
    .from("installment_plans")
    .select("receipt_number")
    .eq("sales_order_id", id)
    .maybeSingle<{ receipt_number: string }>();

  const { error } = await supabase.rpc("void_sales_record", {
    p_id: id,
    p_source: source,
    p_reason: reason,
  });

  if (error) {
    throw new Error(friendlySalesError(error, "Unable to void sale."));
  }

  await supabase.from("activity_logs").insert({
    user_id: profile.id,
    activity: installmentPlan ? "Installment plan cancelled" : "Sale voided",
    description: installmentPlan
      ? `${profile.fullName} cancelled the installment plan for receipt ${installmentPlan.receipt_number}. Reason: ${reason}`
      : `${profile.fullName} voided a sale. Reason: ${reason}`,
    module: "Sales",
  });

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/customers");
  revalidatePath("/dashboard");
}
