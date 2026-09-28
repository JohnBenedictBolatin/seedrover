import { INVENTORY_UNIT } from "@/lib/inventory";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type SellableItem = {
  id: string;
  label: string;
  stockCode: string;
  quantity: number;
  unit: string;
  sellingPrice: number;
};

export type ReleasedDiscount = {
  code: string;
  customerName: string;
  customerContact: string;
  discountType: "Amount" | "Percent";
  discountValue: number;
  validUntil: string | null;
};

export type RecentSalesOrder = {
  id: string;
  receiptNumber: string;
  saleDate: string;
  customerName: string;
  customerContact?: string;
  paymentMethod: string;
  transactionReference?: string | null;
  otherPaymentMethod?: string | null;
  itemCount?: number;
  receiptItems?: SalesReceiptItem[];
  marketItemName?: string;
  marketItemUnit?: string;
  marketQuantitySold?: number;
  marketUnitPrice?: number;
  marketRemarks?: string;
  remarks?: string | null;
  voidReason?: string | null;
  discountAmount?: number;
  totalAmount: number;
  status: string;
  source?: "receipt" | "market" | "payment" | "reversal";
  entryLabel?: string;
  paymentAmount?: number;
  relatedSaleId?: string;
  amountPaid?: number;
  installmentStatus?: "Active" | "Completed" | "Cancelled";
  paymentReceiptId?: string;
  reversalReason?: string | null;
};

export type SalesSummary = {
  salesToday: number;
  salesThisMonth: number;
  collectedToday: number;
  collectedThisMonth: number;
  transactions: number;
  completedSalesCount: number;
  averageTransactionValue: number;
  bestSellingItem: string;
  totalDiscountGiven: number;
};

export type SalesAnalyticsPoint = {
  label: string;
  value: number;
};

export type SalesAnalytics = {
  dailySales: SalesAnalyticsPoint[];
  salesByCategory: SalesAnalyticsPoint[];
  paymentMethods: SalesAnalyticsPoint[];
  topItems: SalesAnalyticsPoint[];
  lowPerformingItems: SalesAnalyticsPoint[];
  discountImpact: SalesAnalyticsPoint[];
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
  transactionReference?: string | null;
  otherPaymentMethod?: string | null;
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

export type InstallmentCollectionEvent = {
  id: string;
  paymentReceiptId: string;
  salesOrderId: string;
  receiptNumber: string;
  saleReceiptNumber: string;
  customerName: string;
  paymentDate: string;
  paymentMethod: string;
  transactionReference: string | null;
  paymentAmount: number;
  collectionType: "down_payment" | "installment";
  installmentNumber: number | null;
  installmentCount: number;
  saleStatus: string;
  isReversal: boolean;
  reversalReason: string | null;
};

type SellableRow = {
  id: string;
  stock_code: string | null;
  item_name: string;
  quantity: number | string;
  unit: string;
  selling_price: number | string | null;
};

type ReleasedDiscountRow = {
  discount_code: string;
  customer_name: string;
  customer_contact: string | null;
  discount_type: "Amount" | "Percent";
  discount_value: number | string;
  valid_until: string | null;
};

type RecentSalesOrderRow = {
  id: string;
  receipt_number: string;
  sale_date: string;
  customer_name: string | null;
  customer_contact?: string | null;
  payment_method: string;
  transaction_reference?: string | null;
  other_payment_method?: string | null;
  discount_amount?: number | string;
  total_amount: number | string;
  amount_paid?: number | string | null;
  change_amount?: number | string | null;
  remarks?: string | null;
  void_reason?: string | null;
  status: string;
  sales_order_items?: Array<{
    id: string;
    item_name_snapshot: string;
    unit_snapshot?: string | null;
    quantity_sold: number | string;
    unit_price?: number | string | null;
    line_total: number | string;
    inventory?: { category: string | null } | { category: string | null }[] | null;
  }>;
};

type InstallmentPlanStatusRow = {
  sales_order_id: string;
  status: "Active" | "Completed" | "Cancelled";
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
  transaction_reference?: string | null;
  other_payment_method?: string | null;
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

type StandaloneSalesRow = {
  id: string;
  sale_date: string;
  customer_name: string | null;
  payment_method?: string | null;
  transaction_reference?: string | null;
  other_payment_method?: string | null;
  void_reason?: string | null;
  quantity_sold: number | string;
  unit_price: number | string;
  total_amount: number | string;
  remarks?: string | null;
  status: string;
  inventory: {
    item_name: string;
    unit?: string | null;
    category: string | null;
  } | {
    item_name: string;
    unit?: string | null;
    category: string | null;
  }[] | null;
};

type InstallmentPlanLinkRow = {
  id: string;
  sales_order_id: string;
  receipt_number: string;
  customer_name: string;
};

type InstallmentCollectionRow = {
  id: string;
  collection_group_id: string;
  collection_type: "down_payment" | "installment";
  plan_id: string;
  schedule_id: string;
  amount: number | string;
  payment_date: string;
  payment_method: string;
  transaction_reference: string | null;
  other_payment_method: string | null;
};

type InstallmentScheduleLinkRow = {
  id: string;
  plan_id: string;
  installment_number: number;
};

type SalesOrderStatusRow = { id: string; status: string };

function toNumber(value: number | string | null | undefined) {
  if (typeof value === "number") {
    return value;
  }

  return Number(value ?? 0);
}

async function fetchAllPages<T>(
  fetchPage: (from: number, to: number) => PromiseLike<{
    data: T[] | null;
    error: { message: string } | null;
  }>,
) {
  const rows: T[] = [];
  for (let from = 0; ; from += 1000) {
    const result = await fetchPage(from, from + 999);
    if (result.error) return { data: null, error: result.error };
    const page = result.data ?? [];
    rows.push(...page);
    if (page.length < 1000) break;
  }
  return { data: rows, error: null };
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
      unit: INVENTORY_UNIT,
      sellingPrice: toNumber(row.selling_price),
    })),
    error: null,
  };
}

