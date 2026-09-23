"use client";

import { useState } from "react";
import Link from "next/link";
import {
  ArrowUpRight,
  Package,
  PackageMinus,
  PackagePlus,
  AlertTriangle,
  PackageX,
  ReceiptText,
  SlidersHorizontal,
  TrendingUp,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { CountUpValue } from "@/components/count-up-value";
import type {
  DashboardPoint,
  DashboardRange,
  OperationsDashboardData,
  StockMovementPoint,
} from "@/lib/dashboard";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import styles from "@/app/(portal)/dashboard/page.module.css";

const ranges: Array<{ label: string; value: DashboardRange }> = [
  { label: "Day", value: "day" },
  { label: "Week", value: "week" },
  { label: "Month", value: "month" },
  { label: "Year", value: "year" },
];

const chartColors = [
  "var(--chart-series-1)",
  "var(--chart-series-2)",
  "var(--chart-series-3)",
  "var(--chart-series-4)",
  "var(--chart-series-5)",
  "var(--chart-series-6)",
];
const chartFillColors = [
  "var(--chart-fill-1)",
  "var(--chart-fill-2)",
  "var(--chart-fill-3)",
  "var(--chart-fill-4)",
  "var(--chart-fill-5)",
  "var(--chart-fill-6)",
];

type OperationsDashboardWorkspaceProps = {
  canViewInvestments: boolean;
  isInventoryManager: boolean;
  data: OperationsDashboardData;
};

export function OperationsDashboardWorkspace({ canViewInvestments, isInventoryManager, data }: OperationsDashboardWorkspaceProps) {
  const [activityPage, setActivityPage] = useState(1);
  const activityPageSize = 5;
  const activityPageCount = Math.max(1, Math.ceil(data.recentActivity.length / activityPageSize));
  const visibleActivity = data.recentActivity.slice(
    (activityPage - 1) * activityPageSize,
    activityPage * activityPageSize,
  );
  const recoveryStatus = data.summary.recoveryStatus === "recovered"
    ? "Investment recovered"
    : data.summary.recoveryStatus === "on-track"
      ? "On track"
      : data.summary.recoveryStatus === "behind"
        ? "Below target"
        : "No investment baseline";
  const recoveryRangeLabel = data.range === "day"
    ? "Daily"
    : data.range === "week"
      ? "Weekly"
        : data.range === "month"
          ? "Monthly"
          : "Yearly";
  const topSalesCategory = data.charts.salesByCategory[0];
  const topSellingItem = data.charts.topItems[0];
  const stockInTotal = data.charts.stockMovement.reduce((total, point) => total + point.in, 0);
  const stockOutTotal = data.charts.stockMovement.reduce((total, point) => total + point.out, 0);
  const summaryCards = [
    {
      icon: <TrendingUp size={20} />,
      label: "Sales total",
      value: data.summary.salesInRange,
      currency: true,
    },
    {
      icon: <ReceiptText size={20} />,
      label: "Transactions",
      value: data.summary.transactionsInRange,
    },
    ...(canViewInvestments ? [{
      icon: <Package size={20} />,
      label: "Inventory value",
      value: data.summary.inventoryValue,
      currency: true,
    },
    {
      icon: <TrendingUp size={20} />,
      label: `${recoveryRangeLabel} ROI target`,
      value: data.summary.requiredPeriodSales,
      currency: true,
      suffix: undefined,
      secondary: recoveryStatus,
      detailsHref: canViewInvestments ? `/investments?range=${data.range}` : undefined,
    }] : []),
    ...(isInventoryManager ? [
      {
        icon: <AlertTriangle size={20} />,
        label: "Low-stock items",
        value: data.summary.lowStockItems,
        detailsHref: "/inventory",
      },
      {
        icon: <PackageX size={20} />,
        label: "Out-of-stock items",
        value: data.summary.outOfStockItems,
        detailsHref: "/inventory",
      },
    ] : []),
  ];

  const insights = [
    {
      label: "Best seller",
      value: data.insights.bestSellingItem,
    },
    {
      label: "Strongest category",
      value: data.insights.strongestCategory,
    },
    {
      label: "Top payment",
      value: data.insights.preferredPaymentMethod,
    },
    {
      label: "Rover",
      value: data.insights.roverWarning,
    },
  ];

  return (
    <>
      <section className={styles.rangePanel} aria-label="Dashboard range selector">
        <div>
          <h2>Farm overview</h2>
        </div>
        <div className={styles.rangeTabs} aria-label="Select dashboard date range">
          {ranges.map((range) => (
            <Link
              aria-current={data.range === range.value ? "page" : undefined}
              className={data.range === range.value ? styles.rangeTabActive : styles.rangeTab}
              href={`/dashboard?range=${range.value}`}
              key={range.value}
            >
              {range.label}
            </Link>
          ))}
        </div>
      </section>

      <section className={styles.metricGrid} aria-label="Operations summary">
        {summaryCards.map((card) => (
          <article className={styles.metric} key={card.label}>
            <div className={styles.metricMeta}>
              <span className={styles.metricIcon}>{card.icon}</span>
              <p>{card.label}</p>
            </div>
          <div className={styles.metricValue}>
            <CountUpValue className="mono" currency={card.currency} value={card.value} suffix={card.suffix} />
            {card.secondary ? <small className={styles.metricSecondary}>{card.secondary}</small> : null}
            {card.detailsHref ? <Link className={styles.metricDetailLink} href={card.detailsHref}>VIEW DETAILS <ArrowUpRight size={13} /></Link> : null}
          </div>
          </article>
        ))}
      </section>

      <section className={styles.analysisPanel} aria-label="Operations insights">
        <div>
          <p className={styles.eyebrow}>Highlights</p>
          <h2>Current operations</h2>
        </div>
        <div className={styles.analysisList}>
          {insights.map((insight) => (
            <div key={insight.label}>
              <span>{insight.label}</span>
              <strong>{insight.value}</strong>
            </div>
          ))}
        </div>
      </section>

      <section className={styles.chartGrid} aria-label="Operations charts">
        <ChartPanel
          description="Completed sales only."
          summary={[
            { value: formatCurrency(data.summary.salesInRange), label: "Completed sales" },
            { value: formatCurrency(data.summary.averageSale), label: "Average sale" },
          ]}
          title="Sales trend"
        >
          <AreaValueChart data={data.charts.salesTrend} />
        </ChartPanel>

        <ChartPanel
          description="Completed sales grouped by inventory category."
          summary={[
            { value: formatCurrency(data.summary.salesInRange), label: "Total sales" },
            { value: topSalesCategory?.label ?? "No category sales", label: "Top category" },
          ]}
          title="Sales by category"
        >
          <PieValueChart data={data.charts.salesByCategory} />
        </ChartPanel>

        <ChartPanel
          description="Current quantity × unit cost."
          summary={[
            { value: formatCurrency(data.summary.inventoryValue), label: "Current value" },
            { value: formatCurrency(data.summary.estimatedSalesValue), label: "Est. sales value" },
          ]}
          title="Stock value"
        >
          <BarValueChart currency data={data.charts.stockValueByCategory} />
        </ChartPanel>

        <ChartPanel
          summary={[
            { value: formatQuantity(stockInTotal, "kg"), label: "Stock in" },
            { value: formatQuantity(stockOutTotal, "kg"), label: "Stock out" },
          ]}
          title="Stock movement"
        >
          <StockMovementLineChart data={data.charts.stockMovement} />
        </ChartPanel>

        <ChartPanel
          summary={[
            { value: formatCurrency(data.summary.salesInRange), label: "Completed sales" },
            { value: data.insights.preferredPaymentMethod, label: "Top method" },
          ]}
          title="Payment breakdown"
        >
          <PieValueChart data={data.charts.paymentMethods} />
        </ChartPanel>

        <ChartPanel
          summary={[
            { value: formatQuantity(topSellingItem?.value ?? 0, "kg"), label: "Top item sold" },
            { value: topSellingItem?.label ?? "No sales yet", label: "Best seller" },
          ]}
          title="Top-selling items"
        >
          <BarValueChart data={data.charts.topItems} />
        </ChartPanel>

      </section>

      <section className={styles.detailGrid} aria-label="Operational detail lists">
        <article className={styles.listPanel}>
          <div className={styles.sectionHeader}>
            <div>
              <p className={styles.eyebrow}>Inventory</p>
              <h2>Low stock items</h2>
            </div>
            <span className={styles.panelPill}>{data.insights.stockWarning}</span>
          </div>
          {data.lowStock.length > 0 ? (
            <div className={styles.riskList}>
              {data.lowStock.map((item) => (
                <div className={styles.riskItem} data-status={item.status} key={item.id}>
                  <div>
                    <strong>{item.itemName}</strong>
                    <span>{item.category}</span>
                  </div>
                  <div>
                    <strong>{item.quantity}</strong>
                    <span>{item.unit}</span>
                  </div>
                  <em>{item.status}</em>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState text="No low-stock items." />
          )}
        </article>

        <article className={styles.listPanel}>
          <div className={styles.sectionHeader}>
            <div>
              <p className={styles.eyebrow}>Activity</p>
              <h2>Recent activity</h2>
            </div>
            <span className={styles.panelPill}>{data.summary.roverStatus}</span>
          </div>
          {data.recentActivity.length > 0 ? (
            <div className={styles.activityList}>
              {visibleActivity.map((activity) => (
                <div className={styles.activityItem} data-type={activity.type} key={`${activity.type}-${activity.id}`}>
                  <span className={styles.activityIcon}>
                    {activity.type === "sale" ? <ReceiptText size={17} /> : null}
                    {activity.type === "stock-in" ? <PackagePlus size={17} /> : null}
                    {activity.type === "stock-out" ? <PackageMinus size={17} /> : null}
                    {activity.type === "stock-adjustment" ? <SlidersHorizontal size={17} /> : null}
                  </span>
                  <div className={styles.activityContent}>
                    <div className={styles.activityHeading}>
                      <strong>{activity.action}</strong>
                      <span>{activity.label}</span>
                    </div>
                    <p>{activity.detail}</p>
                    <div className={styles.activityMetadata}>
                      {activity.metadata.map((item) => <span key={item}>{item}</span>)}
                    </div>
                  </div>
                  <div className={styles.activityValue}>
                    <strong>
                      {activity.type === "sale"
                        ? formatCurrency(Number(activity.value))
                        : activity.value}
                    </strong>
                    <p>{formatDateTime(activity.createdAt)}</p>
                  </div>
                </div>
              ))}
              {activityPageCount > 1 ? (
                <div className={styles.activityPagination}>
                  <button
                    aria-label="Previous activity page"
                    disabled={activityPage === 1}
                    type="button"
                    onClick={() => setActivityPage((page) => Math.max(1, page - 1))}
                  >
                    <ChevronLeft size={16} />
                  </button>
                  <span>Page {activityPage} of {activityPageCount}</span>
                  <button
                    aria-label="Next activity page"
                    disabled={activityPage === activityPageCount}
                    type="button"
                    onClick={() => setActivityPage((page) => Math.min(activityPageCount, page + 1))}
                  >
                    <ChevronRight size={16} />
                  </button>
                </div>
              ) : null}
            </div>
          ) : (
            <EmptyState text="No recent sales or stock movement in this range." />
          )}
        </article>
      </section>
    </>
  );
}

function ChartPanel({
  children,
  description,
  summary,
  title,
}: {
  children: React.ReactNode;
  description?: string;
  summary?: Array<{ value: string; label: string }>;
  title: string;
}) {
  return (
    <article className={styles.chartPanel}>
      <div className={styles.chartHeader}>
        <div className={styles.chartHeaderCopy}>
          <h2>{title}</h2>
          {description ? <p>{description}</p> : null}
        </div>
        {summary?.length ? (
          <div aria-label={`${title} summary`} className={styles.chartSummary}>
            {summary.map((item) => (
              <div className={styles.chartSummaryItem} key={item.label}>
                <strong>{item.value}</strong>
                <span>{item.label}</span>
              </div>
            ))}
          </div>
        ) : null}
      </div>
      <div className={styles.chartBox}>{children}</div>
    </article>
  );
}

function AreaValueChart({ data }: { data: DashboardPoint[] }) {
  if (data.length === 0) {
    return <EmptyState text="No sales data for this range." />;
  }

  return (
    <ResponsiveContainer height="100%" width="100%">
      <AreaChart data={data}>
        <defs>
          <linearGradient id="salesArea" x1="0" x2="0" y1="0" y2="1">
            <stop offset="5%" stopColor="var(--chart-series-1)" stopOpacity={0.24} />
            <stop offset="95%" stopColor="var(--chart-series-1)" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke="var(--chart-grid)" vertical={false} />
        <XAxis axisLine={false} dataKey="label" tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickLine={false} />
        <YAxis axisLine={false} tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickFormatter={(value) => formatCurrency(Number(value))} tickLine={false} width={54} />
        <Tooltip content={<ChartTooltip currency />} cursor={{ stroke: "var(--chart-cursor)", strokeWidth: 1 }} />
        <Area dataKey="value" fill="url(#salesArea)" stroke="var(--chart-series-1)" strokeWidth={2} type="monotone" />
      </AreaChart>
    </ResponsiveContainer>
  );
}

function BarValueChart({ currency = false, data }: { currency?: boolean; data: DashboardPoint[] }) {
  if (data.length === 0) {
    return <EmptyState text="No matching records yet." />;
  }

  return (
    <ResponsiveContainer height="100%" width="100%">
      <BarChart data={data}>
        <CartesianGrid stroke="var(--chart-grid)" vertical={false} />
        <XAxis axisLine={false} dataKey="label" tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickLine={false} />
        <YAxis axisLine={false} tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickFormatter={(value) => currency ? formatCurrency(Number(value)) : String(value)} tickLine={false} width={54} />
        <Tooltip content={<ChartTooltip currency={currency} />} cursor={{ fill: "var(--chart-cursor)" }} />
        <Bar dataKey="value" radius={[8, 8, 0, 0]}>
          {data.map((entry, index) => (
            <Cell
              fill={chartFillColors[index % chartFillColors.length]}
              key={entry.label}
              stroke={chartColors[index % chartColors.length]}
              strokeWidth={1}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}

function PieValueChart({ data }: { data: DashboardPoint[] }) {
  if (data.length === 0) {
    return <EmptyState text="No matching records yet." />;
  }

  const total = data.reduce((sum, entry) => sum + Number(entry.value), 0);

  return (
    <div className={styles.pieChartLayout}>
      <div className={styles.pieChartGraphic}>
        <ResponsiveContainer height="100%" width="100%">
          <PieChart>
            <Tooltip content={<ChartTooltip currency />} />
            <Pie
              cx="50%"
              cy="50%"
              data={data}
              dataKey="value"
              innerRadius={52}
              nameKey="label"
              outerRadius={82}
              paddingAngle={data.length > 1 ? 3 : 0}
            >
              {data.map((entry, index) => (
                <Cell
                  fill={chartFillColors[index % chartFillColors.length]}
                  key={entry.label}
                  stroke={chartColors[index % chartColors.length]}
                  strokeWidth={1}
                />
              ))}
            </Pie>
          </PieChart>
        </ResponsiveContainer>
        <div className={styles.pieChartCenter}>
          <span>Total</span>
          <strong>{formatCurrency(total)}</strong>
        </div>
      </div>

      <div aria-label="Chart breakdown" className={styles.pieLegend}>
        {data.map((entry, index) => {
          const percentage = total > 0 ? (Number(entry.value) / total) * 100 : 0;

          return (
            <div className={styles.pieLegendItem} key={entry.label}>
              <span
                aria-hidden="true"
                className={styles.pieLegendSwatch}
                style={{
                  background: chartFillColors[index % chartFillColors.length],
                  borderColor: chartColors[index % chartColors.length],
                }}
              />
              <div className={styles.pieLegendLabel}>
                <span>{entry.label}</span>
                <small>{percentage.toLocaleString(undefined, { maximumFractionDigits: 1 })}%</small>
              </div>
              <strong>{formatCurrency(Number(entry.value))}</strong>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function StockMovementLineChart({ data }: { data: StockMovementPoint[] }) {
  if (data.length === 0) {
    return <EmptyState text="No stock movement in this range." />;
  }

  return (
    <ResponsiveContainer height="100%" width="100%">
      <LineChart data={data}>
        <CartesianGrid stroke="var(--chart-grid)" vertical={false} />
        <XAxis axisLine={false} dataKey="label" tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickLine={false} />
        <YAxis axisLine={false} tick={{ fill: "var(--chart-axis)", fontSize: 11 }} tickLine={false} width={42} />
        <Tooltip content={<ChartTooltip />} cursor={{ stroke: "var(--chart-cursor)", strokeWidth: 1 }} />
        <Line activeDot={{ r: 4 }} dataKey="in" dot={{ r: 2 }} stroke="var(--chart-series-1)" strokeWidth={1.8} type="monotone" />
        <Line activeDot={{ r: 4 }} dataKey="out" dot={{ r: 2 }} stroke="var(--chart-series-6)" strokeWidth={1.8} type="monotone" />
        <Line activeDot={{ r: 4 }} dataKey="adjustment" dot={{ r: 2 }} stroke="var(--chart-series-2)" strokeWidth={1.8} type="monotone" />
      </LineChart>
    </ResponsiveContainer>
  );
}

function ChartTooltip({
  active,
  currency = false,
  label,
  payload,
}: {
  active?: boolean;
  currency?: boolean;
  label?: string;
  payload?: Array<{ name: string; value: number }>;
}) {
  if (!active || !payload?.length) {
    return null;
  }

  return (
    <div className={styles.chartTooltip}>
      <strong>{label ?? payload[0]?.name}</strong>
      {payload.map((item) => (
        <span key={item.name}>
          {item.name}: {currency ? formatCurrency(Number(item.value)) : item.value}
        </span>
      ))}
    </div>
  );
}

function EmptyState({ text }: { text: string }) {
  return (
    <div className={styles.emptyState}>
      <span className="mono">--</span>
      <p>{text}</p>
    </div>
  );
}
