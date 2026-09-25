import Link from "next/link";
import { redirect } from "next/navigation";
import { Banknote, CalendarDays, ChevronDown, CircleDollarSign, ReceiptText, TrendingUp } from "lucide-react";
import { CountUpValue } from "@/components/count-up-value";
import { InvestmentsWorkspace } from "@/components/investments-workspace";
import { InvestmentHistory } from "@/components/investment-history";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getDashboardRangeStart, normalizeDashboardRange, type DashboardRange } from "@/lib/dashboard";
import {
  calculateRecoveryProjection,
  calculateRoiBreakdown,
  getRecoveryTargetForPeriod,
  isCapitalInvestmentType,
  isOperatingExpenseType,
} from "@/lib/finance";
import { formatCurrency } from "@/lib/format";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import styles from "./page.module.css";

type ExpenseRow = { id: string; description: string; category: string; amount: number | string; expense_date: string; vendor: string | null; payment_method: string; reference_number: string | null; expense_type: string; related_crop_id: string | null; related_inventory_id: string | null; quantity: number | string | null; unit_cost: number | string | null; receipt_path: string | null; notes: string | null };
type BasicExpenseRow = Pick<ExpenseRow, "id" | "description" | "category" | "amount" | "expense_date"> & { notes?: string | null };
type RoiSaleRow = { total_amount: number | string; sale_date: string };

const roiRanges: Array<{ label: string; value: DashboardRange }> = [
  { label: "Day", value: "day" },
  { label: "Week", value: "week" },
  { label: "Month", value: "month" },
  { label: "Year", value: "year" },
];

type InvestmentsPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function InvestmentsPage({ searchParams }: InvestmentsPageProps) {
  const profile = await getCurrentAdminProfile();
  if (!profile) redirect("/login");
  if (profile.roleName !== "System Administrator") redirect("/dashboard");

  const params = await searchParams;
  const roiRange = normalizeDashboardRange(params?.range);
  const roiStart = getDashboardRangeStart(roiRange);
  const roiStartIso = roiStart.toISOString();
  const supabase = await createSupabaseServerClient();
  const expandedResult = supabase
    ? await supabase.from("farm_expenses").select("id, description, category, amount, expense_date, vendor, payment_method, reference_number, expense_type, related_crop_id, related_inventory_id, quantity, unit_cost, receipt_path, notes").order("expense_date", { ascending: false }).returns<ExpenseRow[]>()
    : { data: [] as ExpenseRow[], error: null };
  let error = expandedResult.error;
  let expenses: ExpenseRow[] = expandedResult.data ?? [];
  const needsExpandedMigration = Boolean(error?.message.includes("farm_expenses") && error.message.includes("does not exist"));
  if (supabase && needsExpandedMigration) {
    const fallback = await supabase.from("farm_expenses").select("id, description, category, amount, expense_date, notes").order("expense_date", { ascending: false }).returns<BasicExpenseRow[]>();
    error = fallback.error;
    expenses = (fallback.data ?? []).map((expense) => ({ ...expense, vendor: null, payment_method: "Not recorded", reference_number: null, expense_type: "Capital investment", related_crop_id: null, related_inventory_id: null, quantity: null, unit_cost: null, receipt_path: null, notes: expense.notes ?? null }));
  }

  const capitalExpenses = expenses.filter((expense) => isCapitalInvestmentType(expense.expense_type));
  const totalCapitalInvestment = capitalExpenses.reduce((total, expense) => total + Number(expense.amount), 0);
  const recoveryStartDate = expenses
    .map((expense) => expense.expense_date)
    .sort((left, right) => left.localeCompare(right))[0] ?? null;
  const recoveryStartIso = recoveryStartDate ? `${recoveryStartDate}T00:00:00.000Z` : roiStartIso;
  const salesStartIso = new Date(recoveryStartIso).getTime() < roiStart.getTime()
    ? recoveryStartIso
    : roiStartIso;

  const [{ data: cropRows }, { data: inventoryRows }] = supabase ? await Promise.all([
    supabase.from("crops").select("id, crop_name").order("crop_name"),
    supabase.from("inventory").select("id, item_name").order("item_name"),
  ]) : [{ data: [] }, { data: [] }];

  const [receiptSalesResult, marketSalesResult] = supabase
    ? await Promise.all([
        supabase
          .from("sales_orders")
          .select("total_amount, sale_date")
          .eq("status", "Completed")
          .gte("sale_date", salesStartIso)
          .returns<RoiSaleRow[]>(),
        supabase
          .from("sales_transactions")
          .select("total_amount, sale_date")
          .eq("status", "Completed")
          .gte("sale_date", salesStartIso)
          .returns<RoiSaleRow[]>(),
      ])
    : [
        { data: [] as RoiSaleRow[], error: null },
        { data: [] as RoiSaleRow[], error: null },
      ];

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

  const roiError = receiptSalesResult.error ?? marketSalesResult.error;
  const roiStartDate = roiStartIso.slice(0, 10);
  const roiExpenses = expenses.filter((expense) => expense.expense_date >= roiStartDate);
  const allSales = [...(receiptSalesResult.data ?? []), ...(marketSalesResult.data ?? [])];
  const roiSales = allSales.filter((sale) => new Date(sale.sale_date).getTime() >= roiStart.getTime());
  const recoveredSales = recoveryStartDate
    ? allSales
        .filter((sale) => new Date(sale.sale_date).getTime() >= new Date(recoveryStartIso).getTime())
        .reduce((total, sale) => total + Number(sale.total_amount), 0)
    : 0;
  const roiInvestment = roiExpenses
    .filter((expense) => isCapitalInvestmentType(expense.expense_type))
    .reduce((total, row) => total + Number(row.amount), 0);
  const operatingExpenses = roiExpenses
    .filter((expense) => isOperatingExpenseType(expense.expense_type))
    .reduce((total, row) => total + Number(row.amount), 0);
  const operatingExpensesSinceInvestment = recoveryStartDate
    ? expenses
        .filter((expense) => expense.expense_date >= recoveryStartDate && isOperatingExpenseType(expense.expense_type))
        .reduce((total, expense) => total + Number(expense.amount), 0)
    : 0;
  const totalRecoverableCost = totalCapitalInvestment + operatingExpensesSinceInvestment;
  const roiRevenue = roiSales.reduce((total, row) => total + Number(row.total_amount), 0);
  const roi = calculateRoiBreakdown(Math.max(0, roiRevenue - operatingExpenses), roiInvestment);
  const recovery = calculateRecoveryProjection({
    periodSales: roiRevenue,
    periodStart: roiStart,
    recoveredSales: Math.max(0, recoveredSales - operatingExpensesSinceInvestment),
    totalInvestment: totalRecoverableCost,
  });
  const requiredPeriodSales = getRecoveryTargetForPeriod(recovery.remainingInvestment, roiRange);
  const roiRangeLabel = roiRanges.find((range) => range.value === roiRange)?.label ?? "Month";
  const shortRange = roiRange !== "year";
  const roiTone = recovery.status === "on-track" || recovery.status === "recovered"
    ? "positive"
    : recovery.status === "behind"
      ? "negative"
      : "neutral";
  const recoveryWidth = Math.min(100, Math.max(0, recovery.recoveryRate));
  const recoveryStatusLabel = recovery.status === "recovered"
    ? "Investment already recovered"
    : recovery.status === "on-track"
      ? "On track for one-year recovery"
      : recovery.status === "behind"
        ? "Below the required sales pace"
        : "No one-time investment baseline";
  const performanceStatus = roiError
    ? "Performance unavailable"
    : shortRange
      ? recovery.status === "no-baseline" ? "Baseline needed" : recoveryStatusLabel
      : roi.hasInvestmentBaseline
        ? roi.netReturn >= 0 ? "Positive return" : "Below break-even"
        : "Baseline needed";
  const performanceSummary = roiError
    ? "The finance records for this view could not be loaded."
    : shortRange
      ? `${formatCurrency(roiRevenue)} in sales this period. The farm needs ${formatCurrency(requiredPeriodSales)} to stay on track.`
      : `${formatCurrency(roi.netReturn)} remains after the recorded costs in this year's view.`;
  const estimatedRecoveryDays = recovery.averageDailySales > 0
    ? recovery.remainingInvestment / recovery.averageDailySales
    : null;
  const recoveryEstimate = recovery.remainingInvestment <= 0
    ? "Fully recovered"
    : estimatedRecoveryDays === null
      ? "Not enough sales data"
      : estimatedRecoveryDays < 30.44
        ? "Less than 1 month"
        : estimatedRecoveryDays >= 365
          ? `${(estimatedRecoveryDays / 365).toFixed(1)} years`
          : `${Math.ceil(estimatedRecoveryDays / 30.44)} months`;
  return (
    <div className={styles.page}>
        <header className={styles.header}>
          <ModuleHeaderIntro mascot="investments"><p className={styles.eyebrow}>Operations</p><h1>Investments</h1><p>Farm costs, recurring expenses, receipts, and due dates.</p></ModuleHeaderIntro>
          <div className={styles.liveDateTime}><LiveDateTime /></div>
      </header>

      {error ? <section className={styles.notice}><strong>Investment records are unavailable.</strong><span>{error.message}</span></section> : null}
      {needsExpandedMigration && !error ? <section className={styles.notice}><strong>Expanded investment details need a database update.</strong><span>Existing records are shown below. Apply the latest Supabase migration to use vendor, receipt, recurring, crop, and inventory fields.</span></section> : null}

      <section className={styles.metricGrid} aria-label="Investment summary">
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><ReceiptText size={20} /></span><p>Total records</p></div><CountUpValue className="mono" value={expenses.length} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><CircleDollarSign size={20} /></span><p>Total farm costs</p></div><CountUpValue className="mono" currency value={totalInvestment} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><CalendarDays size={20} /></span><p>This month</p></div><CountUpValue className="mono" currency value={monthlyInvestment} /></article>
        <article className={styles.metric}><div className={styles.metricMeta}><span className={styles.metricIcon}><Banknote size={20} /></span><p>Top category</p></div><strong>{topCategory}</strong></article>
      </section>

      <div className={styles.quickActionArea}>
        <InvestmentsWorkspace />
      </div>

      <div className={styles.investmentsLowerGrid}>
        <section className={styles.roiSection} aria-labelledby="roi-heading">
        <header className={styles.roiHeader}>
          <div>
            <p className={styles.eyebrow}>Farm health</p>
            <h2 id="roi-heading">Investment performance</h2>
          </div>
          <details className={styles.roiRangeSelect}>
            <summary><span>{roiRangeLabel}</span><ChevronDown aria-hidden="true" size={17} /></summary>
            <div className={styles.roiRangeMenu} role="menu" aria-label="Select ROI date range">
              {roiRanges.map((range) => (
                <Link
                  aria-current={roiRange === range.value ? "page" : undefined}
                  data-active={roiRange === range.value ? "true" : "false"}
                  href={`/investments?range=${range.value}`}
                  key={range.value}
                  role="menuitem"
                >
                  {range.label}
                </Link>
              ))}
            </div>
          </details>
        </header>

        {roiError ? (
          <div className={styles.roiNotice}>
            <strong>ROI details are unavailable.</strong>
            <span>{roiError.message}</span>
          </div>
        ) : null}

        <div className={`${styles.roiStatusBanner} ${styles.roiOwnerStatus}`} data-tone={roiTone}>
          <div className={styles.roiStatusLead}>
            <div>
              <span>Performance status</span>
              <strong>{performanceStatus}</strong>
              <p>{performanceSummary}</p>
            </div>
          </div>
          <div className={styles.roiStatusRecovery}>
            <div>
              <span>Investment recovered</span>
              <strong>{recovery.totalInvestment > 0 ? `${recovery.recoveryRate.toFixed(1)}%` : "No baseline"}</strong>
            </div>
            <div className={styles.roiRecoveryTrack} aria-hidden="true"><span data-tone={roiTone} style={{ width: `${recoveryWidth}%` }} /></div>
            <small>{recovery.totalInvestment > 0 ? `${formatCurrency(recovery.recoveredSales)} recovered of ${formatCurrency(recovery.totalInvestment)} total costs` : "Record farm costs to start tracking recovery."}</small>
          </div>
        </div>

        <div className={styles.roiOwnerStats}>
          <article>
            <span className={styles.roiOwnerStatIcon}><CircleDollarSign size={18} /></span>
            <div><small>Invested</small><strong>{formatCurrency(recovery.totalInvestment)}</strong><p>Capital and operating costs</p></div>
          </article>
          <article>
            <span className={styles.roiOwnerStatIcon}><TrendingUp size={18} /></span>
            <div><small>Recovered</small><strong>{formatCurrency(recovery.recoveredSales)}</strong><p>Sales after operating costs</p></div>
          </article>
          <article>
            <span className={styles.roiOwnerStatIcon}><Banknote size={18} /></span>
            <div><small>To recover</small><strong>{formatCurrency(recovery.remainingInvestment)}</strong><p>Remaining farm costs</p></div>
          </article>
        </div>

        <div className={styles.roiOwnerDetails}>
          <article>
            <small>Estimated recovery time</small>
            <strong>{roiError ? "Unavailable" : recoveryEstimate}</strong>
            <p>Based on the current sales pace.</p>
          </article>
          <article>
            <small>Cost breakdown</small>
            <div className={styles.roiCostBreakdown}>
              <span><small>Capital</small><strong>{formatCurrency(totalCapitalInvestment)}</strong></span>
              <span><small>Operating</small><strong>{formatCurrency(operatingExpensesSinceInvestment)}</strong></span>
            </div>
          </article>
        </div>

        </section>

        <section className={styles.listSection}>
          <header className={styles.sectionHeader}><div><p className={styles.eyebrow}>Farm cost list</p><h2>Cost history</h2></div></header>
          <InvestmentHistory records={expenses.map((expense) => ({ id: expense.id, description: expense.description, category: expense.category, amount: Number(expense.amount), expenseDate: expense.expense_date, vendor: expense.vendor, paymentMethod: expense.payment_method, referenceNumber: expense.reference_number, expenseType: expense.expense_type, cropName: expense.related_crop_id ? cropNames.get(expense.related_crop_id) ?? null : null, inventoryName: expense.related_inventory_id ? inventoryNames.get(expense.related_inventory_id) ?? null : null, quantity: expense.quantity === null ? null : Number(expense.quantity), unitCost: expense.unit_cost === null ? null : Number(expense.unit_cost), notes: expense.notes, hasReceipt: Boolean(expense.receipt_path), receiptUrl: receiptUrls.get(expense.id) ?? null, receiptFileName: expense.receipt_path?.split("/").pop() ?? null, receiptKind: expense.receipt_path?.toLowerCase().endsWith(".pdf") ? "pdf" as const : expense.receipt_path ? "image" as const : null }))} />
        </section>
      </div>
    </div>
  );
}
