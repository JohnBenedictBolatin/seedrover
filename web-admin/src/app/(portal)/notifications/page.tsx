import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getNotificationsDashboard } from "@/lib/notifications";
import { NotificationsWorkspace } from "@/components/notifications-workspace";
import styles from "./page.module.css";

export default async function NotificationsPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName !== "System Administrator") {
    redirect("/dashboard");
  }

  const { notifications, summary, error } = await getNotificationsDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>System</p>
          <h1>Notifications</h1>
          <p>Farm alerts, reminders, and system notices.</p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Notifications are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Notification summary">
        <article className={styles.metric}>
          <p>Total</p>
          <strong className="mono">{summary?.total ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Unread</p>
          <strong className="mono">{summary?.unread ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Inventory</p>
          <strong className="mono">{summary?.inventory ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>System</p>
          <strong className="mono">{summary?.system ?? 0}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Notification list</p>
            <h2>Recent messages</h2>
          </div>
        </div>

        <NotificationsWorkspace notifications={notifications} />
      </section>
    </div>
  );
}
