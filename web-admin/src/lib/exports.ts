import { getCurrentAdminProfile } from "@/lib/auth";
import { getCustomersDashboard } from "@/lib/customers";
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
  transactionReference: string;
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

export type ExportCustomerRow = {
  name: string;
  contact: string;
  customerType: string;
  tags: string;
  location: string;
  receiptCount: number;
  totalSpent: number;
  averageSpend: number;
  lastPurchaseAt: string;
  paymentMethods: string;
  topItems: string;
  notes: string;
};

export type ExportStockMovementRow = {
  itemName: string;
  stockCode: string;
  movementType: string;
  quantity: number;
  source: string;
  remarks: string;
  createdAt: string;
};

export type ExportDiscountRow = {
  code: string;
  customerName: string;
  discountType: string;
  discountValue: number;
  releasedAt: string;
  redeemedAt: string;
  status: string;
};

export type SalesExportFilters = {
  end?: string;
  payment?: string;
  start?: string;
  status?: string;
};

export type ReportExportFilters = SalesExportFilters & {
  category?: string;
  customer?: string;
  search?: string;
  source?: string;
  type?: string;
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

type SalesTransactionExportRow = {
  id: string;
  sale_date: string;
  customer_name: string | null;
  payment_method: string | null;
  transaction_reference?: string | null;
  quantity_sold: number | string;
  unit_price: number | string;
  total_amount: number | string;
  status: string;
  inventory:
    | {
        item_name: string;
        unit: string;
      }
    | {
        item_name: string;
        unit: string;
      }[]
    | null;
};

type StockMovementRow = {
  transaction_type: string;
  quantity: number | string;
  remarks: string | null;
  source: string | null;
  created_at: string;
  inventory:
    | {
        item_name: string;
        stock_code: string | null;
      }
    | {
        item_name: string;
        stock_code: string | null;
      }[]
    | null;
};

type DiscountRow = {
  discount_code: string;
  customer_name: string;
  discount_type: string;
  discount_value: number | string;
  released_at: string;
  used_at: string | null;
  status: string;
};

function toNumber(value: number | string | null | undefined) {
  if (typeof value === "number") {
    return value;
  }

  return Number(value ?? 0);
}

function firstRelation<T>(value: T | T[] | null | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function isMissingTransactionReferenceColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.transaction_reference") ?? false;
}

function inventoryStatus(row: InventoryRow) {
  const quantity = toNumber(row.quantity);
  const minimum = toNumber(row.minimum_quantity);

  if (quantity <= 0) {
    return "Out of Stock";
  }

  if (quantity <= minimum * 0.5) {
    return "Critical Stock";
  }

  if (quantity <= minimum) {
    return "Low Stock";
  }

  return "In Stock";
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

export async function getInventoryExportRows(filters: ReportExportFilters = {}) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  let query = supabase
    .from("inventory")
    .select(
      "stock_code, item_name, category, quantity, unit, minimum_quantity, storage_location, unit_cost, selling_price, updated_at",
    )
    .order("item_name", { ascending: true });

  if (filters.category && filters.category !== "All") {
    query = query.eq("category", filters.category);
  }

  const { data } = await query.returns<InventoryRow[]>();
  const search = filters.search?.trim().toLowerCase();

  return (data ?? [])
    .filter((row) => {
      if (!search) {
        return true;
      }

      return `${row.stock_code ?? ""} ${row.item_name} ${row.category} ${row.storage_location ?? ""}`
        .toLowerCase()
        .includes(search);
    })
    .filter((row) => !filters.status || filters.status === "All" || inventoryStatus(row) === filters.status)
    .map<ExportInventoryRow>((row) => {
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

export async function getSalesExportRows(filters: SalesExportFilters = {}) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  let orderQuery = supabase
    .from("sales_orders")
    .select(
      "receipt_number, sale_date, customer_name, customer_contact, payment_method, subtotal, discount_amount, total_amount, status, sales_order_items(item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total)",
    )
    .order("sale_date", { ascending: false });

  if (filters.start) {
    orderQuery = orderQuery.gte("sale_date", `${filters.start}T00:00:00`);
  }

  if (filters.end) {
    orderQuery = orderQuery.lte("sale_date", `${filters.end}T23:59:59`);
  }

  if (filters.payment && filters.payment !== "All") {
    orderQuery = orderQuery.eq("payment_method", filters.payment);
  }

  if (filters.status && filters.status !== "All") {
    orderQuery = orderQuery.eq("status", filters.status);
  }

  let marketQuery = supabase
    .from("sales_transactions")
    .select(
      "id, sale_date, customer_name, payment_method, transaction_reference, quantity_sold, unit_price, total_amount, status, inventory(item_name, unit)",
    )
    .order("sale_date", { ascending: false });

  if (filters.start) {
    marketQuery = marketQuery.gte("sale_date", `${filters.start}T00:00:00`);
  }

  if (filters.end) {
    marketQuery = marketQuery.lte("sale_date", `${filters.end}T23:59:59`);
  }

  if (filters.payment && filters.payment !== "All") {
    marketQuery = marketQuery.eq("payment_method", filters.payment);
  }

  if (filters.status && filters.status !== "All") {
    marketQuery = marketQuery.eq("status", filters.status);
  }

  const [ordersResult, marketResultWithReference] = await Promise.all([
    orderQuery.returns<SalesOrderRow[]>(),
    marketQuery.returns<SalesTransactionExportRow[]>(),
  ]);

  const marketResult = isMissingTransactionReferenceColumn(marketResultWithReference.error)
    ? await (() => {
        let fallbackQuery = supabase
          .from("sales_transactions")
          .select(
            "id, sale_date, customer_name, payment_method, quantity_sold, unit_price, total_amount, status, inventory(item_name, unit)",
          )
          .order("sale_date", { ascending: false });

        if (filters.start) {
          fallbackQuery = fallbackQuery.gte("sale_date", `${filters.start}T00:00:00`);
        }

        if (filters.end) {
          fallbackQuery = fallbackQuery.lte("sale_date", `${filters.end}T23:59:59`);
        }

        if (filters.payment && filters.payment !== "All") {
          fallbackQuery = fallbackQuery.eq("payment_method", filters.payment);
        }

        if (filters.status && filters.status !== "All") {
          fallbackQuery = fallbackQuery.eq("status", filters.status);
        }

        return fallbackQuery.returns<SalesTransactionExportRow[]>();
      })()
    : marketResultWithReference;

  const orderRows = (ordersResult.data ?? []).flatMap<ExportSalesRow>((order) =>
    order.sales_order_items.map((item) => ({
      receiptNumber: order.receipt_number,
      saleDate: order.sale_date,
      customerName: order.customer_name ?? "Walk-in customer",
      customerContact: order.customer_contact ?? "",
      paymentMethod: order.payment_method,
      transactionReference: "",
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

  const marketRows = (marketResult.data ?? []).map<ExportSalesRow>((sale) => {
    const inventory = firstRelation(sale.inventory);
    const total = toNumber(sale.total_amount);

    return {
      receiptNumber: `SR-${sale.id.slice(0, 8).toUpperCase()}`,
      saleDate: sale.sale_date,
      customerName: sale.customer_name ?? "Market distribution",
      customerContact: "",
      paymentMethod: sale.payment_method ?? "Not recorded",
      transactionReference: sale.transaction_reference ?? "",
      itemName: inventory?.item_name ?? "Market distribution",
      quantitySold: toNumber(sale.quantity_sold),
      unit: inventory?.unit ?? "unit",
      unitPrice: toNumber(sale.unit_price),
      lineTotal: total,
      receiptSubtotal: total,
      discountAmount: 0,
      receiptTotal: total,
      status: sale.status,
    };
  });

  return [...orderRows, ...marketRows].sort(
    (left, right) => new Date(right.saleDate).getTime() - new Date(left.saleDate).getTime(),
  );
}

export async function getCustomerExportRows(filters: ReportExportFilters = {}) {
  const { customers } = await getCustomersDashboard();
  const search = filters.search?.trim().toLowerCase();

  return customers
    .filter((customer) => {
      if (!search) {
        return true;
      }

      return `${customer.name} ${customer.contact} ${customer.customerType} ${customer.paymentMethods.join(" ")} ${customer.purchasedItems.map((item) => item.itemName).join(" ")}`
        .toLowerCase()
        .includes(search);
    })
    .map<ExportCustomerRow>((customer) => ({
    name: customer.name,
    contact: customer.contact,
    customerType: customer.customerType,
    tags: customer.tags.join(", "),
    location: customer.location,
    receiptCount: customer.receiptCount,
    totalSpent: customer.totalSpent,
    averageSpend: customer.averageSpend,
    lastPurchaseAt: customer.lastPurchaseAt,
    paymentMethods: customer.paymentMethods.join(", "),
    topItems: customer.purchasedItems
      .slice(0, 3)
      .map((item) => item.itemName)
      .join(", "),
    notes: customer.notes,
    }));
}

export async function getStockMovementExportRows(filters: ReportExportFilters = {}) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  let query = supabase
    .from("inventory_transactions")
    .select("transaction_type, quantity, remarks, source, created_at, inventory(item_name, stock_code)")
    .order("created_at", { ascending: false });

  if (filters.start) {
    query = query.gte("created_at", `${filters.start}T00:00:00`);
  }

  if (filters.end) {
    query = query.lte("created_at", `${filters.end}T23:59:59`);
  }

  if (filters.type && filters.type !== "All") {
    query = query.eq("transaction_type", filters.type);
  }

  if (filters.source && filters.source !== "All") {
    query = query.eq("source", filters.source);
  }

  const { data } = await query.returns<StockMovementRow[]>();
  const search = filters.search?.trim().toLowerCase();

  return (data ?? [])
    .map<ExportStockMovementRow>((row) => {
      const inventory = firstRelation(row.inventory);

      return {
        itemName: inventory?.item_name ?? "Unknown item",
        stockCode: inventory?.stock_code ?? "Uncoded",
        movementType: row.transaction_type,
        quantity: toNumber(row.quantity),
        source: row.source ?? "manual",
        remarks: row.remarks ?? "",
        createdAt: row.created_at,
      };
    })
    .filter((row) => {
      if (!search) {
        return true;
      }

      return `${row.itemName} ${row.stockCode} ${row.movementType} ${row.source} ${row.remarks}`
        .toLowerCase()
        .includes(search);
    });
}

export async function getDiscountExportRows(filters: ReportExportFilters = {}) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  let query = supabase
    .from("customer_discounts")
    .select("discount_code, customer_name, discount_type, discount_value, released_at, used_at, status")
    .order("released_at", { ascending: false });

  if (filters.start) {
    query = query.gte("released_at", `${filters.start}T00:00:00`);
  }

  if (filters.end) {
    query = query.lte("released_at", `${filters.end}T23:59:59`);
  }

  if (filters.status && filters.status !== "All") {
    query = query.eq("status", filters.status);
  }

  const { data, error } = await query.returns<DiscountRow[]>();

  if (error) {
    return [];
  }

  const search = filters.search?.trim().toLowerCase();

  return (data ?? [])
    .map<ExportDiscountRow>((row) => ({
      code: row.discount_code,
      customerName: row.customer_name,
      discountType: row.discount_type,
      discountValue: toNumber(row.discount_value),
      releasedAt: row.released_at,
      redeemedAt: row.used_at ?? "",
      status: row.status,
    }))
    .filter((row) => {
      if (!search) {
        return true;
      }

      return `${row.code} ${row.customerName} ${row.discountType} ${row.status}`
        .toLowerCase()
        .includes(search);
    });
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
