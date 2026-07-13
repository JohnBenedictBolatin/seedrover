import { redirect } from "next/navigation";
import {
  deleteNotificationAction,
  markNotificationReadAction,
} from "@/app/(portal)/notifications/actions";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { getNotificationsDashboard } from "@/lib/notifications";
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
          <p>Review farm and system notifications across SeedRover staff accounts.</p>
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

        {notifications.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No notifications found.</strong>
            <span>System alerts will appear here as they are generated.</span>
          </div>
        ) : (
          <div className={styles.notificationList}>
            {notifications.map((notification) => (
              <article
                className={styles.notificationCard}
                data-read={notification.isRead}
                key={notification.id}
              >
                <div className={styles.notificationCopy}>
                  <div>
                    <strong>{notification.title}</strong>
                    <span>{notification.notificationType}</span>
                  </div>
                  <p>{notification.message}</p>
                  <small>
                    {notification.recipientName} · {formatDateTime(notification.createdAt)}
                  </small>
                </div>
                <div className={styles.status}>
                  {notification.isRead ? "Read" : "Unread"}
                </div>
                <div className={styles.actions}>
                  <form action={markNotificationReadAction}>
                    <input
                      name="notification_id"
                      type="hidden"
                      value={notification.id}
                    />
                    <input
                      name="is_read"
                      type="hidden"
                      value={String(!notification.isRead)}
                    />
                    <button type="submit">
                      {notification.isRead ? "Mark unread" : "Mark read"}
                    </button>
                  </form>
                  <form action={deleteNotificationAction}>
                    <input
                      name="notification_id"
                      type="hidden"
                      value={notification.id}
                    />
                    <button className={styles.dangerButton} type="submit">
                      Delete
                    </button>
                  </form>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
