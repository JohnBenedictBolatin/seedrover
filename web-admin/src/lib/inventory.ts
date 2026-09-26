import { createSupabaseServerClient } from "@/lib/supabase/server";

export const INVENTORY_UNIT = "kg" as const;

export type InventoryItem = {
  id: string;
  stockCode: string;
  itemName: string;
  category: string;
  notes: string;
  quantity: number;
  unit: typeof INVENTORY_UNIT;
  minimumQuantity: number;
  storageLocation: string;
  unitCost: number | null;
  sellingPrice: number | null;
  imageUrl: string | null;
  imagePath: string | null;
  updatedAt: string;
  createdAt: string;
  transactions: InventoryTransaction[];
  sales: InventorySale[];
};

export type InventorySummary = {
  totalItems: number;
  lowStockItems: number;
  outOfStockItems: number;
  inventoryValue: number;
  estimatedSalesValue: number;
};

export type SalesSummary = {
  salesToday: number;
  salesThisMonth: number;
  completedTransactions: number;
  bestSellingItem: string;
};

export type InventoryTransaction = {
  id: string;
  inventoryId: string;
  type: "IN" | "OUT" | "ADJUSTMENT";
  quantity: number;
  remarks: string;
  source: string;
  createdAt: string;
};

export type InventorySale = {
  id: string;
  inventoryId: string;
  quantitySold: number;
  unitPrice: number;
  totalAmount: number;
  saleDate: string;
  customerName: string | null;
  customerContact: string | null;
  paymentMethod: string;
  remarks: string | null;
  status: string;
};

type InventoryRow = {
  id: string;
  stock_code: string | null;
  item_name: string;
  category: string;
  notes: string | null;
  quantity: number | string;
  unit: string;
  minimum_quantity: number | string;
  storage_location: string | null;
  unit_cost: number | string | null;
  selling_price: number | string | null;
  image_path: string | null;
  updated_at: string;
  created_at: string;
};

type SaleRow = {
  id?: string;
  inventory_id?: string;
  quantity_sold?: number | string;
  unit_price?: number | string;
  total_amount: number | string;
  sale_date: string;
  customer_name?: string | null;
  customer_contact?: string | null;
  payment_method?: string | null;
  other_payment_method?: string | null;
  remarks?: string | null;
  status: string;
};

type ReceiptItemSaleRow = {
  id: string;
  inventory_id: string;
  quantity_sold: number | string;
  unit_price: number | string;
  line_total: number | string;
  sales_orders:
    | {
        sale_date: string;
        customer_name: string | null;
        customer_contact: string | null;
        payment_method: string;
        other_payment_method: string | null;
        remarks: string | null;
        status: string;
      }
    | {
        sale_date: string;
        customer_name: string | null;
        customer_contact: string | null;
        payment_method: string;
        other_payment_method: string | null;
        remarks: string | null;
        status: string;
      }[]
    | null;
};

type SalesOrderItemSummaryRow = {
  quantity_sold: number | string;
  item_name_snapshot: string;
  sales_orders:
    | {
        status: string;
      }
    | {
        status: string;
      }[]
    | null;
};

type SalesOrderTotalRow = {
  total_amount: number | string;
  sale_date: string;
  status: string;
};

type TransactionRow = {
  id: string;
  inventory_id: string;
  transaction_type: "IN" | "OUT" | "ADJUSTMENT";
  quantity: number | string;
  remarks: string | null;
  source: string | null;
  created_at: string;
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

function isMissingPaymentMethodColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.payment_method") ?? false;
}

function isMissingOtherPaymentMethodColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.other_payment_method") ?? false;
}

function displayPaymentMethod(method: string | null | undefined, otherMethod?: string | null) {
  if (method === "Other" && otherMethod) {
    return `Other - ${otherMethod}`;
  }

  return method ?? "Not recorded";
}

function startOfTodayIso() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date.toISOString();
}

function startOfMonthIso() {
  const date = new Date();
  date.setDate(1);
  date.setHours(0, 0, 0, 0);
  return date.toISOString();
}

export function stockStatus(item: InventoryItem) {
  if (item.quantity <= 0) {
    return "Out of Stock";
  }

  if (item.quantity <= item.minimumQuantity * 0.5) {
    return "Critical Stock";
  }

  if (item.quantity <= item.minimumQuantity) {
    return "Low Stock";
  }

  return "In Stock";
}

