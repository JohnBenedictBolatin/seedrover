import { redirect } from "next/navigation";
import { CalendarDays, Sprout, TriangleAlert } from "lucide-react";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCropsDashboard } from "@/lib/crops";
import { getCropOutcomes } from "@/lib/crop-outcomes";
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

  const [{ crops, summary, weather, error }, { outcomes, error: outcomesError }] = await Promise.all([
    getCropsDashboard(),
    getCropOutcomes(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Crops</h1>
          <p>Crop batches, care status, sensor readings, and harvest history.</p>
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
            <p>Active batches</p>
          </div>
          <CountUpValue className="mono" value={summary?.activeCrops ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><TriangleAlert size={20} /></span>
            <p>Need attention</p>
          </div>
          <CountUpValue className="mono" value={summary?.needsAttention ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}><CalendarDays size={20} /></span>
            <p>Harvesting soon</p>
          </div>
          <CountUpValue className="mono" value={summary?.upcomingHarvests ?? 0} />
        </article>
      </section>

      <CropsWorkspace
        crops={crops}
        weather={weather}
        canAddManualCrop={profile.roleName === "Farm Planting Manager"}
        outcomes={outcomes}
        outcomesError={outcomesError}
      />
    </div>
  );
}
