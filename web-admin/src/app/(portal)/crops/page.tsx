import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCropsDashboard } from "@/lib/crops";
import { formatDate, formatDateTime } from "@/lib/format";
import styles from "./page.module.css";

export default async function CropsPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Inventory Manager") {
    redirect("/dashboard");
  }

  const { crops, summary, error } = await getCropsDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Farm supervision</p>
          <h1>Crops</h1>
          <p>
            Monitor crop progress, manager assignment, growth stages, and attention status.
          </p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Crops are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Crop summary">
        <article className={styles.metric}>
          <p>Total crops</p>
          <strong className="mono">{summary?.totalCrops ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Active</p>
          <strong className="mono">{summary?.activeCrops ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Needs attention</p>
          <strong className="mono">{summary?.needsAttention ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Harvest ready</p>
          <strong className="mono">{summary?.harvestReady ?? 0}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Crop list</p>
            <h2>Current field records</h2>
          </div>
        </div>

        {crops.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No crop records found.</strong>
            <span>Crops created from mobile or field activity will appear here.</span>
          </div>
        ) : (
          <div className={styles.cropList}>
            {crops.map((crop) => (
              <article className={styles.cropCard} key={crop.id}>
                <div className={styles.cropTitle}>
                  <strong>{crop.cropName}</strong>
                  <span>{crop.managerName}</span>
                </div>
                <div>
                  <span>Growth stage</span>
                  <strong>{crop.growthStage}</strong>
                </div>
                <div>
                  <span>Status</span>
                  <strong className={styles.status} data-status={crop.cropStatus}>
                    {crop.cropStatus}
                  </strong>
                </div>
                <div>
                  <span>Planted</span>
                  <strong>{formatDate(crop.plantingDate)}</strong>
                </div>
                <div>
                  <span>Harvest</span>
                  <strong>
                    {crop.estimatedHarvest
                      ? formatDate(crop.estimatedHarvest)
                      : "Not set"}
                  </strong>
                </div>
                <p>{crop.maintenanceNotes}</p>
                <small>Updated {formatDateTime(crop.updatedAt)}</small>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
