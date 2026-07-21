import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CustomerReceipt = {
  id: string;
  receiptNumber: string;
  saleDate: string;
  paymentMethod: string;
  totalAmount: number;
  source: "receipt" | "market";
};

export type CustomerPurchasedItem = {
  itemName: string;
  quantity: number;
  totalAmount: number;
};

export type CustomerSummary = {
  key: string;
  profileId: string | null;
  name: string;
  contact: string;
  alternateContact: string;
  location: string;
  customerType: string;
  tags: string[];
  notes: string;
  receiptCount: number;
  totalSpent: number;
  averageSpend: number;
  lastPurchaseAt: string;
  paymentMethods: string[];
  purchasedItems: CustomerPurchasedItem[];
  receipts: CustomerReceipt[];
};

export type CustomerStats = {
  totalCustomers: number;
  repeatCustomers: number;
  totalCustomerSales: number;
  averageSpendPerCustomer: number;
  topCustomer: string;
  recentlyActiveCustomers: number;
};

export type CustomerDiscount = {
  id: string;
  code: string;
  customerName: string;
  discountType: "Amount" | "Percent";
  discountValue: number;
  releasedAt: string;
  usedAt: string | null;
  status: string;
};

type SalesOrderRow = {
  id: string;
  receipt_number: string;
  customer_name: string | null;
  customer_contact: string | null;
  payment_method: string;
  total_amount: number | string;
  sale_date: string;
  status: string;
  sales_order_items?: Array<{
    item_name_snapshot: string;
    quantity_sold: number | string;
    line_total: number | string;
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
  inventory:
    | {
        item_name: string;
      }
    | {
        item_name: string;
      }[]
    | null;
};

type CustomerProfileRow = {
  id: string;
  customer_key: string;
  display_name: string;
  contact_number: string | null;
  alternate_contact: string | null;
  customer_type: string | null;
  tags: string[] | null;
  notes: string | null;
  location: string | null;
};

type CustomerDiscountRow = {
  id: string;
  discount_code: string;
  customer_name: string;
  discount_type: "Amount" | "Percent";
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

function normalizeText(value: string) {
  return value.trim().replace(/\s+/g, " ");
}

export function customerKey(name: string, contact: string) {
  return `${normalizeText(name).toLowerCase()}::${normalizeText(contact).toLowerCase()}`;
}

function isMissingCustomerTable(error: { message?: string; code?: string } | null | undefined) {
  return (
    error?.code === "42P01" ||
    error?.message?.includes("customers") ||
    error?.message?.includes("schema cache")
  );
}

function isMissingDiscountTable(error: { message?: string; code?: string } | null | undefined) {
  return (
    error?.code === "42P01" ||
    error?.message?.includes("customer_discounts") ||
    error?.message?.includes("schema cache")
  );
}

function isMissingPaymentMethodColumn(error: { message?: string } | null | undefined) {
  return error?.message?.includes("sales_transactions.payment_method") ?? false;
}

function defaultTags(customer: CustomerSummary) {
  const tags = new Set(customer.tags);

  if (customer.name.toLowerCase().includes("walk-in")) {
    tags.add("Walk-in");
  }

  if (customer.receiptCount > 1) {
    tags.add("Repeat Buyer");
  }

  if (customer.receipts.some((receipt) => receipt.source === "market")) {
    tags.add("Market Buyer");
  }

  return [...tags];
}

function createCustomer(key: string, name: string, contact: string): CustomerSummary {
  return {
    key,
    profileId: null,
    name,
    contact,
    alternateContact: "",
    location: "",
    customerType: "Farm Buyer",
    tags: [],
    notes: "",
    receiptCount: 0,
    totalSpent: 0,
    averageSpend: 0,
    lastPurchaseAt: "",
    paymentMethods: [],
    purchasedItems: [],
    receipts: [],
  };
}

function addReceipt(
  customer: CustomerSummary,
  receipt: CustomerReceipt,
  items: CustomerPurchasedItem[],
) {
  customer.receiptCount += 1;
  customer.totalSpent += receipt.totalAmount;
  customer.averageSpend = customer.totalSpent / customer.receiptCount;
  customer.receipts.push(receipt);

  if (!customer.lastPurchaseAt || receipt.saleDate > customer.lastPurchaseAt) {
    customer.lastPurchaseAt = receipt.saleDate;
  }

  if (!customer.paymentMethods.includes(receipt.paymentMethod)) {
    customer.paymentMethods.push(receipt.paymentMethod);
  }

  for (const item of items) {
    const existing = customer.purchasedItems.find(
      (entry) => entry.itemName === item.itemName,
    );

    if (existing) {
      existing.quantity += item.quantity;
      existing.totalAmount += item.totalAmount;
    } else {
      customer.purchasedItems.push({ ...item });
    }
  }
}

export async function getCustomersDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      customers: [],
      discounts: [],
      stats: null,
      error: "Supabase is not configured.",
      profileError: null,
    };
  }

  const [ordersResult, marketResultWithPayment, profilesResult, discountsResult] =
    await Promise.all([
    supabase
      .from("sales_orders")
      .select(
        "id, receipt_number, customer_name, customer_contact, payment_method, total_amount, sale_date, status, sales_order_items(item_name_snapshot, quantity_sold, line_total)",
      )
      .eq("status", "Completed")
      .order("sale_date", { ascending: false })
      .returns<SalesOrderRow[]>(),
    supabase
      .from("sales_transactions")
      .select(
        "id, sale_date, customer_name, payment_method, quantity_sold, total_amount, status, inventory(item_name)",
      )
      .eq("status", "Completed")
      .order("sale_date", { ascending: false })
      .returns<MarketSaleRow[]>(),
    supabase
      .from("customers")
      .select(
        "id, customer_key, display_name, contact_number, alternate_contact, customer_type, tags, notes, location",
      )
      .returns<CustomerProfileRow[]>(),
    supabase
      .from("customer_discounts")
      .select("id, discount_code, customer_name, discount_type, discount_value, released_at, used_at, status")
      .order("released_at", { ascending: false })
      .returns<CustomerDiscountRow[]>(),
  ]);

  const marketResult = isMissingPaymentMethodColumn(marketResultWithPayment.error)
    ? await supabase
        .from("sales_transactions")
        .select(
          "id, sale_date, customer_name, quantity_sold, total_amount, status, inventory(item_name)",
        )
        .eq("status", "Completed")
        .order("sale_date", { ascending: false })
        .returns<MarketSaleRow[]>()
    : marketResultWithPayment;

  if (ordersResult.error) {
    return {
      customers: [],
      discounts: [],
      stats: null,
      error: ordersResult.error.message,
      profileError: null,
    };
  }

  const profileError =
    profilesResult.error && !isMissingCustomerTable(profilesResult.error)
      ? profilesResult.error.message
      : null;
  const profileRows = profilesResult.error ? [] : profilesResult.data ?? [];
  const discounts = discountsResult.error
    ? []
    : (discountsResult.data ?? []).map<CustomerDiscount>((discount) => ({
        id: discount.id,
        code: discount.discount_code,
        customerName: discount.customer_name,
        discountType: discount.discount_type,
        discountValue: toNumber(discount.discount_value),
        releasedAt: discount.released_at,
        usedAt: discount.used_at,
        status: discount.status,
      }));
  const profilesByKey = new Map(profileRows.map((profile) => [profile.customer_key, profile]));
  const customersByKey = new Map<string, CustomerSummary>();

  for (const row of ordersResult.data ?? []) {
    const name = normalizeText(row.customer_name || "Walk-in customer");
    const contact = normalizeText(row.customer_contact || "Not provided");
    const key = customerKey(name, contact);
    const customer = customersByKey.get(key) ?? createCustomer(key, name, contact);
    const totalAmount = toNumber(row.total_amount);

    addReceipt(
      customer,
      {
        id: row.id,
        receiptNumber: row.receipt_number,
        saleDate: row.sale_date,
        paymentMethod: row.payment_method,
        totalAmount,
        source: "receipt",
      },
      (row.sales_order_items ?? []).map((item) => ({
        itemName: item.item_name_snapshot,
        quantity: toNumber(item.quantity_sold),
        totalAmount: toNumber(item.line_total),
      })),
    );

    customersByKey.set(key, customer);
  }

  for (const row of marketResult.data ?? []) {
    const name = normalizeText(row.customer_name ?? "");

    if (!name) {
      continue;
    }

    const contact = "Not provided";
    const key = customerKey(name, contact);
    const customer = customersByKey.get(key) ?? createCustomer(key, name, contact);
    const totalAmount = toNumber(row.total_amount);
    const inventory = firstRelation(row.inventory);

    addReceipt(
      customer,
      {
        id: row.id,
        receiptNumber: `SR-${row.id.slice(0, 8).toUpperCase()}`,
        saleDate: row.sale_date,
        paymentMethod: row.payment_method ?? "Not recorded",
        totalAmount,
        source: "market",
      },
      [
        {
          itemName: inventory?.item_name ?? "Market distribution",
          quantity: toNumber(row.quantity_sold),
          totalAmount,
        },
      ],
    );

    customersByKey.set(key, customer);
  }

  for (const [key, customer] of customersByKey) {
    const profile = profilesByKey.get(key);

    if (profile) {
      customer.profileId = profile.id;
      customer.name = profile.display_name || customer.name;
      customer.contact = profile.contact_number || customer.contact;
      customer.alternateContact = profile.alternate_contact ?? "";
      customer.customerType = profile.customer_type ?? "Farm Buyer";
      customer.tags = profile.tags ?? [];
      customer.notes = profile.notes ?? "";
      customer.location = profile.location ?? "";
    }

    customer.tags = defaultTags(customer);
    customer.purchasedItems.sort((left, right) => right.totalAmount - left.totalAmount);
    customer.receipts.sort(
      (left, right) =>
        new Date(right.saleDate).getTime() - new Date(left.saleDate).getTime(),
    );
    customersByKey.set(key, customer);
  }

  const customers = Array.from(customersByKey.values()).sort(
    (left, right) => right.totalSpent - left.totalSpent,
  );
  const totalCustomerSales = customers.reduce(
    (total, customer) => total + customer.totalSpent,
    0,
  );
  const recentCutoff = new Date();
  recentCutoff.setDate(recentCutoff.getDate() - 30);

  const stats: CustomerStats = {
    totalCustomers: customers.length,
    repeatCustomers: customers.filter((customer) => customer.receiptCount > 1).length,
    totalCustomerSales,
    averageSpendPerCustomer:
      customers.length > 0 ? totalCustomerSales / customers.length : 0,
    topCustomer: customers[0]?.name ?? "None yet",
    recentlyActiveCustomers: customers.filter(
      (customer) => new Date(customer.lastPurchaseAt) >= recentCutoff,
    ).length,
  };

  return {
    customers,
    discounts,
    stats,
    error:
      marketResult.error?.message ??
      (discountsResult.error && !isMissingDiscountTable(discountsResult.error)
        ? discountsResult.error.message
        : null),
    profileError,
  };
}
