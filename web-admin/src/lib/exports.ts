import { getCurrentAdminProfile } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type ExportInventoryRow = {
  stockCode: string;
  itemName: string;
  category: string;
  quantity: number;
  unit: string;
  minimumQuantity: number;
  storageLocation: string;
  unitCost: number;
  sellingPrice: number;
  inventoryValue: number;
  estimatedSalesValue: number;
  updatedAt: string;
};

export type ExportSalesRow = {
  receiptNumber: string;
  saleDate: string;
  customerName: string;
  customerContact: string;
  paymentMethod: string;
  itemName: string;
  quantitySold: number;
  unit: string;
  unitPrice: number;
  lineTotal: number;
  receiptSubtotal: number;
  discountAmount: number;
  receiptTotal: number;
  status: string;
};

type InventoryRow = {
  stock_code: string | null;
  item_name: string;
  category: string;
  quantity: number | string;
  unit: string;
  minimum_quantity: number | string;
  storage_location: string | null;
  unit_cost: number | string | null;
  selling_price: number | string | null;
  updated_at: string;
};

type SalesOrderRow = {
  receipt_number: string;
  sale_date: string;
  customer_name: string | null;
  customer_contact: string | null;
  payment_method: string;
  subtotal: number | string;
  discount_amount: number | string;
  total_amount: number | string;
  status: string;
  sales_order_items: Array<{
    item_name_snapshot: string;
    unit_snapshot: string;
    quantity_sold: number | string;
    unit_price: number | string;
    line_total: number | string;
  }>;
};

function toNumber(value: number | string | null | undefined) {
  if (typeof value === "number") {
    return value;
  }

  return Number(value ?? 0);
}

export async function requireOperationsExporter() {
  const profile = await getCurrentAdminProfile();

  if (
    !profile ||
    !["System Administrator", "Farm Inventory Manager"].includes(profile.roleName)
  ) {
    return null;
  }

  return profile;
}

export async function getInventoryExportRows() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  const { data } = await supabase
    .from("inventory")
    .select(
      "stock_code, item_name, category, quantity, unit, minimum_quantity, storage_location, unit_cost, selling_price, updated_at",
    )
    .order("item_name", { ascending: true })
    .returns<InventoryRow[]>();

  return (data ?? []).map<ExportInventoryRow>((row) => {
    const quantity = toNumber(row.quantity);
    const unitCost = toNumber(row.unit_cost);
    const sellingPrice = toNumber(row.selling_price);

    return {
      stockCode: row.stock_code ?? "Uncoded",
      itemName: row.item_name,
      category: row.category,
      quantity,
      unit: row.unit,
      minimumQuantity: toNumber(row.minimum_quantity),
      storageLocation: row.storage_location ?? "Not set",
      unitCost,
      sellingPrice,
      inventoryValue: quantity * unitCost,
      estimatedSalesValue: quantity * sellingPrice,
      updatedAt: row.updated_at,
    };
  });
}

export async function getSalesExportRows() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  const { data } = await supabase
    .from("sales_orders")
    .select(
      "receipt_number, sale_date, customer_name, customer_contact, payment_method, subtotal, discount_amount, total_amount, status, sales_order_items(item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total)",
    )
    .order("sale_date", { ascending: false })
    .returns<SalesOrderRow[]>();

  return (data ?? []).flatMap<ExportSalesRow>((order) =>
    order.sales_order_items.map((item) => ({
      receiptNumber: order.receipt_number,
      saleDate: order.sale_date,
      customerName: order.customer_name ?? "Walk-in customer",
      customerContact: order.customer_contact ?? "",
      paymentMethod: order.payment_method,
      itemName: item.item_name_snapshot,
      quantitySold: toNumber(item.quantity_sold),
      unit: item.unit_snapshot,
      unitPrice: toNumber(item.unit_price),
      lineTotal: toNumber(item.line_total),
      receiptSubtotal: toNumber(order.subtotal),
      discountAmount: toNumber(order.discount_amount),
      receiptTotal: toNumber(order.total_amount),
      status: order.status,
    })),
  );
}

export function rowsToCsv(rows: Array<Array<string | number>>) {
  return rows
    .map((row) =>
      row
        .map((value) => {
          const text = String(value ?? "");
          return `"${text.replaceAll('"', '""')}"`;
        })
        .join(","),
    )
    .join("\r\n");
}

export function rowsToExcelHtml(title: string, rows: Array<Array<string | number>>) {
  const body = rows
    .map(
      (row) =>
        `<tr>${row
          .map((value) => `<td>${String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")}</td>`)
          .join("")}</tr>`,
    )
    .join("");

  return `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title></head><body><table>${body}</table></body></html>`;
}