export async function getReleasedDiscounts() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      discounts: [] as ReleasedDiscount[],
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("customer_discounts")
    .select("discount_code, customer_name, customer_contact, discount_type, discount_value, valid_until")
    .eq("status", "Released")
    .order("created_at", { ascending: false })
    .returns<ReleasedDiscountRow[]>();

  if (error) {
    if (error.message.includes("customer_discounts") || error.message.includes("schema cache")) {
      return { discounts: [], error: null };
    }

    return { discounts: [], error: error.message };
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return {
    discounts: (data ?? [])
      .filter((discount) => {
        if (!discount.valid_until) {
          return true;
        }

        return new Date(`${discount.valid_until}T23:59:59`).getTime() >= today.getTime();
      })
      .map<ReleasedDiscount>((discount) => ({
        code: discount.discount_code,
        customerName: discount.customer_name,
        customerContact: discount.customer_contact ?? "",
        discountType: discount.discount_type,
        discountValue: toNumber(discount.discount_value),
        validUntil: discount.valid_until,
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

function startOfToday() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date;
}

function startOfMonth() {
  const date = new Date();
  date.setDate(1);
  date.setHours(0, 0, 0, 0);
  return date;
}

function dateKey(value: string) {
  return new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
  }).format(new Date(value));
}

function addToMap(map: Map<string, number>, key: string, value: number) {
  map.set(key, (map.get(key) ?? 0) + value);
}

function topMapEntries(map: Map<string, number>, limit: number, ascending = false) {
  return [...map.entries()]
    .sort((a, b) => ascending ? a[1] - b[1] : b[1] - a[1])
    .slice(0, limit)
    .map<SalesAnalyticsPoint>(([label, value]) => ({ label, value }));
}

function firstRelation<T>(value: T | T[] | null | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

function isMissingPaymentMethodColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.payment_method") ?? false;
}

function isMissingTransactionReferenceColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.transaction_reference") ?? false;
}

function isMissingOtherPaymentMethodColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("other_payment_method") ?? false;
}

function isMissingSalesOrderPaymentDetailColumn(error: { message?: string } | null | undefined) {
  return (
    error?.message?.includes("sales_orders.transaction_reference") ||
    error?.message?.includes("sales_orders.other_payment_method")
  ) ?? false;
}

function displayPaymentMethod(method: string | null | undefined, otherMethod?: string | null) {
  if (method === "Other" && otherMethod) {
    return `Other - ${otherMethod}`;
  }

  return method ?? "Not recorded";
}

