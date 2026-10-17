import { redirect } from "next/navigation";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { OperationsDashboardWorkspace } from "@/components/operations-dashboard-workspace";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getOperationsDashboard, normalizeDashboardRange } from "@/lib/dashboard";
import { getCropsDashboard } from "@/lib/crops";
import { farmerCareText, farmerGrowthStage } from "@/lib/farmer-copy";
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
    const { crops, summary, error, recentHarvestMonths, harvestHistoryError } = await getCropsDashboard();
    const stageCounts = new Map<string, number>();
    const activeCrops = crops.filter((item) => !["Completed", "Harvested", "Cancelled"].includes(item.cropStatus));
    for (const crop of activeCrops) {
      const stageLabel = farmerGrowthStage(crop.growthStage);
      stageCounts.set(stageLabel, (stageCounts.get(stageLabel) ?? 0) + 1);
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
    const maxHarvestKg = Math.max(1, ...recentHarvestMonths.map((month) => month.kilograms));

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
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><Sprout size={19} /><span>Active crop batches</span></div><strong>{error ? "Unavailable" : summary?.activeCrops ?? 0}</strong></article>
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><TriangleAlert size={19} /><span>Need attention</span></div><strong>{error ? "Unavailable" : summary?.needsAttention ?? 0}</strong></article>
          <article className={styles.metric}><div className={styles.plantingMetricLabel}><CalendarDays size={19} /><span>Harvesting soon</span></div><strong>{error ? "Unavailable" : summary?.upcomingHarvests ?? 0}</strong></article>
        </section>
        <section className={styles.plantingDashboardGrid}>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Growth stages</h2><p>Active batches by their recorded stage</p></div><a href="/crops">View crops</a></div>
            {stages.length ? <div className={styles.stageChart}>{stages.map(([stage, count]) => <div className={styles.stageBarRow} key={stage}><span>{stage}</span><div role="img" aria-label={`${count} active ${stage} crop batches`}><i style={{ width: `${(count / maxStageCount) * 100}%` }} /></div><b>{count}</b></div>)}</div> : <p className={styles.plantingEmpty}>No active crop batches yet.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Recent harvests</h2><p>Confirmed weight picked each month, including active crops</p></div><a href="/crops">View crop history</a></div>
            {harvestHistoryError ? <p className={styles.plantingEmpty}>Harvest totals could not load: {harvestHistoryError}</p> : recentHarvestMonths.some((month) => month.count > 0) ? <div className={styles.harvestChart} role="img" aria-label="Confirmed harvest weight by month">{recentHarvestMonths.map((month) => <div className={styles.harvestMonth} key={month.key}><strong>{month.kilograms.toFixed(1)} kg</strong><div><i style={{ height: `${Math.max(month.kilograms ? 10 : 0, (month.kilograms / maxHarvestKg) * 100)}%` }} /></div><span>{month.label}</span></div>)}</div> : <p className={styles.plantingEmpty}>No harvest weights were recorded in the last six months.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Crop status</h2><p>Current condition of active crop batches</p></div><a href="/crops">Open crop list</a></div>
            {activeCrops.length ? <div className={styles.statusChart}>{cropStatuses.filter((item) => item.count > 0).map(({ status, count }) => <div className={styles.statusBarRow} key={status}><span data-status={status} /><strong>{status}</strong><div role="img" aria-label={`${count} ${status} crop batches`}><i data-status={status} style={{ width: `${(count / activeCrops.length) * 100}%` }} /></div><b>{count}</b></div>)}</div> : <p className={styles.plantingEmpty}>No active crop batches yet.</p>}
          </article>
          <article className={styles.plantingPanel}>
            <div className={styles.plantingPanelHeader}><div><h2>Care follow-up</h2><p>Crops with overdue or upcoming care</p></div><a href="/crops">Open crop care</a></div>
            {attentionCrops.length ? <ul className={styles.careCropList}>{attentionCrops.slice(0, 6).map((crop) => <li key={crop.id}><div><strong>{crop.displayName}</strong><span>{crop.cropName} · {crop.fieldLabel} · {farmerGrowthStage(crop.growthStage)}</span></div><small>{farmerCareText(crop.nextCareTask ?? crop.careStatus)}</small></li>)}</ul> : <p className={styles.plantingEmpty}>No crops need care follow-up right now.</p>}
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
          <p>Sales, inventory, crops, and customers at a glance.</p>
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
