import { createSupabaseServerClient } from "@/lib/supabase/server";

export type InventoryItem = {
  id: string;
  stockCode: string;
  itemName: string;
  category: string;
  quantity: number;
  unit: string;
  minimumQuantity: number;
  storageLocation: string;
  unitCost: number | null;
  sellingPrice: number | null;
  updatedAt: string;
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
};

type InventoryRow = {
  id: string;
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

type SaleRow = {
  total_amount: number | string;
  sale_date: string;
  status: string;
};

function toNumber(value: number | string | null | undefined) {
  if (typeof value === "number") {
    return value;
  }

  return Number(value ?? 0);
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
      "id, stock_code, item_name, category, quantity, unit, minimum_quantity, storage_location, unit_cost, selling_price, updated_at",
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

  const items: InventoryItem[] = (inventoryRows ?? []).map((row) => ({
    id: row.id,
    stockCode: row.stock_code ?? "Uncoded",
    itemName: row.item_name,
    category: row.category,
    quantity: toNumber(row.quantity),
    unit: row.unit,
    minimumQuantity: toNumber(row.minimum_quantity),
    storageLocation: row.storage_location ?? "Not set",
    unitCost: row.unit_cost === null ? null : toNumber(row.unit_cost),
    sellingPrice: row.selling_price === null ? null : toNumber(row.selling_price),
    updatedAt: row.updated_at,
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

  const { data: saleRows } = await supabase
    .from("sales_transactions")
    .select("total_amount, sale_date, status")
    .eq("status", "Completed")
    .returns<SaleRow[]>();

  const salesRows = saleRows ?? [];
  const todayIso = startOfTodayIso();
  const monthIso = startOfMonthIso();

  const sales: SalesSummary = {
    salesToday: salesRows
      .filter((sale) => sale.sale_date >= todayIso)
      .reduce((total, sale) => total + toNumber(sale.total_amount), 0),
    salesThisMonth: salesRows
      .filter((sale) => sale.sale_date >= monthIso)
      .reduce((total, sale) => total + toNumber(sale.total_amount), 0),
    completedTransactions: salesRows.length,
  };

  return {
    items,
    summary,
    sales,
    error: null,
  };
}
