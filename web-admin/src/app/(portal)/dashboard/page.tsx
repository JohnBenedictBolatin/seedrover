import { redirect } from "next/navigation";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { OperationsDashboardWorkspace } from "@/components/operations-dashboard-workspace";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getOperationsDashboard, normalizeDashboardRange } from "@/lib/dashboard";
import { getCropsDashboard } from "@/lib/crops";
import { CalendarDays, Sprout, TriangleAlert } from "lucide-react";
import styles from "./page.module.css";

type DashboardPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function DashboardPage({ searchParams }: DashboardPageProps) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Planting Staff") {
    redirect("/crops");
  }

  if (profile.roleName === "Inventory Staff") {
    redirect("/inventory");
  }

  if (profile.roleName === "Farm Planting Manager") {
    const { crops, summary, error } = await getCropsDashboard();
    const stageCounts = new Map<string, number>();
    const activeCrops = crops.filter((item) => item.cropStatus !== "Completed" && item.cropStatus !== "Cancelled");
    for (const crop of activeCrops) {
      stageCounts.set(crop.growthStage, (stageCounts.get(crop.growthStage) ?? 0) + 1);
    }
    const stageOrder = crops[0]?.stages ?? [];
    const stages = [...stageCounts.entries()].sort(([a], [b]) => {
      const aIndex = stageOrder.indexOf(a);
      const bIndex = stageOrder.indexOf(b);
      return (aIndex < 0 ? Number.MAX_SAFE_INTEGER : aIndex) - (bIndex < 0 ? Number.MAX_SAFE_INTEGER : bIndex) || a.localeCompare(b);
    });
    const maxStageCount = Math.max(1, ...stages.map(([, count]) => count));
    const attentionCrops = crops.filter((crop) => crop.cropStatus === "Needs Attention" || crop.tasks.some((task) => task.status === "Due" || task.status === "Overdue"));
    const cropStatuses = ["Active", "Needs Attention", "Harvest Ready"].map((status) => ({
      status,
      count: activeCrops.filter((crop) => crop.cropStatus === status).length,
    }));
    const harvestMonths = Array.from({ length: 6 }, (_, offset) => {
      const month = new Date();
      month.setDate(1);
      month.setHours(0, 0, 0, 0);
      month.setMonth(month.getMonth() + offset);
      return { key: `${month.getFullYear()}-${month.getMonth()}`, label: month.toLocaleDateString("en", { month: "short" }), count: 0 };
    });
    for (const crop of activeCrops) {
      const date = crop.harvestWindowStart ?? crop.estimatedHarvest;
      if (!date) continue;
      const expected = new Date(`${date.slice(0, 10)}T00:00:00`);
      if (Number.isNaN(expected.getTime())) continue;
      const bucket = harvestMonths.find((month) => month.key === `${expected.getFullYear()}-${expected.getMonth()}`);
      if (bucket) bucket.count += 1;
    }
    const maxHarvestCount = Math.max(1, ...harvestMonths.map((month) => month.count));

    return (
      <div className={styles.page}>
        <header className={styles.header}>
          <ModuleHeaderIntro mascot="dashboard">
            <p className={styles.eyebrow}>Farm overview</p>
            <h1>Planting Dashboard</h1>
            <p>Crop growth, care tasks, and upcoming harvests for your farm.</p>
          </ModuleHeaderIntro>
          <div className={styles.liveDateTime}><LiveDateTime /></div>
        </header>
        {error ? <section className={styles.notice}><strong>Crop dashboard data could not load.</strong><span>{error}</span></section> : null}
        <section className={styles.plantingMetrics} aria-label="Planting summary">
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><Sprout size={19} /><span>Active crop batches</span></div><strong>{summary?.activeCrops ?? 0}</strong></article>
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><TriangleAlert size={19} /><span>Need attention</span></div><strong>{summary?.needsAttention ?? 0}</strong></article>
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><CalendarDays size={19} /><span>Harvesting soon</span></div><strong>{summary?.upcomingHarvests ?? 0}</strong></article>
        </section>
        <section className={styles.plantingDashboardGrid}>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Growth stages</h2><p>Active batches by their recorded stage</p></div><a href="/crops">View crops</a></div>
            {stages.length ? <div className={styles.stageChart}>{stages.map(([stage, count]) => <div className={styles.stageBarRow} key={stage}><span>{stage}</span><div role="img" aria-label={`${count} active ${stage} crop batches`}><i style={{ width: `${(count / maxStageCount) * 100}%` }} /></div><b>{count}</b></div>)}</div> : <p className={styles.plantingEmpty}>No active crop batches yet.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Harvest outlook</h2><p>Active batches expected to reach harvest each month</p></div><a href="/crops">Review dates</a></div>
            {activeCrops.length ? <div className={styles.harvestChart} role="img" aria-label="Expected crop harvests by month">{harvestMonths.map((month) => <div className={styles.harvestMonth} key={month.key}><strong>{month.count}</strong><div><i style={{ height: `${Math.max(month.count ? 10 : 0, (month.count / maxHarvestCount) * 100)}%` }} /></div><span>{month.label}</span></div>)}</div> : <p className={styles.plantingEmpty}>No active crop batches yet.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Crop status</h2><p>Current condition of active crop batches</p></div><a href="/crops">Open crop list</a></div>
            {activeCrops.length ? <div className={styles.statusChart}>{cropStatuses.filter((item) => item.count > 0).map(({ status, count }) => <div className={styles.statusBarRow} key={status}><span data-status={status} /><strong>{status}</strong><div role="img" aria-label={`${count} ${status} crop batches`}><i data-status={status} style={{ width: `${(count / activeCrops.length) * 100}%` }} /></div><b>{count}</b></div>)}</div> : <p className={styles.plantingEmpty}>No active crop batches yet.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Care follow-up</h2><p>Crops with overdue or upcoming care</p></div><a href="/crops">Open crop care</a></div>
            {attentionCrops.length ? <ul className={styles.careCropList}>{attentionCrops.slice(0, 6).map((crop) => <li key={crop.id}><div><strong>{crop.cropName}</strong><span>{crop.fieldLabel} · {crop.growthStage}</span></div><small>{crop.nextCareTask ?? crop.careStatus}</small></li>)}</ul> : <p className={styles.plantingEmpty}>No crops need care follow-up right now.</p>}
          </article>
        </section>
      </div>
    );
  }

  const params = await searchParams;
  const range = normalizeDashboardRange(params?.range);
  const data = await getOperationsDashboard(range);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="dashboard">
            <p className={styles.eyebrow}>Overview</p>
            <h1>Operations Dashboard</h1>
            <p>Sales, inventory, crops, customers, and rover status.</p>
          </ModuleHeaderIntro>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {data.error ? (
        <section className={styles.notice}>
          <strong>Some dashboard data could not load.</strong>
          <span>{data.error}</span>
        </section>
      ) : null}

      <OperationsDashboardWorkspace
        canViewInvestments={profile.roleName === "System Administrator"}
        isInventoryManager={["Farm Inventory Manager", "Inventory Staff"].includes(profile.roleName)}
        data={data}
      />
    </div>
  );
}
