import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CustomerPayment = {
  id: string;
  customerKey: string;
  customerName: string;
  saleReference: string | null;
  amount: number;
  dueDate: string | null;
  paidAt: string | null;
  status: "Pending" | "Paid" | "Overdue";
  notes: string | null;
};

type PaymentRow = Omit<CustomerPayment, "customerKey" | "customerName" | "saleReference" | "dueDate" | "paidAt"> & {
  customer_key: string;
  customer_name: string;
  sale_reference: string | null;
  due_date: string | null;
  paid_at: string | null;
  amount: number | string;
};

export async function getCustomerPayments() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { payments: [], error: "Supabase is not configured." };

  const { data, error } = await supabase
    .from("customer_payments")
    .select("id, customer_key, customer_name, sale_reference, amount, due_date, paid_at, status, notes")
    .order("status", { ascending: true })
    .order("due_date", { ascending: true })
    .returns<PaymentRow[]>();

  const setupError = error?.message?.includes("customer_payments") || error?.message?.includes("schema cache")
    ? "Installment tracking is not set up yet. Apply the latest Supabase migration, then refresh this page."
    : error?.message ?? null;

  return {
    payments: (data ?? []).map<CustomerPayment>((row) => ({
      id: row.id,
      customerKey: row.customer_key,
      customerName: row.customer_name,
      saleReference: row.sale_reference,
      amount: Number(row.amount),
      dueDate: row.due_date,
      paidAt: row.paid_at,
      status: row.status,
      notes: row.notes,
    })),
    error: setupError,
  };
}
