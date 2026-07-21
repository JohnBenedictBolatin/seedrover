import { getRoverMonitor } from "@/lib/rover";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type DashboardRange = "day" | "week" | "month" | "year";

export type DashboardPoint = {
  label: string;
  value: number;
};

export type StockMovementPoint = {
  label: string;
  in: number;
  out: number;
  adjustment: number;
};

export type DashboardActivity = {
  id: string;
  label: string;
  detail: string;
  value: string;
  createdAt: string;
  type: "sale" | "stock";
};

export type DashboardRiskItem = {
  id: string;
  itemName: string;
  category: string;
  quantity: number;
  unit: string;
  status: "Out of Stock" | "Critical Stock" | "Low Stock";
};

export type OperationsDashboardData = {
  range: DashboardRange;
  summary: {
    salesInRange: number;
    transactionsInRange: number;
    averageSale: number;
    inventoryValue: number;
    estimatedSalesValue: number;
    lowStockItems: number;
    outOfStockItems: number;
    totalCustomers: number;
    activeCrops: number;
    cropsNeedingAttention: number;
    roverStatus: string;
  };
  insights: {
    bestSellingItem: string;
    strongestCategory: string;
    preferredPaymentMethod: string;
    stockWarning: string;
    cropWarning: string;
    roverWarning: string;
  };
  charts: {
    salesTrend: DashboardPoint[];
    salesByCategory: DashboardPoint[];
    stockValueByCategory: DashboardPoint[];
    stockMovement: StockMovementPoint[];
    paymentMethods: DashboardPoint[];
    topItems: DashboardPoint[];
    cropStatus: DashboardPoint[];
    roverSensors: DashboardPoint[];
  };
  recentActivity: DashboardActivity[];
  lowStock: DashboardRiskItem[];
  error: string | null;
};

type InventoryRow = {
  id: string;
  item_name: string;
  category: string | null;
  quantity: number | string;
  unit: string;
  minimum_quantity: number | string;
  unit_cost: number | string | null;
  selling_price: number | string | null;
};

type SalesOrderRow = {
  id: string;
  receipt_number: string;
  sale_date: string;
  customer_name: string | null;
  payment_method: string;
  total_amount: number | string;
  status: string;
  sales_order_items?: Array<{
    item_name_snapshot: string;
    quantity_sold: number | string;
    line_total: number | string;
    inventory?: { category: string | null } | { category: string | null }[] | null;
  }>;
};

type MarketSaleRow = {
  id: string;
  sale_date: string;
  customer_name: string | null;
  payment_method?: string | null;
  quantity_sold: number | string;
  total_amount: number | string;
  status: string;
  inventory: {
    item_name: string;
    category: string | null;
  } | {
    item_name: string;
    category: string | null;
  }[] | null;
};

type TransactionRow = {
  id: string;
  transaction_type: "IN" | "OUT" | "ADJUSTMENT";
  quantity: number | string;
  remarks: string | null;
  source: string | null;
  created_at: string;
  inventory: {
    item_name: string;
    unit: string;
  } | {
    item_name: string;
    unit: string;
  }[] | null;
};

type CropRow = {
  crop_status: string;
  growth_stage: string;
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

export function normalizeDashboardRange(value: string | string[] | undefined): DashboardRange {
  const range = Array.isArray(value) ? value[0] : value;

  if (range === "day" || range === "week" || range === "year") {
    return range;
  }

  return "month";
}

function rangeStart(range: DashboardRange) {
  const date = new Date();

  if (range === "day") {
    date.setHours(0, 0, 0, 0);
    return date;
  }

  if (range === "week") {
    date.setDate(date.getDate() - 6);
    date.setHours(0, 0, 0, 0);
    return date;
  }

  if (range === "year") {
    date.setMonth(0, 1);
    date.setHours(0, 0, 0, 0);
    return date;
  }

  date.setDate(1);
  date.setHours(0, 0, 0, 0);
  return date;
}

function bucketLabel(value: string, range: DashboardRange) {
  const date = new Date(value);

  if (range === "day") {
    return new Intl.DateTimeFormat("en-PH", {
      hour: "numeric",
    }).format(date);
  }

  if (range === "year") {
    return new Intl.DateTimeFormat("en-PH", {
      month: "short",
    }).format(date);
  }

  return new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
  }).format(date);
}

