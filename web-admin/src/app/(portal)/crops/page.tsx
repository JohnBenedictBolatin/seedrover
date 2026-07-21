import { redirect } from "next/navigation";
import { CheckCircle2, Leaf, Sprout, TriangleAlert } from "lucide-react";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCropsDashboard, getHarvestInventoryOptions } from "@/lib/crops";
import { CountUpValue } from "@/components/count-up-value";
import { LiveDateTime } from "@/components/live-date-time";
import { CropsWorkspace } from "@/components/crops-workspace";
import styles from "./page.module.css";

export default async function CropsPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Inventory Manager") {
    redirect("/dashboard");
  }

  const [{ crops, summary, error }, harvestInventoryOptions] = await Promise.all([
    getCropsDashboard(),
    getHarvestInventoryOptions(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Crops</h1>
          <p>
            Monitor planting progress, field care, harvest timing, and crop health.
          </p>
        </div>
        <div className={styles.liveDateTime}><LiveDateTime /></div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Crops are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Crop summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><Sprout size={20} /></span>
            <p>Total crops</p>
          </div>
          <CountUpValue className="mono" value={summary?.totalCrops ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><Leaf size={20} /></span>
            <p>Active</p>
          </div>
          <CountUpValue className="mono" value={summary?.activeCrops ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><TriangleAlert size={20} /></span>
            <p>Needs attention</p>
          </div>
          <CountUpValue className="mono" value={summary?.needsAttention ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><CheckCircle2 size={20} /></span>
            <p>Harvest ready</p>
          </div>
          <CountUpValue className="mono" value={summary?.harvestReady ?? 0} />
        </article>
      </section>

      <CropsWorkspace crops={crops} harvestInventoryOptions={harvestInventoryOptions} />
    </div>
  );
}
