"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { writeActivityLog } from "@/lib/activity-log";
import { normalizeContactNumber } from "@/lib/contact-number.mjs";
import { parseDatabaseDecimal } from "@/lib/field-validation.mjs";

export type SalesFormState = {
  message: string;
  receiptId?: string;
  receiptNumber?: string;
  paymentReceiptId?: string;
  paymentReceiptNumber?: string;
};

type SubmittedItem = {
  inventory_id: string;
  quantity: number;
  unit_price: number;
};

const paymentMethods = new Set(["Cash", "GCash", "Bank Transfer", "Card", "Installment", "Other"]);
const installmentFrequencies = new Set(["Weekly", "Monthly", "Yearly"]);

type ActiveInstallmentSummary = {
  planId: string;
  salesOrderId: string;
  receiptNumber: string;
  remainingAmount: number;
  nextDueDate: string | null;
};

export async function getCustomerActiveInstallmentAction(
  customerId: string | null,
  customerContact: string,
): Promise<{ installment: ActiveInstallmentSummary | null; error: string | null }> {
  try {
    await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);
  } catch (error) {
    return { installment: null, error: error instanceof Error ? error.message : "Not authorized." };
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { installment: null, error: "Supabase is not configured." };
  const { data, error } = await supabase.rpc("get_customer_active_installment", {
    p_customer_id: customerId,
    p_customer_contact: customerContact,
  });
  if (error) return { installment: null, error: error.message };
  if (!data) return { installment: null, error: null };
  const row = data as ActiveInstallmentSummary;
  return { installment: row, error: null };
}

function parseNumber(value: FormDataEntryValue | null, label: string) {
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

  let items: SubmittedItem[];
  try {
    items = inventoryIds.map((inventoryId, index) => ({
      inventory_id: inventoryId,
      quantity: parseNumber(quantities[index] ?? null, "Quantity"),
      unit_price: parseNumber(unitPrices[index] ?? null, "Unit price"),
    }));
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Enter valid sale quantities." };
  }
  items = items.filter((item) => item.inventory_id && item.quantity > 0);

  if (items.length === 0) {
    return { message: "Add at least one item with a valid quantity." };
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
      return { message: "Select an existing customer for this receipt." };
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
  const initialPaymentReference = text(formData, "initial_payment_transaction_reference");

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
    if (paymentMethod !== "Installment") return { message: "Transaction ID is required for non-cash sales." };
  }

  const installmentFrequency = text(formData, "installment_frequency");
  const installmentCountRaw = text(formData, "installment_count");
  const amountPaidRaw = text(formData, "amount_paid");
  let installmentCount = 0;
  let initialPayment: number | null;
  try {
    installmentCount = installmentCountRaw
      ? parseNumber(formData.get("installment_count"), "Number of payments")
      : 0;
    initialPayment = amountPaidRaw
      ? parseNumber(formData.get("amount_paid"), "Amount paid")
      : null;
  } catch (error) {
    return { message: error instanceof Error ? error.message : "Enter valid payment amounts." };
  }
  const initialPaymentMethod = text(formData, "initial_payment_method", "Cash");

  if (initialPayment !== null && initialPayment < 0) {
    return { message: "Amount paid cannot be negative." };
  }

  if (paymentMethod === "Installment" && initialPayment !== null && initialPayment >= expectedSaleTotal) {
    return { message: "Initial payment must be less than the sale total so a balance remains." };
  }

  if (paymentMethod !== "Cash" && initialPayment !== null && initialPayment > expectedSaleTotal) {
    return { message: "Non-cash payment cannot exceed the sale total." };
  }

  if (paymentMethod === "Installment" && (initialPayment === null || initialPayment <= 0)) {
    return { message: "Enter an initial payment greater than zero." };
  }

  if (paymentMethod === "Installment" && !installmentFrequencies.has(installmentFrequency)) {
    return { message: "Select a valid installment payment frequency." };
  }

  if (paymentMethod === "Installment" && (!Number.isInteger(installmentCount) || installmentCount < 2 || installmentCount > 120)) {
    return { message: "Enter a total of 2 to 120 payments, including the initial payment." };
  }
  if (paymentMethod === "Installment" && installmentCount - 1 > Math.floor((expectedSaleTotal - (initialPayment ?? 0)) * 100)) {
    return { message: "Number of future payments is too high for the remaining balance." };
  }

  if (
    paymentMethod === "Installment" &&
    !new Set(["Cash", "GCash", "Bank Transfer", "Card", "Other"]).has(initialPaymentMethod)
  ) {
    return { message: "Select a valid initial payment method." };
  }

  if (paymentMethod === "Installment" && (initialPayment ?? 0) > 0 && initialPaymentMethod !== "Cash" && !initialPaymentReference) {
    return { message: "Enter the transaction ID for the non-cash initial payment." };
  }
  const initialOtherPaymentMethod = text(formData, "initial_other_payment_method");
  if (paymentMethod === "Installment" && initialPaymentMethod === "Other" && !initialOtherPaymentMethod) {
    return { message: "Describe the other initial payment method." };
  }

  if (paymentMethod === "Installment") {
    let cashTendered = initialPayment!;
    try {
      cashTendered = initialPaymentMethod === "Cash"
        ? parseNumber(formData.get("initial_cash_tendered"), "Cash received")
        : initialPayment!;
    } catch (error) {
      return { message: error instanceof Error ? error.message : "Enter a valid cash received amount." };
    }
    if (cashTendered < initialPayment!) return { message: "Cash received must cover the initial payment." };
    const { data, error } = await supabase.rpc("record_installment_sale", {
      p_request_id: text(formData, "idempotency_key"),
      p_customer_id: selectedCustomerId,
      p_customer_name: customerName,
      p_customer_contact: customerContact,
      p_frequency: installmentFrequency,
      p_total_payments: installmentCount,
      p_initial_payment: initialPayment,
      p_initial_payment_method: initialPaymentMethod,
      p_initial_payment_reference: initialPaymentReference || null,
      p_initial_payment_other_method: initialPaymentMethod === "Other" ? initialOtherPaymentMethod : null,
      p_cash_tendered: cashTendered,
      p_discount_code: discountCode || null,
      p_remarks: text(formData, "remarks") || null,
      p_items: items,
    });
    if (error) {
      return { message: friendlySalesError(error, "Unable to record the installment sale.") };
    }
    const result = data as {
      sales_order_id: string;
      receipt_number: string;
      payment_id: string;
      payment_receipt_number: string;
    };
    await writeActivityLog(supabase, {
      userId: adminProfile.id,
      activity: "Installment sale and initial payment recorded",
      description: `${adminProfile.fullName} recorded receipt ${result.receipt_number} and collected PHP ${initialPayment!.toFixed(2)} under payment receipt ${result.payment_receipt_number}.`,
      module: "Sales",
    });
    revalidatePath("/sales");
    revalidatePath("/inventory");
    revalidatePath("/customers");
    revalidatePath("/dashboard");
    return {
      message: "Initial payment recorded.",
      receiptId: result.sales_order_id,
      receiptNumber: result.receipt_number,
      paymentReceiptId: result.payment_id,
      paymentReceiptNumber: result.payment_receipt_number,
    };
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

  if (discountCode) {
    await writeActivityLog(supabase, {
      userId: adminProfile.id,
      activity: "Discount applied",
      description: `${discountCode} was applied to receipt ${data.receipt_number} for ${customerName}.`,
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
