import { redirect } from "next/navigation";
import { getActivityDashboard } from "@/lib/activity";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import styles from "./page.module.css";

export default async function ActivityLogPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName !== "System Administrator") {
    redirect("/dashboard");
  }

  const { logs, summary, error } = await getActivityDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>System</p>
          <h1>Activity Log</h1>
          <p>Audit recent web and mobile activities recorded across SeedRover.</p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Activity logs are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Activity summary">
        <article className={styles.metric}>
          <p>Recent records</p>
          <strong className="mono">{summary?.total ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Authentication</p>
          <strong className="mono">{summary?.authentication ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Sales / Stocks</p>
          <strong className="mono">{summary?.salesAndStocks ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>System</p>
          <strong className="mono">{summary?.system ?? 0}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Audit trail</p>
            <h2>Latest 100 records</h2>
          </div>
        </div>

        {logs.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No activity records found.</strong>
            <span>System actions will appear here as they are recorded.</span>
          </div>
        ) : (
          <div className={styles.logList}>
            {logs.map((log) => (
              <article className={styles.logCard} key={log.id}>
                <div className={styles.logCopy}>
                  <strong>{log.activity}</strong>
                  <p>{log.description}</p>
                </div>
                <span>{log.module}</span>
                <span>{log.userName}</span>
                <time>{formatDateTime(log.createdAt)}</time>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
