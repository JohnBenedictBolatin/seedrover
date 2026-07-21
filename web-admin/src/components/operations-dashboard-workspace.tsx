"use client";

import Link from "next/link";
import {
  AlertTriangle,
  Package,
  ReceiptText,
  TrendingUp,
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
import { formatCurrency, formatDateTime } from "@/lib/format";
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
  data: OperationsDashboardData;
};

export function OperationsDashboardWorkspace({ data }: OperationsDashboardWorkspaceProps) {
  const summaryCards = [
    {
      icon: <TrendingUp size={20} />,
      label: "Sales in range",
      value: data.summary.salesInRange,
      currency: true,
    },
    {
      icon: <ReceiptText size={20} />,
      label: "Transactions",
      value: data.summary.transactionsInRange,
    },
    {
      icon: <Package size={20} />,
      label: "Inventory value",
      value: data.summary.inventoryValue,
      currency: true,
    },
    {
      icon: <AlertTriangle size={20} />,
      label: "Low stock",
      value: data.summary.lowStockItems,
    },
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
          <p className={styles.eyebrow}>Analysis range</p>
          <h2>Farm overview</h2>
          <span>Charts and insights update using the selected period.</span>
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
            <CountUpValue className="mono" currency={card.currency} value={card.value} />
          </article>
        ))}
      </section>

      <section className={styles.analysisPanel} aria-label="Operations insights">
        <div>
          <p className={styles.eyebrow}>Clear analysis</p>
          <h2>What matters right now</h2>
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
          description="Completed receipt and Market Distribution sales."
          title="Sales trend"
        >
          <AreaValueChart data={data.charts.salesTrend} />
        </ChartPanel>

        <ChartPanel description="Revenue grouped by vegetable/category." title="Sales by category">
          <PieValueChart data={data.charts.salesByCategory} />
        </ChartPanel>

        <ChartPanel description="Current estimated stock cost by category." title="Stock value">
          <BarValueChart currency data={data.charts.stockValueByCategory} />
        </ChartPanel>

        <ChartPanel description="Stock in, out, and adjustment activity." title="Stock movement">
          <StockMovementLineChart data={data.charts.stockMovement} />
        </ChartPanel>

        <ChartPanel description="Payment methods used in completed sales." title="Payment breakdown">
          <PieValueChart data={data.charts.paymentMethods} />
        </ChartPanel>

        <ChartPanel description="Quantity sold by crop/item." title="Top-selling items">
          <BarValueChart data={data.charts.topItems} />
        </ChartPanel>

      </section>

      <section className={styles.detailGrid} aria-label="Operational detail lists">
        <article className={styles.listPanel}>
          <div className={styles.sectionHeader}>
            <div>
              <p className={styles.eyebrow}>Risk watch</p>
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
            <EmptyState text="No low stock records for now." />
          )}
        </article>

        <article className={styles.listPanel}>
          <div className={styles.sectionHeader}>
            <div>
              <p className={styles.eyebrow}>Live operations</p>
              <h2>Recent activity</h2>
            </div>
            <span className={styles.panelPill}>{data.summary.roverStatus}</span>
          </div>
          {data.recentActivity.length > 0 ? (
            <div className={styles.activityList}>
              {data.recentActivity.map((activity) => (
                <div className={styles.activityItem} data-type={activity.type} key={`${activity.type}-${activity.id}`}>
                  <span>{activity.type === "sale" ? <ReceiptText size={16} /> : <Package size={16} />}</span>
                  <div>
                    <strong>{activity.label}</strong>
                    <p>{activity.detail}</p>
                  </div>
                  <div>
                    <strong>
                      {activity.type === "sale"
                        ? formatCurrency(Number(activity.value))
                        : activity.value}
                    </strong>
                    <p>{formatDateTime(activity.createdAt)}</p>
                  </div>
                </div>
              ))}
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
  title,
}: {
  children: React.ReactNode;
  description: string;
  title: string;
}) {
  return (
    <article className={styles.chartPanel}>
      <div className={styles.chartHeader}>
        <div>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
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

  return (
    <ResponsiveContainer height="100%" width="100%">
      <PieChart>
        <Tooltip content={<ChartTooltip currency />} />
        <Pie cx="50%" cy="50%" data={data} dataKey="value" innerRadius={46} outerRadius={80} paddingAngle={4}>
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