export async function getInventoryDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      items: [],
      summary: null,
      sales: null,
      error: "Supabase is not configured.",
    };
  }

  const { data: inventoryRows, error: inventoryError } = await supabase
    .from("inventory")
    .select(
      "id, stock_code, item_name, category, quantity, unit, minimum_quantity, storage_location, unit_cost, selling_price, image_path, notes, created_at, updated_at",
    )
    .order("item_name", { ascending: true })
    .returns<InventoryRow[]>();

  if (inventoryError) {
    return {
      items: [],
      summary: null,
      sales: null,
      error: inventoryError.message,
    };
  }

  const inventoryIds = (inventoryRows ?? []).map((row) => row.id);

  const { data: transactionRows } = inventoryIds.length
    ? await supabase
        .from("inventory_transactions")
        .select("id, inventory_id, transaction_type, quantity, remarks, source, created_at")
        .in("inventory_id", inventoryIds)
        .order("created_at", { ascending: false })
        .returns<TransactionRow[]>()
    : { data: [] };

  let itemSaleRows: SaleRow[] = [];

  if (inventoryIds.length) {
    const itemSalesResultWithPayment = await supabase
      .from("sales_transactions")
      .select(
        "id, inventory_id, quantity_sold, unit_price, total_amount, sale_date, customer_name, customer_contact, payment_method, other_payment_method, remarks, status",
      )
      .in("inventory_id", inventoryIds)
      .order("sale_date", { ascending: false })
      .returns<SaleRow[]>();

    const itemSalesResult = isMissingPaymentMethodColumn(itemSalesResultWithPayment.error)
      ? await supabase
          .from("sales_transactions")
          .select(
            "id, inventory_id, quantity_sold, unit_price, total_amount, sale_date, customer_name, remarks, status",
          )
          .in("inventory_id", inventoryIds)
          .order("sale_date", { ascending: false })
          .returns<SaleRow[]>()
      : isMissingOtherPaymentMethodColumn(itemSalesResultWithPayment.error)
        ? await supabase
            .from("sales_transactions")
            .select(
              "id, inventory_id, quantity_sold, unit_price, total_amount, sale_date, customer_name, payment_method, remarks, status",
            )
            .in("inventory_id", inventoryIds)
            .order("sale_date", { ascending: false })
            .returns<SaleRow[]>()
      : itemSalesResultWithPayment;

    itemSaleRows = itemSalesResult.data ?? [];

    const { data: receiptItemRows } = await supabase
      .from("sales_order_items")
      .select(
        "id, inventory_id, quantity_sold, unit_price, line_total, sales_orders!inner(sale_date, customer_name, customer_contact, payment_method, other_payment_method, remarks, status)",
      )
      .in("inventory_id", inventoryIds)
      .returns<ReceiptItemSaleRow[]>();

    for (const row of receiptItemRows ?? []) {
      const order = firstRelation(row.sales_orders);
      if (!order) continue;
      itemSaleRows.push({
        id: row.id,
        inventory_id: row.inventory_id,
        quantity_sold: row.quantity_sold,
        unit_price: row.unit_price,
        total_amount: row.line_total,
        sale_date: order.sale_date,
        customer_name: order.customer_name,
        customer_contact: order.customer_contact,
        payment_method: order.payment_method,
        other_payment_method: order.other_payment_method,
        remarks: order.remarks,
        status: order.status,
      });
    }
  }

  const transactionsByItem = new Map<string, InventoryTransaction[]>();
  for (const row of transactionRows ?? []) {
    const transaction: InventoryTransaction = {
      id: row.id,
      inventoryId: row.inventory_id,
      type: row.transaction_type,
      quantity: toNumber(row.quantity),
      remarks: row.remarks ?? "No remarks.",
      source: row.source ?? "manual",
      createdAt: row.created_at,
    };

    transactionsByItem.set(row.inventory_id, [
      ...(transactionsByItem.get(row.inventory_id) ?? []),
      transaction,
    ]);
  }

  const salesByItem = new Map<string, InventorySale[]>();
  for (const row of itemSaleRows) {
    if (!row.id || !row.inventory_id) {
      continue;
    }

    const sale: InventorySale = {
      id: row.id,
      inventoryId: row.inventory_id,
      quantitySold: toNumber(row.quantity_sold),
      unitPrice: toNumber(row.unit_price),
      totalAmount: toNumber(row.total_amount),
      saleDate: row.sale_date,
      customerName: row.customer_name ?? null,
      customerContact: row.customer_contact ?? null,
      paymentMethod: displayPaymentMethod(row.payment_method, row.other_payment_method),
      remarks: row.remarks ?? null,
      status: row.status,
    };

    salesByItem.set(row.inventory_id, [
      ...(salesByItem.get(row.inventory_id) ?? []),
      sale,
    ]);
  }

  for (const itemSales of salesByItem.values()) {
    itemSales.sort(
      (a, b) => new Date(b.saleDate).getTime() - new Date(a.saleDate).getTime(),
    );
  }

  const items: InventoryItem[] = (inventoryRows ?? []).map((row) => ({
    id: row.id,
    stockCode: row.stock_code ?? "Uncoded",
    itemName: row.item_name,
    category: row.category,
    notes: row.notes ?? '',
    quantity: toNumber(row.quantity),
    unit: INVENTORY_UNIT,
    minimumQuantity: toNumber(row.minimum_quantity),
    storageLocation: row.storage_location ?? "Not set",
    unitCost: row.unit_cost === null ? null : toNumber(row.unit_cost),
    sellingPrice: row.selling_price === null ? null : toNumber(row.selling_price),
    imagePath: row.image_path,
    imageUrl:
      row.image_path === null
        ? null
        : supabase.storage.from("stock-images").getPublicUrl(row.image_path).data
            .publicUrl,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    transactions: transactionsByItem.get(row.id) ?? [],
    sales: salesByItem.get(row.id) ?? [],
  }));

  const summary: InventorySummary = {
    totalItems: items.length,
    lowStockItems: items.filter((item) =>
      ["Low Stock", "Critical Stock"].includes(stockStatus(item)),
    ).length,
    outOfStockItems: items.filter((item) => stockStatus(item) === "Out of Stock")
      .length,
    inventoryValue: items.reduce(
      (total, item) => total + item.quantity * (item.unitCost ?? 0),
      0,
    ),
    estimatedSalesValue: items.reduce(
      (total, item) => total + item.quantity * (item.sellingPrice ?? 0),
      0,
    ),
  };

  const [{ data: saleRows }, { data: orderItemRows }, { data: orderRows }] = await Promise.all([
    supabase
      .from("sales_transactions")
      .select("total_amount, sale_date, status, inventory_id, quantity_sold")
      .order("sale_date", { ascending: false })
      .limit(120)
      .returns<SaleRow[]>(),
    supabase
      .from("sales_order_items")
      .select("quantity_sold, item_name_snapshot, sales_orders(status)")
      .returns<SalesOrderItemSummaryRow[]>(),
    supabase
      .from("sales_orders")
      .select("total_amount, sale_date, status")
      .order("sale_date", { ascending: false })
      .limit(120)
      .returns<SalesOrderTotalRow[]>(),
  ]);

  const salesRows = saleRows ?? [];
  const completedOrderRows = (orderRows ?? []).filter((order) => order.status === "Completed");
  const todayIso = startOfTodayIso();
  const monthIso = startOfMonthIso();
  const itemTotals = new Map<string, number>();

  for (const sale of salesRows) {
    if (sale.status !== "Completed" || !sale.inventory_id) {
      continue;
    }

    const matchingItem = items.find((item) => item.id === sale.inventory_id);

    if (!matchingItem) {
      continue;
    }

    itemTotals.set(
      matchingItem.itemName,
      (itemTotals.get(matchingItem.itemName) ?? 0) + toNumber(sale.quantity_sold),
    );
  }

  for (const row of orderItemRows ?? []) {
    const order = firstRelation(row.sales_orders);

    if (order?.status !== "Completed") {
      continue;
    }

    itemTotals.set(
      row.item_name_snapshot,
      (itemTotals.get(row.item_name_snapshot) ?? 0) + toNumber(row.quantity_sold),
    );
  }

  const bestSellingItem =
    [...itemTotals.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? "No sales yet";

  const sales: SalesSummary = {
    salesToday: [...salesRows, ...completedOrderRows]
      .filter((sale) => sale.status === "Completed" && sale.sale_date >= todayIso)
      .reduce((total, sale) => total + toNumber(sale.total_amount), 0),
    salesThisMonth: [...salesRows, ...completedOrderRows]
      .filter((sale) => sale.status === "Completed" && sale.sale_date >= monthIso)
      .reduce((total, sale) => total + toNumber(sale.total_amount), 0),
    completedTransactions: salesRows.filter((sale) => sale.status === "Completed").length + completedOrderRows.length,
    bestSellingItem,
  };

  return {
    items,
    summary,
    sales,
    error: null,
  };
}