function addToMap(map: Map<string, number>, key: string, value: number) {
  map.set(key, (map.get(key) ?? 0) + value);
}

function rankedPoints(map: Map<string, number>, limit = 6, ascending = false) {
  return [...map.entries()]
    .sort((left, right) => (ascending ? left[1] - right[1] : right[1] - left[1]))
    .slice(0, limit)
    .map<DashboardPoint>(([label, value]) => ({ label, value }));
}

function stockStatus(row: InventoryRow): DashboardRiskItem["status"] | "In Stock" {
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

function customerKey(name: string | null | undefined) {
  const normalized = (name ?? "").trim().toLowerCase();

  if (!normalized || normalized === "walk-in customer" || normalized === "market distribution") {
    return "";
  }

  return normalized;
}

function emptyData(range: DashboardRange, error: string | null): OperationsDashboardData {
  return {
    range,
    summary: {
      salesInRange: 0,
      transactionsInRange: 0,
      averageSale: 0,
      inventoryValue: 0,
      estimatedSalesValue: 0,
      lowStockItems: 0,
      outOfStockItems: 0,
      totalCustomers: 0,
      activeCrops: 0,
      cropsNeedingAttention: 0,
      roverStatus: "Unknown",
    },
    insights: {
      bestSellingItem: "No sales yet",
      strongestCategory: "No category sales yet",
      preferredPaymentMethod: "Not recorded",
      stockWarning: "No stock records connected yet",
      cropWarning: "No crop records connected yet",
      roverWarning: "No active rover status",
    },
    charts: {
      salesTrend: [],
      salesByCategory: [],
      stockValueByCategory: [],
      stockMovement: [],
      paymentMethods: [],
      topItems: [],
      cropStatus: [],
      roverSensors: [],
    },
    recentActivity: [],
    lowStock: [],
    error,
  };
}

export async function getOperationsDashboard(range: DashboardRange) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return emptyData(range, "Supabase is not configured.");
  }

  const start = rangeStart(range);
  const startIso = start.toISOString();

  const [
    inventoryResult,
    transactionsResult,
    ordersResult,
    marketResultWithPayment,
    cropsResult,
    roverResult,
  ] = await Promise.all([
    supabase
      .from("inventory")
      .select("id, item_name, category, quantity, unit, minimum_quantity, unit_cost, selling_price")
      .order("item_name", { ascending: true })
      .returns<InventoryRow[]>(),
    supabase
      .from("inventory_transactions")
      .select("id, transaction_type, quantity, remarks, source, created_at, inventory(item_name, unit)")
      .gte("created_at", startIso)
      .order("created_at", { ascending: false })
      .limit(160)
      .returns<TransactionRow[]>(),
    supabase
      .from("sales_orders")
      .select(
        "id, receipt_number, sale_date, customer_name, payment_method, total_amount, status, sales_order_items(item_name_snapshot, quantity_sold, line_total, inventory(category))",
      )
      .gte("sale_date", startIso)
      .order("sale_date", { ascending: false })
      .limit(180)
      .returns<SalesOrderRow[]>(),
    supabase
      .from("sales_transactions")
      .select("id, sale_date, customer_name, payment_method, quantity_sold, total_amount, status, inventory(item_name, category)")
      .gte("sale_date", startIso)
      .order("sale_date", { ascending: false })
      .limit(180)
      .returns<MarketSaleRow[]>(),
    supabase
      .from("crops")
      .select("crop_status, growth_stage")
      .returns<CropRow[]>(),
    getRoverMonitor(),
  ]);

  const marketResult = isMissingPaymentMethodColumn(marketResultWithPayment.error)
    ? await supabase
        .from("sales_transactions")
        .select("id, sale_date, customer_name, quantity_sold, total_amount, status, inventory(item_name, category)")
        .gte("sale_date", startIso)
        .order("sale_date", { ascending: false })
        .limit(180)
        .returns<MarketSaleRow[]>()
    : marketResultWithPayment;

  if (inventoryResult.error) {
    return emptyData(range, inventoryResult.error.message);
  }

  const inventoryRows = inventoryResult.data ?? [];
  const orderRows = ordersResult.error ? [] : ordersResult.data ?? [];
  const marketRows = marketResult.error ? [] : marketResult.data ?? [];
  const transactionRows = transactionsResult.error ? [] : transactionsResult.data ?? [];
  const cropRows = cropsResult.error ? [] : cropsResult.data ?? [];

  const stockValueByCategory = new Map<string, number>();
  const lowStock: DashboardRiskItem[] = [];
  let inventoryValue = 0;
  let estimatedSalesValue = 0;

  for (const row of inventoryRows) {
    const quantity = toNumber(row.quantity);
    const unitCost = toNumber(row.unit_cost);
    const sellingPrice = toNumber(row.selling_price);
    const category = row.category ?? "Uncategorized";
    const value = quantity * unitCost;
    const status = stockStatus(row);

    inventoryValue += value;
    estimatedSalesValue += quantity * sellingPrice;
    addToMap(stockValueByCategory, category, value);

    if (status !== "In Stock") {
      lowStock.push({
        id: row.id,
        itemName: row.item_name,
        category,
        quantity,
        unit: row.unit,
        status,
      });
    }
  }

  const salesTrend = new Map<string, number>();
  const salesByCategory = new Map<string, number>();
  const paymentMethods = new Map<string, number>();
  const topItems = new Map<string, number>();
  const customers = new Set<string>();
  let salesInRange = 0;
  let transactionsInRange = 0;

  const recentActivity: DashboardActivity[] = [];

  for (const order of orderRows) {
    if (order.status !== "Completed") {
      continue;
    }

    const total = toNumber(order.total_amount);
    const items = order.sales_order_items ?? [];

    salesInRange += total;
    transactionsInRange += 1;
    addToMap(salesTrend, bucketLabel(order.sale_date, range), total);
    addToMap(paymentMethods, order.payment_method, total);

    const key = customerKey(order.customer_name);
    if (key) {
      customers.add(key);
    }

    recentActivity.push({
      id: order.id,
      label: order.receipt_number,
      detail: order.customer_name ?? "Walk-in customer",
      value: total.toString(),
      createdAt: order.sale_date,
      type: "sale",
    });

    for (const item of items) {
      const category = firstRelation(item.inventory)?.category ?? "Uncategorized";
      const lineTotal = toNumber(item.line_total);
      addToMap(salesByCategory, category, lineTotal);
      addToMap(topItems, item.item_name_snapshot, toNumber(item.quantity_sold));
    }
  }

  for (const sale of marketRows) {
    if (sale.status !== "Completed") {
      continue;
    }

    const total = toNumber(sale.total_amount);
    const inventory = firstRelation(sale.inventory);
    const itemName = inventory?.item_name ?? "Market distribution";
    const category = inventory?.category ?? "Market Distribution";
    const paymentMethod = sale.payment_method ?? "Not recorded";

    salesInRange += total;
    transactionsInRange += 1;
    addToMap(salesTrend, bucketLabel(sale.sale_date, range), total);
    addToMap(paymentMethods, paymentMethod, total);
    addToMap(salesByCategory, category, total);
    addToMap(topItems, itemName, toNumber(sale.quantity_sold));

    const key = customerKey(sale.customer_name);
    if (key) {
      customers.add(key);
    }

    recentActivity.push({
      id: sale.id,
      label: `SR-${sale.id.slice(0, 8).toUpperCase()}`,
      detail: sale.customer_name ?? "Market distribution",
      value: total.toString(),
      createdAt: sale.sale_date,
      type: "sale",
    });
  }

  const stockMovementMap = new Map<string, StockMovementPoint>();

  for (const transaction of transactionRows) {
    const label = bucketLabel(transaction.created_at, range);
    const current = stockMovementMap.get(label) ?? {
      label,
      in: 0,
      out: 0,
      adjustment: 0,
    };
    const quantity = toNumber(transaction.quantity);

    if (transaction.transaction_type === "IN") {
      current.in += quantity;
    } else if (transaction.transaction_type === "OUT") {
      current.out += quantity;
    } else {
      current.adjustment += quantity;
    }

    stockMovementMap.set(label, current);

    const item = firstRelation(transaction.inventory);
    recentActivity.push({
      id: transaction.id,
      label: transaction.transaction_type,
      detail: `${item?.item_name ?? "Inventory item"} · ${transaction.source ?? "manual"}`,
      value: `${quantity} ${item?.unit ?? ""}`.trim(),
      createdAt: transaction.created_at,
      type: "stock",
    });
  }

  const cropStatus = new Map<string, number>();
  for (const crop of cropRows) {
    addToMap(cropStatus, crop.crop_status || "Uncategorized", 1);
  }

  const roverSensors = roverResult.sensors
    ? [
        { label: "Soil moisture", value: roverResult.sensors.soilMoisture },
        { label: "Soil temp", value: roverResult.sensors.soilTemperature },
        { label: "Humidity", value: roverResult.sensors.humidity },
        { label: "Environment", value: roverResult.sensors.environmentalTemperature },
      ]
    : [];

  const sortedRecentActivity = recentActivity
    .sort((left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime())
    .slice(0, 8);
  const topItemPoints = rankedPoints(topItems, 6);
  const salesByCategoryPoints = rankedPoints(salesByCategory, 6);
  const paymentPoints = rankedPoints(paymentMethods, 5);
  const activeCrops = cropRows.filter((crop) => crop.crop_status === "Active").length;
  const cropsNeedingAttention = cropRows.filter((crop) => crop.crop_status === "Needs Attention").length;
  const outOfStockItems = lowStock.filter((item) => item.status === "Out of Stock").length;

  return {
    range,
    summary: {
      salesInRange,
      transactionsInRange,
      averageSale: transactionsInRange > 0 ? salesInRange / transactionsInRange : 0,
      inventoryValue,
      estimatedSalesValue,
      lowStockItems: lowStock.length,
      outOfStockItems,
      totalCustomers: customers.size,
      activeCrops,
      cropsNeedingAttention,
      roverStatus: roverResult.status?.roverStatus ?? "Unknown",
    },
    insights: {
      bestSellingItem: topItemPoints[0]?.label ?? "No sales yet",
      strongestCategory: salesByCategoryPoints[0]?.label ?? "No category sales yet",
      preferredPaymentMethod: paymentPoints[0]?.label ?? "Not recorded",
      stockWarning:
        lowStock.length > 0
          ? `${lowStock.length} item${lowStock.length === 1 ? "" : "s"} need stock attention`
          : "Stock levels look stable",
      cropWarning:
        cropsNeedingAttention > 0
          ? `${cropsNeedingAttention} crop${cropsNeedingAttention === 1 ? "" : "s"} need attention`
          : "Crop records look stable",
      roverWarning: roverResult.status
        ? `${roverResult.status.roverStatus} · ${roverResult.status.currentActivity}`
        : "No active rover status",
    },
    charts: {
      salesTrend: [...salesTrend.entries()].map(([label, value]) => ({ label, value })),
      salesByCategory: salesByCategoryPoints,
      stockValueByCategory: rankedPoints(stockValueByCategory, 6),
      stockMovement: [...stockMovementMap.values()],
      paymentMethods: paymentPoints,
      topItems: topItemPoints,
      cropStatus: rankedPoints(cropStatus, 6),
      roverSensors,
    },
    recentActivity: sortedRecentActivity,
    lowStock: lowStock.slice(0, 6),
    error:
      ordersResult.error?.message ??
      marketResult.error?.message ??
      transactionsResult.error?.message ??
      cropsResult.error?.message ??
      roverResult.error ??
      null,
  } satisfies OperationsDashboardData;
}
