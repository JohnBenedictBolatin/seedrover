import { redirect } from "next/navigation";
import { CalendarDays, Sprout, TriangleAlert } from "lucide-react";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCropsDashboard } from "@/lib/crops";
import { getCropOutcomes } from "@/lib/crop-outcomes";
import { getPlantingRunsAction } from "./actions";
import { CountUpValue } from "@/components/count-up-value";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { CropsWorkspace } from "@/components/crops-workspace";
import styles from "./page.module.css";
import inventorySummaryStyles from "@/app/(portal)/inventory/page.module.css";

export default async function CropsPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Inventory Manager", "Inventory Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const [{ crops, summary, weather, error }, { outcomes, error: outcomesError }, plantingRuns] = await Promise.all([
    getCropsDashboard(),
    getCropOutcomes(),
    getPlantingRunsAction(1),
  ]);

  return (
    <div className={`${styles.page} ${inventorySummaryStyles.inventoryPage} ${inventorySummaryStyles.summaryDesignScope}`}>
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="crops">
            <p className={styles.eyebrow}>Operations</p>
            <h1>Crops</h1>
            <p>Crop batches, care status, sensor readings, and harvest history.</p>
          </ModuleHeaderIntro>
          <div className={styles.liveDateTime}><LiveDateTime /></div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Crops are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <CropsWorkspace
        crops={crops}
        weather={weather}
        outcomes={outcomes}
        outcomesError={outcomesError}
        initialPlantingRuns={plantingRuns.rows}
        plantingRunsTotal={plantingRuns.total}
        plantingRunsError={plantingRuns.error}
        isAdministrator={profile.roleName === "System Administrator"}
      >
        <section className={styles.metricGrid} aria-label="Crop summary">
          <article className={`${inventorySummaryStyles.metric} ${inventorySummaryStyles.summaryMetric}`}>
            <div className={inventorySummaryStyles.metricMeta}>
              <span className={inventorySummaryStyles.metricIcon}><Sprout size={20} /></span>
              <p>Active batches</p>
            </div>
            <CountUpValue className="mono" value={summary?.activeCrops ?? 0} />
          </article>
          <article className={`${inventorySummaryStyles.metric} ${inventorySummaryStyles.summaryMetric}`}>
            <div className={inventorySummaryStyles.metricMeta}>
              <span className={inventorySummaryStyles.metricIcon}><TriangleAlert size={20} /></span>
              <p>Need attention</p>
            </div>
            <CountUpValue className="mono" value={summary?.needsAttention ?? 0} />
          </article>
          <article className={`${inventorySummaryStyles.metric} ${inventorySummaryStyles.summaryMetric}`}>
            <div className={inventorySummaryStyles.metricMeta}>
              <span className={inventorySummaryStyles.metricIcon}><CalendarDays size={20} /></span>
              <p>Harvesting soon</p>
            </div>
            <CountUpValue className="mono" value={summary?.upcomingHarvests ?? 0} />
          </article>
        </section>
      </CropsWorkspace>
    </div>
  );
}
