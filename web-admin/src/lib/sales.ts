import { createSupabaseServerClient } from "@/lib/supabase/server";

export type SellableItem = {
  id: string;
  label: string;
  stockCode: string;
  quantity: number;
  unit: string;
  sellingPrice: number;
};

export type RecentSalesOrder = {
  id: string;
  receiptNumber: string;
  saleDate: string;
  customerName: string;
  paymentMethod: string;
  totalAmount: number;
  status: string;
};

export type SalesReceiptItem = {
  id: string;
  itemName: string;
  unit: string;
  quantitySold: number;
  unitPrice: number;
  lineTotal: number;
};

export type SalesReceipt = {
  id: string;
  receiptNumber: string;
  saleDate: string;
  customerName: string;
  customerContact: string;
  paymentMethod: string;
  subtotal: number;
  discountType: string;
  discountValue: number;
  discountAmount: number;
  totalAmount: number;
  amountPaid: number | null;
  changeAmount: number | null;
  remarks: string;
  status: string;
  recordedBy: string;
  items: SalesReceiptItem[];
};

type SellableRow = {
  id: string;
  stock_code: string | null;
  item_name: string;
  quantity: number | string;
  unit: string;
  selling_price: number | string | null;
};

type RecentSalesOrderRow = {
  id: string;
  receipt_number: string;
  sale_date: string;
  customer_name: string | null;
  payment_method: string;
  total_amount: number | string;
  status: string;
};

type SalesReceiptItemRow = {
  id: string;
  item_name_snapshot: string;
  unit_snapshot: string;
  quantity_sold: number | string;
  unit_price: number | string;
  line_total: number | string;
};

type SalesReceiptRow = {
  id: string;
  receipt_number: string;
  sale_date: string;
  customer_name: string | null;
  customer_contact: string | null;
  payment_method: string;
  subtotal: number | string;
  discount_type: string;
  discount_value: number | string;
  discount_amount: number | string;
  total_amount: number | string;
  amount_paid: number | string | null;
  change_amount: number | string | null;
  remarks: string | null;
  status: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
  sales_order_items: SalesReceiptItemRow[];
};

function toNumber(value: number | string | null | undefined) {
  if (typeof value === "number") {
    return value;
  }

  return Number(value ?? 0);
}

export async function getSellableInventory() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      items: [],
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("inventory")
    .select("id, stock_code, item_name, quantity, unit, selling_price")
    .gt("quantity", 0)
    .order("item_name", { ascending: true })
    .returns<SellableRow[]>();

  if (error) {
    return {
      items: [],
      error: error.message,
    };
  }

  return {
    items: (data ?? []).map<SellableItem>((row) => ({
      id: row.id,
      label: row.item_name,
      stockCode: row.stock_code ?? "Uncoded",
      quantity: toNumber(row.quantity),
      unit: row.unit,
      sellingPrice: toNumber(row.selling_price),
    })),
    error: null,
  };
}

export async function getRecentSalesOrders() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      orders: [],
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("sales_orders")
    .select("id, receipt_number, sale_date, customer_name, payment_method, total_amount, status")
    .order("sale_date", { ascending: false })
    .limit(10)
    .returns<RecentSalesOrderRow[]>();

  if (error) {
    return {
      orders: [],
      error: error.message,
    };
  }

  return {
    orders: (data ?? []).map<RecentSalesOrder>((row) => ({
      id: row.id,
      receiptNumber: row.receipt_number,
      saleDate: row.sale_date,
      customerName: row.customer_name ?? "Walk-in customer",
      paymentMethod: row.payment_method,
      totalAmount: toNumber(row.total_amount),
      status: row.status,
    })),
    error: null,
  };
}

export async function getSalesReceipt(id: string) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      receipt: null,
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("sales_orders")
    .select(
      "id, receipt_number, sale_date, customer_name, customer_contact, payment_method, subtotal, discount_type, discount_value, discount_amount, total_amount, amount_paid, change_amount, remarks, status, profiles(full_name), sales_order_items(id, item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total)",
    )
    .eq("id", id)
    .single<SalesReceiptRow>();

  if (error || !data) {
    return {
      receipt: null,
      error: error?.message ?? "Receipt was not found.",
    };
  }

  const profile = Array.isArray(data.profiles) ? data.profiles[0] : data.profiles;

  return {
    receipt: {
      id: data.id,
      receiptNumber: data.receipt_number,
      saleDate: data.sale_date,
      customerName: data.customer_name ?? "Walk-in customer",
      customerContact: data.customer_contact ?? "Not provided",
      paymentMethod: data.payment_method,
      subtotal: toNumber(data.subtotal),
      discountType: data.discount_type,
      discountValue: toNumber(data.discount_value),
      discountAmount: toNumber(data.discount_amount),
      totalAmount: toNumber(data.total_amount),
      amountPaid: data.amount_paid === null ? null : toNumber(data.amount_paid),
      changeAmount:
        data.change_amount === null ? null : toNumber(data.change_amount),
      remarks: data.remarks ?? "",
      status: data.status,
      recordedBy: profile?.full_name ?? "SeedRover user",
      items: data.sales_order_items.map<SalesReceiptItem>((item) => ({
        id: item.id,
        itemName: item.item_name_snapshot,
        unit: item.unit_snapshot,
        quantitySold: toNumber(item.quantity_sold),
        unitPrice: toNumber(item.unit_price),
        lineTotal: toNumber(item.line_total),
      })),
    },
    error: null,
  };
}
