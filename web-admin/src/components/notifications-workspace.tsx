"use client";

import { useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { NotificationDeleteButton, NotificationReadButton } from "@/components/notification-action-buttons";
import { formatDateTime } from "@/lib/format";
import type { AdminNotification } from "@/lib/notifications";
import styles from "@/app/(portal)/notifications/page.module.css";

const NOTIFICATIONS_PER_PAGE = 10;

export function NotificationsWorkspace({ notifications }: { notifications: AdminNotification[] }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(notifications.length / NOTIFICATIONS_PER_PAGE));
  const safePage = Math.min(page, totalPages);
  const visibleNotifications = notifications.slice(
    (safePage - 1) * NOTIFICATIONS_PER_PAGE,
    safePage * NOTIFICATIONS_PER_PAGE,
  );

  if (notifications.length === 0) {
    return (
      <div className={styles.emptyState}>
        <strong>No notifications found.</strong>
      </div>
    );
  }

  return (
    <>
      <div className={styles.notificationList} aria-live="polite">
        {visibleNotifications.map((notification) => (
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
              <small>{notification.recipientName} · {formatDateTime(notification.createdAt)}</small>
            </div>
            <div className={styles.status}>{notification.isRead ? "Read" : "Unread"}</div>
            <div className={styles.actions}>
              <NotificationReadButton id={notification.id} isRead={notification.isRead}>
                {notification.isRead ? "Mark unread" : "Mark read"}
              </NotificationReadButton>
              <NotificationDeleteButton id={notification.id} className={styles.dangerButton}>
                Delete
              </NotificationDeleteButton>
            </div>
          </article>
        ))}
      </div>
      <nav className={styles.pagination} aria-label="Notification pages">
        <span>Showing {(safePage - 1) * NOTIFICATIONS_PER_PAGE + 1}–{Math.min(safePage * NOTIFICATIONS_PER_PAGE, notifications.length)} of {notifications.length}</span>
        <div>
          <button aria-label="Previous notification page" disabled={safePage === 1} type="button" onClick={() => setPage((current) => Math.max(1, current - 1))}>
            <ChevronLeft size={17} />
          </button>
          <strong>Page {safePage} of {totalPages}</strong>
          <button aria-label="Next notification page" disabled={safePage === totalPages} type="button" onClick={() => setPage((current) => Math.min(totalPages, current + 1))}>
            <ChevronRight size={17} />
          </button>
        </div>
      </nav>
    </>
  );
}