function manilaDate(timestamp: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Manila",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(timestamp));
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((item) => item.type === type)?.value ?? "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export async function getInstallmentCollectionEvents() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { events: [] as InstallmentCollectionEvent[], error: "Supabase is not configured." };
  const collectionResult = await fetchAllPages((from, to) => supabase
    .from("installment_collections")
    .select("id, receipt_number, sales_order_id, plan_id, collection_type, amount, payment_date, payment_method, transaction_reference, other_payment_method, installment_plans(customer_name, receipt_number), sales_orders(status)")
    .order("payment_date", { ascending: false })
    .range(from, to));
  const collections = collectionResult.data;
  const error = collectionResult.error;
  if (error) return { events: [] as InstallmentCollectionEvent[], error: error.message };
  if (!collections?.length) return { events: [] as InstallmentCollectionEvent[], error: null };
  const ids = collections.map((collection) => collection.id);
  const reversals = [] as Array<{ id: string; collection_id: string; receipt_number: string; reason: string; balance_after: number | string; reversed_at: string }>;
  for (let index = 0; index < ids.length; index += 500) {
    const { data, error: reversalsError } = await supabase
      .from("installment_collection_reversals")
      .select("id, collection_id, receipt_number, reason, balance_after, reversed_at")
      .in("collection_id", ids.slice(index, index + 500));
    if (reversalsError) return { events: [] as InstallmentCollectionEvent[], error: reversalsError.message };
    reversals.push(...((data ?? []) as typeof reversals));
  }
  const reversalByCollection = new Map((reversals ?? []).map((reversal) => [reversal.collection_id, reversal]));
  const events = collections.flatMap<InstallmentCollectionEvent>((raw) => {
    const row = raw as unknown as {
      id: string; receipt_number: string; sales_order_id: string; plan_id: string;
      collection_type: "down_payment" | "installment"; amount: number | string; payment_date: string;
      payment_method: string; transaction_reference: string | null; other_payment_method: string | null;
      installment_plans: { customer_name: string; receipt_number: string } | { customer_name: string; receipt_number: string }[] | null;
      sales_orders: { status: string } | { status: string }[] | null;
    };
    const plan = Array.isArray(row.installment_plans) ? row.installment_plans[0] : row.installment_plans;
    const sale = Array.isArray(row.sales_orders) ? row.sales_orders[0] : row.sales_orders;
    const base: InstallmentCollectionEvent = {
      id: row.id, paymentReceiptId: row.id, salesOrderId: row.sales_order_id,
      receiptNumber: row.receipt_number, saleReceiptNumber: plan?.receipt_number ?? "Purchase",
      customerName: plan?.customer_name ?? "Customer", paymentDate: row.payment_date,
      paymentMethod: displayPaymentMethod(row.payment_method, row.other_payment_method),
      transactionReference: row.transaction_reference, paymentAmount: toNumber(row.amount),
      collectionType: row.collection_type, installmentNumber: null, installmentCount: 0,
      saleStatus: sale?.status ?? "Completed", isReversal: false, reversalReason: null,
    };
    const reversal = reversalByCollection.get(row.id);
    if (!reversal) return [base];
    return [base, {
      ...base, id: reversal.id, receiptNumber: reversal.receipt_number,
      paymentDate: manilaDate(reversal.reversed_at), paymentAmount: -base.paymentAmount,
      paymentMethod: "Reversal", isReversal: true, reversalReason: reversal.reason,
    }];
  }).sort((left, right) => new Date(right.paymentDate).getTime() - new Date(left.paymentDate).getTime());
  return { events, error: null };
}

