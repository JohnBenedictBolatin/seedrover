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

export type InstallmentPayment = {
  id: string;
  amount: number;
  paymentDate: string;
  paymentMethod: string;
  transactionReference: string | null;
  otherPaymentMethod: string | null;
  notes: string | null;
  receiptUrl: string | null;
};

export type InstallmentSchedule = {
  id: string;
  installmentNumber: number;
  dueDate: string;
  scheduledAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: "Pending" | "Partially Paid" | "Paid" | "Overdue";
  payments: InstallmentPayment[];
};

export type InstallmentPlan = {
  id: string;
  salesOrderId: string;
  customerName: string;
  customerContact: string | null;
  receiptNumber: string;
  frequency: "Weekly" | "Monthly" | "Yearly";
  paymentAmount: number;
  totalAmount: number;
  initialPayment: number;
  financedAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: "Active" | "Completed" | "Cancelled";
  schedule: InstallmentSchedule[];
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

type InstallmentPlanRow = {
  id: string;
  sales_order_id: string;
  customer_name: string;
  customer_contact: string | null;
  receipt_number: string;
  frequency: "Weekly" | "Monthly" | "Yearly";
  payment_amount: number | string;
  total_amount: number | string;
  initial_payment: number | string;
  financed_amount: number | string;
  status: "Active" | "Completed" | "Cancelled";
};

type InstallmentScheduleRow = {
  id: string;
  plan_id: string;
  installment_number: number;
  due_date: string;
  scheduled_amount: number | string;
};

type InstallmentPaymentRow = {
  id: string;
  plan_id: string;
  schedule_id: string;
  amount: number | string;
  payment_date: string;
  payment_method: string;
  transaction_reference: string | null;
  other_payment_method: string | null;
  notes: string | null;
  receipt_path: string | null;
};

function installmentStatus(
  paidAmount: number,
  scheduledAmount: number,
  dueDate: string,
  today: string,
): InstallmentSchedule["status"] {
  if (paidAmount >= scheduledAmount - 0.005) return "Paid";
  if (dueDate < today) return "Overdue";
  if (paidAmount > 0) return "Partially Paid";
  return "Pending";
}

export async function getInstallmentPlans() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { plans: [] as InstallmentPlan[], error: "Supabase is not configured." };

  const { data: planRows, error: plansError } = await supabase
    .from("installment_plans")
    .select("id, sales_order_id, customer_name, customer_contact, receipt_number, frequency, payment_amount, total_amount, initial_payment, financed_amount, status")
    .order("status", { ascending: true })
    .order("created_at", { ascending: false })
    .returns<InstallmentPlanRow[]>();

  if (plansError) {
    const message = plansError.message.includes("installment_") || plansError.message.includes("schema cache")
      ? "Installment schedules are not set up yet. Apply the latest Supabase migration, then refresh this page."
      : plansError.message;
    return { plans: [] as InstallmentPlan[], error: message };
  }

  const planIds = (planRows ?? []).map((row) => row.id);
  if (planIds.length === 0) return { plans: [], error: null };

  const [{ data: scheduleRows, error: scheduleError }, { data: paymentRows, error: paymentError }] = await Promise.all([
    supabase
      .from("installment_schedule")
      .select("id, plan_id, installment_number, due_date, scheduled_amount")
      .in("plan_id", planIds)
      .order("installment_number", { ascending: true })
      .returns<InstallmentScheduleRow[]>(),
    supabase
      .from("installment_payments")
      .select("id, plan_id, schedule_id, amount, payment_date, payment_method, transaction_reference, other_payment_method, notes, receipt_path")
      .in("plan_id", planIds)
      .order("payment_date", { ascending: false })
      .returns<InstallmentPaymentRow[]>(),
  ]);

  const relatedError = scheduleError ?? paymentError;
  if (relatedError) return { plans: [] as InstallmentPlan[], error: relatedError.message };

  const paymentsBySchedule = new Map<string, InstallmentPayment[]>();
  for (const row of paymentRows ?? []) {
    const receiptUrl = row.receipt_path
      ? (await supabase.storage.from("installment-receipts").createSignedUrl(row.receipt_path, 60 * 60)).data?.signedUrl ?? null
      : null;
    const payments = paymentsBySchedule.get(row.schedule_id) ?? [];
    payments.push({
      id: row.id,
      amount: Number(row.amount),
      paymentDate: row.payment_date,
      paymentMethod: row.payment_method,
      transactionReference: row.transaction_reference,
      otherPaymentMethod: row.other_payment_method,
      notes: row.notes,
      receiptUrl,
    });
    paymentsBySchedule.set(row.schedule_id, payments);
  }

  const today = new Date().toISOString().slice(0, 10);
  const schedulesByPlan = new Map<string, InstallmentSchedule[]>();
  for (const row of scheduleRows ?? []) {
    const payments = paymentsBySchedule.get(row.id) ?? [];
    const scheduledAmount = Number(row.scheduled_amount);
    const paidAmount = payments.reduce((sum, payment) => sum + payment.amount, 0);
    const schedule = {
      id: row.id,
      installmentNumber: row.installment_number,
      dueDate: row.due_date,
      scheduledAmount,
      paidAmount,
      remainingAmount: Math.max(scheduledAmount - paidAmount, 0),
      status: installmentStatus(paidAmount, scheduledAmount, row.due_date, today),
      payments,
    } satisfies InstallmentSchedule;
    schedulesByPlan.set(row.plan_id, [...(schedulesByPlan.get(row.plan_id) ?? []), schedule]);
  }

  return {
    plans: (planRows ?? []).map<InstallmentPlan>((row) => {
      const schedule = schedulesByPlan.get(row.id) ?? [];
      const paidAmount = schedule.reduce((sum, item) => sum + item.paidAmount, 0);
      return {
        id: row.id,
        salesOrderId: row.sales_order_id,
        customerName: row.customer_name,
        customerContact: row.customer_contact,
        receiptNumber: row.receipt_number,
        frequency: row.frequency,
        paymentAmount: Number(row.payment_amount),
        totalAmount: Number(row.total_amount),
        initialPayment: Number(row.initial_payment),
        financedAmount: Number(row.financed_amount),
        paidAmount,
        remainingAmount: Math.max(Number(row.total_amount) - paidAmount, 0),
        status: row.status,
        schedule,
      };
    }),
    error: null,
  };
}

export async function getInstallmentPlanForSale(salesOrderId: string) {
  const result = await getInstallmentPlans();
  return {
    plan: result.plans.find((plan) => plan.salesOrderId === salesOrderId) ?? null,
    error: result.error,
  };
}
