export type RoiBreakdown = {
  sales: number;
  investment: number;
  netReturn: number;
  roi: number;
  recoveryRate: number;
  revenuePerPeso: number;
  breakEvenGap: number;
  hasInvestmentBaseline: boolean;
};

export type RecoveryProjection = {
  averageDailySales: number;
  daysObserved: number;
  projectedAnnualSales: number;
  projectedRecoveryRate: number;
  recoveredSales: number;
  recoveryRate: number;
  remainingInvestment: number;
  requiredDailySales: number;
  status: "no-baseline" | "recovered" | "on-track" | "behind";
  totalInvestment: number;
};

export type RecoveryPeriod = "day" | "week" | "month" | "year";

export function isOperatingExpenseType(expenseType: string | null | undefined) {
  return expenseType === "Operating expense" || expenseType === "Recurring expense";
}

export function isCapitalInvestmentType(expenseType: string | null | undefined) {
  return !isOperatingExpenseType(expenseType);
}

export function getRecoveryTargetForPeriod(remainingInvestment: number, period: RecoveryPeriod) {
  const safeRemainingInvestment = Number.isFinite(remainingInvestment)
    ? Math.max(0, remainingInvestment)
    : 0;

  if (period === "day") {
    return safeRemainingInvestment / 365;
  }

  if (period === "week") {
    return safeRemainingInvestment / (365 / 7);
  }

  if (period === "month") {
    return safeRemainingInvestment / 12;
  }

  return safeRemainingInvestment;
}

export function calculateRoiBreakdown(sales: number, investment: number): RoiBreakdown {
  const safeSales = Number.isFinite(sales) ? Math.max(0, sales) : 0;
  const safeInvestment = Number.isFinite(investment) ? Math.max(0, investment) : 0;
  const hasInvestmentBaseline = safeInvestment > 0;
  const netReturn = safeSales - safeInvestment;

  return {
    sales: safeSales,
    investment: safeInvestment,
    netReturn,
    roi: hasInvestmentBaseline ? (netReturn / safeInvestment) * 100 : 0,
    recoveryRate: hasInvestmentBaseline ? (safeSales / safeInvestment) * 100 : 0,
    revenuePerPeso: hasInvestmentBaseline ? safeSales / safeInvestment : 0,
    breakEvenGap: Math.max(0, safeInvestment - safeSales),
    hasInvestmentBaseline,
  };
}

export function calculateRecoveryProjection({
  asOf = new Date(),
  periodSales,
  periodStart,
  recoveredSales,
  totalInvestment,
}: {
  asOf?: Date;
  periodSales: number;
  periodStart: Date;
  recoveredSales: number;
  totalInvestment: number;
}): RecoveryProjection {
  const dayMs = 24 * 60 * 60 * 1000;
  const safePeriodSales = Number.isFinite(periodSales) ? Math.max(0, periodSales) : 0;
  const safeRecoveredSales = Number.isFinite(recoveredSales) ? Math.max(0, recoveredSales) : 0;
  const safeInvestment = Number.isFinite(totalInvestment) ? Math.max(0, totalInvestment) : 0;
  const elapsedMs = Math.max(0, asOf.getTime() - periodStart.getTime());
  const daysObserved = Math.max(1, Math.ceil(elapsedMs / dayMs));
  const averageDailySales = safePeriodSales / daysObserved;
  const projectedAnnualSales = averageDailySales * 365;
  const remainingInvestment = Math.max(0, safeInvestment - safeRecoveredSales);
  const requiredDailySales = remainingInvestment / 365;
  const recoveryRate = safeInvestment > 0 ? (safeRecoveredSales / safeInvestment) * 100 : 0;
  const projectedRecoveryRate = safeInvestment > 0
    ? ((safeRecoveredSales + projectedAnnualSales) / safeInvestment) * 100
    : 0;
  const status = safeInvestment <= 0
    ? "no-baseline"
    : remainingInvestment <= 0
      ? "recovered"
      : averageDailySales >= requiredDailySales
        ? "on-track"
        : "behind";

  return {
    averageDailySales,
    daysObserved,
    projectedAnnualSales,
    projectedRecoveryRate,
    recoveredSales: safeRecoveredSales,
    recoveryRate,
    remainingInvestment,
    requiredDailySales,
    status,
    totalInvestment: safeInvestment,
  };
}
