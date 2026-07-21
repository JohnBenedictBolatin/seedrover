import { redirect } from "next/navigation";
import { LiveDateTime } from "@/components/live-date-time";
import { getActivityDashboard } from "@/lib/activity";
import { getCurrentAdminProfile } from "@/lib/auth";
import { ActivityLogWorkspace } from "./activity-log-workspace";
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
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Activity logs are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <ActivityLogWorkspace logs={logs} summary={summary} />
    </div>
  );
}
