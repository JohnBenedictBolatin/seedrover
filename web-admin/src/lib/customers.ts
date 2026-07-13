import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CustomerSummary = {
  key: string;
  name: string;
  contact: string;
  receiptCount: number;
  totalSpent: number;
  lastPurchaseAt: string;
  paymentMethods: string[];
};

export type CustomerStats = {
  totalCustomers: number;
  repeatCustomers: number;
  totalCustomerSales: number;
  topCustomer: string;
};

type SalesOrderRow = {
  customer_name: string | null;
  customer_contact: string | null;
  payment_method: string;
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

function customerKey(name: string, contact: string) {
  return `${name.trim().toLowerCase()}::${contact.trim().toLowerCase()}`;
}

export async function getCustomersDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      customers: [],
      stats: null,
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("sales_orders")
    .select("customer_name, customer_contact, payment_method, total_amount, sale_date, status")
    .eq("status", "Completed")
    .order("sale_date", { ascending: false })
    .returns<SalesOrderRow[]>();

  if (error) {
    return {
      customers: [],
      stats: null,
      error: error.message,
    };
  }

  const customersByKey = new Map<string, CustomerSummary>();

  for (const row of data ?? []) {
    const name = row.customer_name?.trim() || "Walk-in customer";
    const contact = row.customer_contact?.trim() || "Not provided";
    const key = customerKey(name, contact);
    const existing = customersByKey.get(key);

    if (!existing) {
      customersByKey.set(key, {
        key,
        name,
        contact,
        receiptCount: 1,
        totalSpent: toNumber(row.total_amount),
        lastPurchaseAt: row.sale_date,
        paymentMethods: [row.payment_method],
      });
      continue;
    }

    existing.receiptCount += 1;
    existing.totalSpent += toNumber(row.total_amount);

    if (row.sale_date > existing.lastPurchaseAt) {
      existing.lastPurchaseAt = row.sale_date;
    }

    if (!existing.paymentMethods.includes(row.payment_method)) {
      existing.paymentMethods.push(row.payment_method);
    }
  }

  const customers = Array.from(customersByKey.values()).sort(
    (left, right) => right.totalSpent - left.totalSpent,
  );

  const stats: CustomerStats = {
    totalCustomers: customers.length,
    repeatCustomers: customers.filter((customer) => customer.receiptCount > 1).length,
    totalCustomerSales: customers.reduce(
      (total, customer) => total + customer.totalSpent,
      0,
    ),
    topCustomer: customers[0]?.name ?? "None yet",
  };

  return {
    customers,
    stats,
    error: null,
  };
}
