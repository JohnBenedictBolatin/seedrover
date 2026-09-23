import Link from "next/link";
import { redirect } from "next/navigation";
import { Banknote, CalendarDays, CircleDollarSign, ReceiptText, Target, TrendingUp, WalletCards } from "lucide-react";
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
  const investmentStartDate = capitalExpenses
    .map((expense) => expense.expense_date)
    .sort((left, right) => left.localeCompare(right))[0] ?? null;
  const investmentStartIso = investmentStartDate ? `${investmentStartDate}T00:00:00.000Z` : roiStartIso;
  const salesStartIso = new Date(investmentStartIso).getTime() < roiStart.getTime()
    ? investmentStartIso
    : roiStartIso;

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

  const roiError = receiptSalesResult.error ?? marketSalesResult.error;
  const roiStartDate = roiStartIso.slice(0, 10);
  const roiExpenses = expenses.filter((expense) => expense.expense_date >= roiStartDate);
  const allSales = [...(receiptSalesResult.data ?? []), ...(marketSalesResult.data ?? [])];
  const roiSales = allSales.filter((sale) => new Date(sale.sale_date).getTime() >= roiStart.getTime());
  const recoveredSales = investmentStartDate
    ? allSales
        .filter((sale) => new Date(sale.sale_date).getTime() >= new Date(investmentStartIso).getTime())
        .reduce((total, sale) => total + Number(sale.total_amount), 0)
    : 0;
  const roiInvestment = roiExpenses
    .filter((expense) => isCapitalInvestmentType(expense.expense_type))
    .reduce((total, row) => total + Number(row.amount), 0);
  const operatingExpenses = roiExpenses
    .filter((expense) => isOperatingExpenseType(expense.expense_type))
    .reduce((total, row) => total + Number(row.amount), 0);
  const operatingExpensesSinceInvestment = investmentStartDate
    ? expenses
        .filter((expense) => expense.expense_date >= investmentStartDate && isOperatingExpenseType(expense.expense_type))
        .reduce((total, expense) => total + Number(expense.amount), 0)
    : 0;
  const roiRevenue = roiSales.reduce((total, row) => total + Number(row.total_amount), 0);
  const roi = calculateRoiBreakdown(Math.max(0, roiRevenue - operatingExpenses), roiInvestment);
  const recovery = calculateRecoveryProjection({
    periodSales: roiRevenue,
    periodStart: roiStart,
    recoveredSales: Math.max(0, recoveredSales - operatingExpensesSinceInvestment),
    totalInvestment: totalCapitalInvestment,
  });
  const requiredPeriodSales = getRecoveryTargetForPeriod(recovery.remainingInvestment, roiRange)
    + operatingExpenses;
  const roiRangeLabel = roiRanges.find((range) => range.value === roiRange)?.label ?? "Month";
  const periodTargetLabel = roiRange === "day"
    ? "Daily"
    : roiRange === "week"
      ? "Weekly"
      : roiRange === "month"
        ? "Monthly"
        : "Yearly";
  const targetFormula = roiRange === "day"
    ? "Remaining investment / 365 days + today's operating expenses"
    : roiRange === "week"
      ? "Remaining investment / 52.14 weeks + this week's operating expenses"
      : roiRange === "month"
        ? "Remaining investment / 12 months + this month's operating expenses"
        : "Remaining investment + this year's operating expenses";
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
  const roiCategoryTotals = new Map<string, number>();
  roiExpenses.forEach((expense) => {
    const category = expense.category?.trim() || "Uncategorized";
    roiCategoryTotals.set(category, (roiCategoryTotals.get(category) ?? 0) + Number(expense.amount));
  });
  const roiExpenseTotal = roiExpenses.reduce((total, expense) => total + Number(expense.amount), 0);
  const roiCategories = [...roiCategoryTotals.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, 5)
    .map(([category, amount]) => ({
      category,
      amount,
      share: roiExpenseTotal > 0 ? (amount / roiExpenseTotal) * 100 : 0,
    }));

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

      <section className={styles.roiSection} aria-labelledby="roi-heading">
        <header className={styles.roiHeader}>
          <div>
            <p className={styles.eyebrow}>Return analysis</p>
            <h2 id="roi-heading">Investment performance</h2>
            <span>{shortRange ? `Current sales compared with the ${periodTargetLabel.toLowerCase()} target for recovering one-time investments within a year.` : "Year-to-date sales, the annual recovery target, and sales-based ROI after recorded expenses."}</span>
          </div>
          <nav className={styles.roiRangeTabs} aria-label="Select ROI date range">
            {roiRanges.map((range) => (
              <Link
                aria-current={roiRange === range.value ? "page" : undefined}
                data-active={roiRange === range.value ? "true" : "false"}
                href={`/investments?range=${range.value}`}
                key={range.value}
              >
                {range.label}
              </Link>
            ))}
          </nav>
        </header>

        {roiError ? (
          <div className={styles.roiNotice}>
            <strong>ROI details are unavailable.</strong>
            <span>{roiError.message}</span>
          </div>
        ) : null}

        <div className={styles.roiOverview}>
          <article className={styles.roiScoreCard} data-tone={roiTone}>
            <div className={styles.roiScoreLabel}>
              <span aria-hidden="true"><TrendingUp size={20} /></span>
              <p>{periodTargetLabel} recovery target</p>
            </div>
            {roiError ? (
              <strong className={styles.roiScoreValue}>Unavailable</strong>
            ) : recovery.totalInvestment > 0 ? (
              <CountUpValue className={styles.roiScoreValue} currency value={requiredPeriodSales} />
            ) : (
              <strong className={styles.roiScoreValue}>--</strong>
            )}
            <p className={styles.roiScoreSummary}>
              {roiError
                ? "The required finance records could not be loaded."
                : recovery.status === "no-baseline"
                  ? "Record a one-time investment to establish a recovery target."
                  : `${recoveryStatusLabel}. Current ${roiRangeLabel.toLowerCase()} sales: ${formatCurrency(roiRevenue)}.`}
            </p>
            <div className={styles.roiFormula}>
              <span>FORMULA</span>
              <p>{targetFormula}</p>
            </div>
          </article>

          <div className={styles.roiCalculation}>
            <div className={styles.roiCalculationHeader}>
              <div>
                <span>Calculation</span>
                <h3>{shortRange ? `${periodTargetLabel} sales and recovery target` : "Yearly recovery and ROI"}</h3>
              </div>
              <small>{shortRange ? `${recovery.daysObserved} ${recovery.daysObserved === 1 ? "day" : "days"} observed` : `${roiRangeLabel} period`}</small>
            </div>
            <div className={styles.roiCalculationRows}>
              {shortRange ? (
                <>
                  <div>
                    <span>Current {roiRangeLabel.toLowerCase()} sales</span>
                    <strong>{formatCurrency(roiRevenue)}</strong>
                  </div>
                  <div>
                    <span>{periodTargetLabel} recovery target</span>
                    <strong>{recovery.totalInvestment > 0 ? formatCurrency(requiredPeriodSales) : "Not available"}</strong>
                  </div>
                  <div data-total="true">
                    <span>Projected sales over 12 months</span>
                    <strong>{formatCurrency(recovery.projectedAnnualSales)}</strong>
                  </div>
                </>
              ) : (
                <>
                  <div>
                    <span>Completed sales</span>
                    <strong>{formatCurrency(roiRevenue)}</strong>
                  </div>
                  <div>
                    <span>Operating expenses</span>
                    <strong>- {formatCurrency(operatingExpenses)}</strong>
                  </div>
                  <div>
                    <span>Capital investments</span>
                    <strong>- {formatCurrency(roiInvestment)}</strong>
                  </div>
                  <div data-total="true">
                    <span>Sales-based net return</span>
                    <strong>{formatCurrency(roi.netReturn)}</strong>
                  </div>
                </>
              )}
            </div>
            <div className={styles.roiRecovery}>
              <div>
                <span>All-time investment recovery</span>
                <strong>{recovery.totalInvestment > 0 ? `${recovery.recoveryRate.toFixed(1)}%` : "Not available"}</strong>
              </div>
              <div className={styles.roiRecoveryTrack} aria-hidden="true">
                <span data-tone={roiTone} style={{ width: `${recoveryWidth}%` }} />
              </div>
              <p>{formatCurrency(recovery.recoveredSales)} in completed sales remains after recorded operating expenses since the first capital investment, against {formatCurrency(recovery.totalInvestment)} invested.</p>
            </div>
          </div>
        </div>

        <div className={styles.roiInsightGrid}>
          {shortRange ? (
            <>
              <article>
                <span className={styles.roiInsightIcon}><Target size={19} /></span>
                <div><p>{periodTargetLabel} recovery target</p><strong>{recovery.totalInvestment > 0 ? formatCurrency(requiredPeriodSales) : "No baseline"}</strong></div>
              </article>
              <article>
                <span className={styles.roiInsightIcon}><WalletCards size={19} /></span>
                <div><p>Projected 12-month sales</p><strong>{formatCurrency(recovery.projectedAnnualSales)}</strong></div>
              </article>
              <article>
                <span className={styles.roiInsightIcon}><ReceiptText size={19} /></span>
                <div><p>Remaining investment</p><strong>{recovery.totalInvestment > 0 ? formatCurrency(recovery.remainingInvestment) : "No baseline"}</strong></div>
              </article>
            </>
          ) : (
            <>
              <article>
                <span className={styles.roiInsightIcon}><Target size={19} /></span>
                <div><p>Break-even position</p><strong>{roi.hasInvestmentBaseline ? roi.breakEvenGap > 0 ? `${formatCurrency(roi.breakEvenGap)} needed` : `${formatCurrency(roi.netReturn)} surplus` : "No baseline"}</strong></div>
              </article>
              <article>
                <span className={styles.roiInsightIcon}><WalletCards size={19} /></span>
                <div><p>Sales after operating costs per PHP 1 invested</p><strong>{roi.hasInvestmentBaseline ? `PHP ${roi.revenuePerPeso.toFixed(2)}` : "Not available"}</strong></div>
              </article>
              <article>
                <span className={styles.roiInsightIcon}><ReceiptText size={19} /></span>
                <div><p>Records analyzed</p><strong>{roiExpenses.length} expenses / {roiSales.length} sales</strong></div>
              </article>
            </>
          )}
        </div>

        <div className={styles.roiAllocation}>
          <div className={styles.roiAllocationHeader}>
            <div><span>Investment allocation</span><h3>Spending by category</h3></div>
            <small>{roiRangeLabel} period</small>
          </div>
          {roiCategories.length > 0 ? (
            <div className={styles.roiCategoryList}>
              {roiCategories.map((category) => (
                <div className={styles.roiCategoryRow} key={category.category}>
                  <div><span>{category.category}</span><strong>{formatCurrency(category.amount)}</strong></div>
                  <div className={styles.roiCategoryTrack} aria-hidden="true"><span style={{ width: `${category.share}%` }} /></div>
                  <small>{category.share.toFixed(1)}%</small>
                </div>
              ))}
            </div>
          ) : (
            <div className={styles.roiAllocationEmpty}>No investments were recorded in this period.</div>
          )}
        </div>

        <p className={styles.roiDisclaimer}>
          {shortRange ? "The target includes operating expenses actually recorded in the selected period. The forecast does not predict bills that have not been entered." : "The yearly target includes operating expenses recorded this year. ROI remains sales-based because historical cost-of-goods snapshots are not available."}
        </p>
      </section>

      <InvestmentsWorkspace crops={(cropRows ?? []).map((crop) => ({ id: crop.id, name: crop.crop_name }))} inventoryItems={(inventoryRows ?? []).map((item) => ({ id: item.id, name: item.item_name }))} />

      <section className={styles.listSection}>
        <header className={styles.sectionHeader}><div><p className={styles.eyebrow}>Farm cost list</p><h2>Cost history</h2></div></header>
        <InvestmentHistory records={expenses.map((expense) => ({ id: expense.id, description: expense.description, category: expense.category, amount: Number(expense.amount), expenseDate: expense.expense_date, vendor: expense.vendor, paymentMethod: expense.payment_method, referenceNumber: expense.reference_number, expenseType: expense.expense_type, cropName: expense.related_crop_id ? cropNames.get(expense.related_crop_id) ?? null : null, inventoryName: expense.related_inventory_id ? inventoryNames.get(expense.related_inventory_id) ?? null : null, quantity: expense.quantity === null ? null : Number(expense.quantity), unitCost: expense.unit_cost === null ? null : Number(expense.unit_cost), notes: expense.notes, hasReceipt: Boolean(expense.receipt_path), receiptUrl: receiptUrls.get(expense.id) ?? null, receiptFileName: expense.receipt_path?.split("/").pop() ?? null, receiptKind: expense.receipt_path?.toLowerCase().endsWith(".pdf") ? "pdf" as const : expense.receipt_path ? "image" as const : null }))} />
      </section>
    </div>
  );
}
