import { redirect } from "next/navigation";
import { Banknote, CalendarDays, CircleDollarSign, ReceiptText } from "lucide-react";
import { CountUpValue } from "@/components/count-up-value";
import { InvestmentsWorkspace } from "@/components/investments-workspace";
import { InvestmentHistory } from "@/components/investment-history";
import { LiveDateTime } from "@/components/live-date-time";
import { getCurrentAdminProfile } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import styles from "./page.module.css";

type ExpenseRow = { id: string; description: string; category: string; amount: number | string; expense_date: string; vendor: string | null; payment_method: string; reference_number: string | null; expense_type: string; related_crop_id: string | null; related_inventory_id: string | null; quantity: number | string | null; unit_cost: number | string | null; receipt_path: string | null; notes: string | null; frequency: string | null; next_due_date: string | null; end_date: string | null };
type BasicExpenseRow = Pick<ExpenseRow, "id" | "description" | "category" | "amount" | "expense_date"> & { notes?: string | null };

export default async function InvestmentsPage() {
  const profile = await getCurrentAdminProfile();
  if (!profile) redirect("/login");
  if (profile.roleName === "Farm Planting Manager") redirect("/dashboard");

  const supabase = await createSupabaseServerClient();
  const expandedResult = supabase
    ? await supabase.from("farm_expenses").select("id, description, category, amount, expense_date, vendor, payment_method, reference_number, expense_type, related_crop_id, related_inventory_id, quantity, unit_cost, receipt_path, notes, frequency, next_due_date, end_date").order("expense_date", { ascending: false }).limit(100).returns<ExpenseRow[]>()
    : { data: [] as ExpenseRow[], error: null };
  let error = expandedResult.error;
  let expenses: ExpenseRow[] = expandedResult.data ?? [];
  const needsExpandedMigration = Boolean(error?.message.includes("farm_expenses") && error.message.includes("does not exist"));
  if (supabase && needsExpandedMigration) {
    const fallback = await supabase.from("farm_expenses").select("id, description, category, amount, expense_date, notes").order("expense_date", { ascending: false }).limit(100).returns<BasicExpenseRow[]>();
    error = fallback.error;
    expenses = (fallback.data ?? []).map((expense) => ({ ...expense, vendor: null, payment_method: "Not recorded", reference_number: null, expense_type: "One-time investment", related_crop_id: null, related_inventory_id: null, quantity: null, unit_cost: null, receipt_path: null, notes: expense.notes ?? null, frequency: null, next_due_date: null, end_date: null }));
  }
  const [{ data: cropRows }, { data: inventoryRows }] = supabase ? await Promise.all([
    supabase.from("crops").select("id, crop_name").order("crop_name"),
    supabase.from("inventory").select("id, item_name").order("item_name"),
  ]) : [{ data: [] }, { data: [] }];
  const cropNames = new Map((cropRows ?? []).map((crop) => [crop.id, crop.crop_name]));
  const inventoryNames = new Map((inventoryRows ?? []).map((item) => [item.id, item.item_name]));
  const receiptUrlEntries = supabase ? await Promise.all(
    expenses.filter((expense) => expense.receipt_path).map(async (expense) => {
      const { data } = await supabase.storage.from("expense-receipts").createSignedUrl(expense.receipt_path!, 60 * 60);
      return [expense.id, data?.signedUrl ?? null] as const;
    }),
  ) : [];
  const receiptUrls = new Map(receiptUrlEntries);
  const monthKey = new Date().toISOString().slice(0, 7);
  const totalInvestment = expenses.reduce((total, expense) => total + Number(expense.amount), 0);
  const monthlyInvestment = expenses.filter((expense) => expense.expense_date.startsWith(monthKey)).reduce((total, expense) => total + Number(expense.amount), 0);
  const categoryTotals = new Map<string, number>();
  expenses.forEach((expense) => categoryTotals.set(expense.category, (categoryTotals.get(expense.category) ?? 0) + Number(expense.amount)));
  const topCategory = [...categoryTotals.entries()].sort((left, right) => right[1] - left[1])[0]?.[0] ?? "No records";

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div><p className={styles.eyebrow}>Operations</p><h1>Investments</h1><p>Farm costs, recurring expenses, receipts, and due dates.</p></div>
        <div className={styles.liveDateTime}><LiveDateTime /></div>
      </header>

      {error ? <section className={styles.notice}><strong>Investment records are unavailable.</strong><span>{error.message}</span></section> : null}
      {needsExpandedMigration && !error ? <section className={styles.notice}><strong>Expanded investment details need a database update.</strong><span>Existing records are shown below. Apply the latest Supabase migration to use vendor, receipt, recurring, crop, and inventory fields.</span></section> : null}

      <section className={styles.metricGrid} aria-label="Investment summary">
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><ReceiptText size={20} /></span><p>Total records</p></div><CountUpValue className="mono" value={expenses.length} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><CircleDollarSign size={20} /></span><p>Total invested</p></div><CountUpValue className="mono" currency value={totalInvestment} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><CalendarDays size={20} /></span><p>This month</p></div><CountUpValue className="mono" currency value={monthlyInvestment} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><Banknote size={20} /></span><p>Top category</p></div><strong>{topCategory}</strong></article>
      </section>

      <InvestmentsWorkspace crops={(cropRows ?? []).map((crop) => ({ id: crop.id, name: crop.crop_name }))} inventoryItems={(inventoryRows ?? []).map((item) => ({ id: item.id, name: item.item_name }))} />

      <section className={styles.listSection}>
        <header className={styles.sectionHeader}><div><p className={styles.eyebrow}>Investment list</p><h2>Investment history</h2></div></header>
        <InvestmentHistory records={expenses.map((expense) => ({ id: expense.id, description: expense.description, category: expense.category, amount: Number(expense.amount), expenseDate: expense.expense_date, vendor: expense.vendor, paymentMethod: expense.payment_method, referenceNumber: expense.reference_number, expenseType: expense.expense_type, cropName: expense.related_crop_id ? cropNames.get(expense.related_crop_id) ?? null : null, inventoryName: expense.related_inventory_id ? inventoryNames.get(expense.related_inventory_id) ?? null : null, quantity: expense.quantity === null ? null : Number(expense.quantity), unitCost: expense.unit_cost === null ? null : Number(expense.unit_cost), notes: expense.notes, frequency: expense.frequency, nextDueDate: expense.next_due_date, endDate: expense.end_date, hasReceipt: Boolean(expense.receipt_path), receiptUrl: receiptUrls.get(expense.id) ?? null, receiptFileName: expense.receipt_path?.split("/").pop() ?? null, receiptKind: expense.receipt_path?.toLowerCase().endsWith(".pdf") ? "pdf" as const : expense.receipt_path ? "image" as const : null }))} />
      </section>
    </div>
  );
}
