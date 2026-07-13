"use server";

import { revalidatePath } from "next/cache";
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

function parseNumber(value: FormDataEntryValue | null) {
  const parsed = Number(String(value ?? "").trim());
  return Number.isFinite(parsed) ? parsed : 0;
}

export async function recordSalesOrderAction(
  _state: SalesFormState,
  formData: FormData,
): Promise<SalesFormState> {
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

  const payload = {
    p_customer_name: String(formData.get("customer_name") ?? ""),
    p_customer_contact: String(formData.get("customer_contact") ?? ""),
    p_payment_method: String(formData.get("payment_method") ?? "Cash"),
    p_discount_type: String(formData.get("discount_type") ?? "None"),
    p_discount_value: parseNumber(formData.get("discount_value")),
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
    return { message: error.message };
  }

  revalidatePath("/sales");
  revalidatePath("/inventory");
  revalidatePath("/dashboard");

  return {
    message: `Receipt ${data.receipt_number} recorded.`,
    receiptId: data.id,
    receiptNumber: data.receipt_number,
  };
}