export async function getSalesWorkspaceData() {
  const supabase = await createSupabaseServerClient();

  const empty = {
    summary: {
      salesToday: 0,
      salesThisMonth: 0,
      collectedToday: 0,
      collectedThisMonth: 0,
      transactions: 0,
      completedSalesCount: 0,
      averageTransactionValue: 0,
      bestSellingItem: "No sales yet",
      totalDiscountGiven: 0,
    } satisfies SalesSummary,
    analytics: {
      dailySales: [],
      salesByCategory: [],
      paymentMethods: [],
      topItems: [],
      lowPerformingItems: [],
      discountImpact: [],
    } satisfies SalesAnalytics,
    orders: [] as RecentSalesOrder[],
    error: "Supabase is not configured.",
  };

  if (!supabase) {
    return empty;
  }

  const [ordersResultWithPaymentDetails, marketResultWithPayment] = await Promise.all([
    fetchAllPages<RecentSalesOrderRow>((from, to) => supabase
      .from("sales_orders")
      .select(
        "id, receipt_number, sale_date, customer_name, customer_contact, payment_method, transaction_reference, other_payment_method, discount_amount, total_amount, amount_paid, change_amount, remarks, void_reason, status, sales_order_items(id, item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total, inventory(category))",
      )
      .order("sale_date", { ascending: false })
      .range(from, to)
      .returns<RecentSalesOrderRow[]>()),
    fetchAllPages<StandaloneSalesRow>((from, to) => supabase
      .from("sales_transactions")
      .select("id, sale_date, customer_name, payment_method, transaction_reference, other_payment_method, quantity_sold, unit_price, total_amount, remarks, void_reason, status, inventory(item_name, unit, category)")
      .order("sale_date", { ascending: false })
      .range(from, to)
      .returns<StandaloneSalesRow[]>()),
  ]);

  const ordersResult = isMissingSalesOrderPaymentDetailColumn(ordersResultWithPaymentDetails.error)
    ? await fetchAllPages<RecentSalesOrderRow>((from, to) => supabase
        .from("sales_orders")
        .select(
          "id, receipt_number, sale_date, customer_name, customer_contact, payment_method, discount_amount, total_amount, amount_paid, change_amount, remarks, void_reason, status, sales_order_items(id, item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total, inventory(category))",
        )
        .order("sale_date", { ascending: false })
        .range(from, to)
        .returns<RecentSalesOrderRow[]>())
    : ordersResultWithPaymentDetails;

  const marketResult = isMissingPaymentMethodColumn(marketResultWithPayment.error)
    ? await fetchAllPages<StandaloneSalesRow>((from, to) => supabase
        .from("sales_transactions")
        .select("id, sale_date, customer_name, quantity_sold, unit_price, total_amount, remarks, void_reason, status, inventory(item_name, unit, category)")
        .order("sale_date", { ascending: false })
        .range(from, to)
        .returns<StandaloneSalesRow[]>())
    : isMissingTransactionReferenceColumn(marketResultWithPayment.error)
      ? await fetchAllPages<StandaloneSalesRow>((from, to) => supabase
          .from("sales_transactions")
          .select("id, sale_date, customer_name, payment_method, quantity_sold, unit_price, total_amount, remarks, void_reason, status, inventory(item_name, unit, category)")
          .order("sale_date", { ascending: false })
          .range(from, to)
          .returns<StandaloneSalesRow[]>())
      : isMissingOtherPaymentMethodColumn(marketResultWithPayment.error)
        ? await fetchAllPages<StandaloneSalesRow>((from, to) => supabase
            .from("sales_transactions")
            .select("id, sale_date, customer_name, payment_method, transaction_reference, quantity_sold, unit_price, total_amount, remarks, void_reason, status, inventory(item_name, unit, category)")
            .order("sale_date", { ascending: false })
            .range(from, to)
            .returns<StandaloneSalesRow[]>())
    : marketResultWithPayment;

  if (ordersResult.error) {
    return { ...empty, error: ordersResult.error.message };
  }

  const orderRows = ordersResult.data ?? [];
  const marketRows = marketResult.data ?? [];
  const installmentStatusesResult = orderRows.length
    ? await fetchAllPages<InstallmentPlanStatusRow>((from, to) => supabase
        .from("installment_plans")
        .select("sales_order_id, status")
        .range(from, to)
        .returns<InstallmentPlanStatusRow[]>())
    : { data: [] as InstallmentPlanStatusRow[], error: null as { message: string } | null };
  const installmentStatusBySale = new Map(
    (installmentStatusesResult.data ?? []).map((plan) => [plan.sales_order_id, plan.status]),
  );
  if (installmentStatusesResult.error) {
    return { ...empty, error: installmentStatusesResult.error.message };
  }
  const collectionsResult = await getInstallmentCollectionEvents();
  const collectionEvents = collectionsResult.events;
  const today = startOfToday();
  const month = startOfMonth();
  const itemTotals = new Map<string, number>();
  const categoryTotals = new Map<string, number>();
  const paymentTotals = new Map<string, number>();
  const dailyTotals = new Map<string, number>();
  let completedTotal = 0;
  let completedCount = 0;
  let totalDiscountGiven = 0;
  let salesToday = 0;
  let salesThisMonth = 0;
  let collectedToday = 0;
  let collectedThisMonth = 0;

  const history: RecentSalesOrder[] = [];

  for (const order of orderRows) {
    const total = toNumber(order.total_amount);
    const discount = toNumber(order.discount_amount);
    const isCompleted = order.status === "Completed";
    const saleDate = new Date(order.sale_date);
    const items = order.sales_order_items ?? [];

    history.push({
      id: order.id,
      receiptNumber: order.receipt_number,
      saleDate: order.sale_date,
      customerName: order.customer_name ?? "Walk-in customer",
      customerContact: order.customer_contact ?? "",
      remarks: order.remarks,
      voidReason: order.void_reason,
      paymentMethod: displayPaymentMethod(order.payment_method, order.other_payment_method),
      transactionReference: order.transaction_reference ?? null,
      otherPaymentMethod: order.other_payment_method ?? null,
      itemCount: items.length,
      receiptItems: items.map<SalesReceiptItem>((item) => ({
        id: item.id,
        itemName: item.item_name_snapshot,
        unit: INVENTORY_UNIT,
        quantitySold: toNumber(item.quantity_sold),
        unitPrice:
          item.unit_price === null || item.unit_price === undefined
            ? toNumber(item.line_total) / Math.max(toNumber(item.quantity_sold), 1)
            : toNumber(item.unit_price),
        lineTotal: toNumber(item.line_total),
      })),
      discountAmount: discount,
      totalAmount: total,
      amountPaid: toNumber(order.amount_paid),
      status: order.status,
      installmentStatus:
        order.payment_method === "Installment"
          ? installmentStatusBySale.get(order.id) ?? "Active"
          : undefined,
      source: "receipt",
    });

    if (!isCompleted) {
      continue;
    }

    completedTotal += total;
    completedCount += 1;
    totalDiscountGiven += discount;
    addToMap(dailyTotals, dateKey(order.sale_date), total);

    if (order.payment_method !== "Installment") {
      const method = displayPaymentMethod(order.payment_method, order.other_payment_method);
      const collectedAmount = Math.max(toNumber(order.amount_paid ?? total) - toNumber(order.change_amount), 0);
      addToMap(paymentTotals, method, collectedAmount);
      if (saleDate >= today) collectedToday += collectedAmount;
      if (saleDate >= month) collectedThisMonth += collectedAmount;
    }

    if (saleDate >= today) {
      salesToday += total;
    }

    if (saleDate >= month) {
      salesThisMonth += total;
    }

    for (const item of items) {
      const category = firstRelation(item.inventory)?.category ?? "Uncategorized";
      addToMap(itemTotals, item.item_name_snapshot, toNumber(item.line_total));
      addToMap(categoryTotals, category, toNumber(item.line_total));
    }
  }

  for (const sale of marketRows) {
    const total = toNumber(sale.total_amount);
    const isCompleted = sale.status === "Completed";
    const saleDate = new Date(sale.sale_date);
    const inventory = firstRelation(sale.inventory);
    const itemName = inventory?.item_name ?? "Legacy inventory sale";
    const category = inventory?.category ?? "Uncategorized";

    history.push({
      id: sale.id,
      receiptNumber: `LEGACY-${sale.id.slice(0, 8).toUpperCase()}`,
      saleDate: sale.sale_date,
      customerName: sale.customer_name ?? "Legacy inventory sale",
      paymentMethod: displayPaymentMethod(sale.payment_method, sale.other_payment_method),
      transactionReference: sale.transaction_reference ?? null,
      otherPaymentMethod: sale.other_payment_method ?? null,
      itemCount: 1,
      marketItemName: itemName,
      marketItemUnit: INVENTORY_UNIT,
      marketQuantitySold: toNumber(sale.quantity_sold),
      marketUnitPrice: toNumber(sale.unit_price),
      marketRemarks: sale.remarks ?? "",
      remarks: sale.remarks ?? "",
      voidReason: sale.void_reason,
      discountAmount: 0,
      totalAmount: total,
      status: sale.status,
      source: "market",
    });

    if (!isCompleted) {
      continue;
    }

    completedTotal += total;
    completedCount += 1;
    const method = displayPaymentMethod(sale.payment_method, sale.other_payment_method);
    addToMap(paymentTotals, method, total);
    addToMap(dailyTotals, dateKey(sale.sale_date), total);
    addToMap(itemTotals, itemName, total);
    addToMap(categoryTotals, category, total);

    if (saleDate >= today) {
      salesToday += total;
      collectedToday += total;
    }

    if (saleDate >= month) {
      salesThisMonth += total;
      collectedThisMonth += total;
    }
  }

  for (const event of collectionEvents) {
    const paymentDate = new Date(`${event.paymentDate}T00:00:00`);
    const entryLabel = event.isReversal
      ? `Payment reversal · ${event.reversalReason ?? ""}`
      : event.collectionType === "down_payment" ? "Initial payment" : "Installment payment";
    history.push({
      id: event.id,
      receiptNumber: event.receiptNumber,
      saleDate: event.paymentDate,
      customerName: event.customerName,
      paymentMethod: event.paymentMethod,
      transactionReference: event.transactionReference,
      totalAmount: event.paymentAmount,
      paymentAmount: event.paymentAmount,
      discountAmount: 0,
      itemCount: 0,
      status: event.saleStatus,
      source: event.isReversal ? "reversal" : "payment",
      entryLabel,
      relatedSaleId: event.salesOrderId,
      paymentReceiptId: event.paymentReceiptId,
      reversalReason: event.reversalReason,
    });
    addToMap(paymentTotals, event.paymentMethod, event.paymentAmount);
    if (paymentDate >= today) collectedToday += event.paymentAmount;
    if (paymentDate >= month) collectedThisMonth += event.paymentAmount;
  }

  const topItems = topMapEntries(itemTotals, 5);

  return {
    summary: {
      salesToday,
      salesThisMonth,
      collectedToday,
      collectedThisMonth,
      transactions: orderRows.length + marketRows.length,
      completedSalesCount: completedCount,
      averageTransactionValue: completedCount > 0 ? completedTotal / completedCount : 0,
      bestSellingItem: topItems[0]?.label ?? "No sales yet",
      totalDiscountGiven,
    },
    analytics: {
      dailySales: topMapEntries(dailyTotals, 7).reverse(),
      salesByCategory: topMapEntries(categoryTotals, 5),
      paymentMethods: topMapEntries(paymentTotals, 5),
      topItems,
      lowPerformingItems: topMapEntries(itemTotals, 5, true),
      discountImpact: [
        { label: "Sales value", value: completedTotal },
        { label: "Discounts", value: totalDiscountGiven },
      ],
    },
    orders: history.sort(
      (a, b) => new Date(b.saleDate).getTime() - new Date(a.saleDate).getTime(),
    ),
    error: marketResult.error?.message ?? collectionsResult.error ?? null,
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

  const receiptWithPaymentDetails = await supabase
    .from("sales_orders")
    .select(
      "id, receipt_number, sale_date, customer_name, customer_contact, payment_method, transaction_reference, other_payment_method, subtotal, discount_type, discount_value, discount_amount, total_amount, amount_paid, change_amount, remarks, status, profiles(full_name), sales_order_items(id, item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total)",
    )
    .eq("id", id)
    .single<SalesReceiptRow>();

  const { data, error } = isMissingSalesOrderPaymentDetailColumn(receiptWithPaymentDetails.error)
    ? await supabase
        .from("sales_orders")
        .select(
          "id, receipt_number, sale_date, customer_name, customer_contact, payment_method, subtotal, discount_type, discount_value, discount_amount, total_amount, amount_paid, change_amount, remarks, status, profiles(full_name), sales_order_items(id, item_name_snapshot, unit_snapshot, quantity_sold, unit_price, line_total)",
        )
        .eq("id", id)
        .single<SalesReceiptRow>()
    : receiptWithPaymentDetails;

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
      paymentMethod: displayPaymentMethod(data.payment_method, data.other_payment_method),
      transactionReference: data.transaction_reference ?? null,
      otherPaymentMethod: data.other_payment_method ?? null,
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
        unit: INVENTORY_UNIT,
        quantitySold: toNumber(item.quantity_sold),
        unitPrice: toNumber(item.unit_price),
        lineTotal: toNumber(item.line_total),
      })),
    },
    error: null,
  };
}
