"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import type { AdminProfile } from "@/lib/auth";
import { signOutAction } from "@/app/(portal)/actions";
import {
  deleteNotificationAction,
  markNotificationReadAction,
} from "@/app/(portal)/notifications/actions";
import { formatDateTime } from "@/lib/format";
import type { AdminNotification, NotificationsSummary } from "@/lib/notifications";
import {
  Bell,
  Boxes,
  ChevronLeft,
  ClipboardList,
  LayoutDashboard,
  Radar,
  LogOut,
  MailCheck,
  Trash2,
  Shield,
  ShoppingCart,
  Sprout,
  Users,
  X,
} from "lucide-react";
import { BrandMark } from "./brand-mark";
import { ConfirmSubmitButton } from "./confirm-submit-button";
import { RovieAssistant } from "./rovie-assistant";
import styles from "./app-shell.module.css";

function navGroupsFor(roleName: AdminProfile["roleName"]) {
  const canManageInventory =
    roleName === "System Administrator" || roleName === "Farm Inventory Manager";
  const canManageCrops =
    roleName === "System Administrator" || roleName === "Farm Planting Manager";
  const isAdmin = roleName === "System Administrator";

  return [
    {
      label: "Overview",
      items: [{ label: "Dashboard", href: "/dashboard" }],
    },
    canManageInventory
      ? {
          label: "Operations",
          items: [
            { label: "Inventory", href: "/inventory" },
            { label: "Sales", href: "/sales" },
            { label: "Customers", href: "/customers" },
          ],
        }
      : null,
    canManageCrops
        ? {
          label: "Farm",
          items: [
            { label: "Crops", href: "/crops" },
            { label: "Rover Monitor", href: "/rover-monitor" },
          ],
        }
      : null,
    isAdmin
        ? {
          label: "System",
          items: [
            { label: "Users", href: "/users" },
            { label: "Activity Log", href: "/activity-log" },
          ],
        }
      : null,
  ].filter((group) => group !== null);
}

function iconFor(label: string) {
  switch (label) {
    case "Dashboard":
      return <LayoutDashboard size={18} />;
    case "Inventory":
      return <Boxes size={18} />;
    case "Sales":
      return <ShoppingCart size={18} />;
    case "Customers":
    case "Users":
      return <Users size={18} />;
    case "Crops":
      return <Sprout size={18} />;
    case "Rover Monitor":
      return <Radar size={18} />;
    case "Notifications":
      return <Bell size={18} />;
    case "Activity Log":
      return <ClipboardList size={18} />;
    default:
      return <Shield size={18} />;
  }
}

function notificationTone(type: string) {
  const normalized = type.toLowerCase();

  if (normalized.includes("inventory")) return "inventory";
  if (normalized.includes("robot") || normalized.includes("rover")) return "robot";
  if (normalized.includes("crop")) return "crop";
  if (normalized.includes("battery")) return "battery";
  if (normalized.includes("seed")) return "seed";
  if (normalized.includes("system")) return "system";

  return "default";
}

function notificationRoute(notification: AdminNotification) {
  if (notification.actionRoute) {
    if (notification.actionRoute.startsWith("/stocks")) {
      return "/inventory";
    }

    return notification.actionRoute;
  }

  const type = notification.notificationType.toLowerCase();

  if (type.includes("inventory") || type.includes("stock")) return "/inventory";
  if (type.includes("sale")) return "/sales";
  if (type.includes("customer") || type.includes("discount")) return "/customers";
  if (type.includes("crop") || type.includes("plant")) return "/crops";
  if (type.includes("robot") || type.includes("rover") || type.includes("battery") || type.includes("seed")) {
    return "/rover-monitor";
  }
  if (type.includes("user")) return "/users";

  return "/activity-log";
}

export function AppShell({
  children,
  notifications,
  notificationsError,
  notificationsSummary,
  profile,
}: {
  children: React.ReactNode;
  notifications: AdminNotification[];
  notificationsError: string | null;
  notificationsSummary: NotificationsSummary | null;
  profile: AdminProfile;
}) {
  const navGroups = useMemo(() => navGroupsFor(profile.roleName), [profile.roleName]);
  const pathname = usePathname();
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);
  const [confirmSignOut, setConfirmSignOut] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const unreadCount = notificationsSummary?.unread ?? notifications.filter((item) => !item.isRead).length;
  const recentNotifications = notifications.slice(0, 5);
  const hasNotifications = unreadCount > 0 || recentNotifications.length > 0;

  useEffect(() => {
    const savedTheme = window.localStorage.getItem("seedrover-theme");
    const nextTheme = savedTheme === "light" ? "light" : "dark";
    document.documentElement.dataset.theme = nextTheme;
    setTheme(nextTheme);
  }, []);

  function toggleTheme() {
    const nextTheme = theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = nextTheme;
    window.localStorage.setItem("seedrover-theme", nextTheme);
    setTheme(nextTheme);
  }

  function isActive(href: string) {
    if (href === "/dashboard") {
      return pathname === href;
    }

    return pathname === href || pathname.startsWith(`${href}/`);
  }

  return (
    <div className={styles.shell}>
      <aside className={`${styles.sidebar} ${collapsed ? styles.sidebarCollapsed : ""}`}>
        <div className={styles.sidebarTop}>
          <div className={styles.sidebarHeader}>
            <div className={styles.sidebarHeaderRow}>
              <BrandMark compact={collapsed} />
              <div className={styles.sidebarHeaderControls}>
                <button
                  aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
                  className={styles.toggle}
                  type="button"
                  onClick={() => setCollapsed((current) => !current)}
                >
                  <ChevronLeft
                    className={collapsed ? styles.toggleIconCollapsed : undefined}
                    size={18}
                  />
                </button>
                <button
                  aria-expanded={notificationsOpen}
                  aria-label="Open notifications"
                  className={styles.notificationButton}
                  title="Notifications"
                  type="button"
                  onClick={() => setNotificationsOpen((current) => !current)}
                >
                  <Bell size={18} />
                  {hasNotifications ? <i aria-hidden="true" /> : null}
                </button>
              </div>
            </div>
          </div>
        </div>

        <nav className={styles.nav} aria-label="SeedRover admin navigation">
          {navGroups.map((group) => (
            <div className={styles.navGroup} key={group.label}>
              {!collapsed ? <p className={styles.navLabel}>{group.label}</p> : null}
              {group.items.map((item) =>
                item.href ? (
                  <Link
                    className={`${styles.navItem} ${isActive(item.href) ? styles.active : ""}`}
                    href={item.href}
                    key={item.label}
                    title={collapsed ? item.label : undefined}
                  >
                    <span className={styles.navIcon}>{iconFor(item.label)}</span>
                    {!collapsed ? <span className={styles.navText}>{item.label}</span> : null}
                  </Link>
                ) : (
                  <span
                    className={styles.navItem}
                    aria-disabled="true"
                    key={item.label}
                    title={collapsed ? item.label : undefined}
                  >
                    <span className={styles.navIcon}>{iconFor(item.label)}</span>
                    {!collapsed ? <span className={styles.navText}>{item.label}</span> : null}
                  </span>
                ),
              )}
            </div>
          ))}
          <div className={`${styles.navGroup} ${styles.themeNavGroup}`}>
            <div className={styles.themeSwitchRow}>
              {!collapsed ? <p className={styles.navLabel}>Theme</p> : null}
              <label
                className={styles.themeSwitch}
                title={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
              >
                <input
                  aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
                  checked={theme === "light"}
                  className={styles.themeSwitchInput}
                  type="checkbox"
                  onChange={toggleTheme}
                />
                <span className={styles.themeSwitchToggle} aria-hidden="true">
                  <span className={styles.themeMoonsHole}>
                    <span className={styles.themeMoonHole} />
                    <span className={styles.themeMoonHole} />
                    <span className={styles.themeMoonHole} />
                  </span>
                  <span className={styles.themeBlackClouds}>
                    <span className={styles.themeBlackCloud} />
                    <span className={styles.themeBlackCloud} />
                    <span className={styles.themeBlackCloud} />
                  </span>
                  <span className={styles.themeClouds}>
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                    <span className={styles.themeCloud} />
                  </span>
                  <span className={styles.themeStars}>
                    {Array.from({ length: 5 }).map((_, index) => (
                      <svg className={styles.themeStar} viewBox="0 0 20 20" key={index}>
                        <path d="M 0 10 C 10 10,10 10 ,0 10 C 10 10 , 10 10 , 10 20 C 10 10 , 10 10 , 20 10 C 10 10 , 10 10 , 10 0 C 10 10,10 10 ,0 10 Z" />
                      </svg>
                    ))}
                  </span>
                </span>
              </label>
            </div>
          </div>
        </nav>

        <div className={styles.account}>
          {!collapsed ? (
            <div className={styles.accountHeader}>
              <div>
                <strong>{profile.fullName}</strong>
                <span>{profile.roleName}</span>
              </div>
            </div>
          ) : null}

          <button
            className={styles.signOutButton}
            title="Sign out"
            type="button"
            onClick={() => setConfirmSignOut(true)}
          >
            <LogOut size={16} />
            {!collapsed ? <span>Sign out</span> : null}
          </button>
        </div>
      </aside>

      <main className={styles.main}>{children}</main>

      <RovieAssistant />

      {notificationsOpen ? (
        <div
          className={styles.notificationWindowWrap}
          role="presentation"
          style={{
            left: collapsed ? "104px" : "314px",
          }}
        >
                  <section
                    className={styles.notificationPopover}
                    aria-label="Notifications"
                    aria-modal="false"
                  >
                    <header>
                      <div>
                        <p>
                          Notifications{" "}
                          <strong>
                            ({unreadCount} unread)
                          </strong>
                        </p>
                      </div>
                      <button
                        aria-label="Close notifications"
                        type="button"
                        onClick={() => setNotificationsOpen(false)}
                      >
                        <X size={16} />
                      </button>
                    </header>
                    {notificationsError ? (
                      <div className={styles.notificationEmpty}>
                        <strong>Notifications unavailable.</strong>
                        <span>{notificationsError}</span>
                      </div>
                    ) : recentNotifications.length === 0 ? (
                      <div className={styles.notificationEmpty}>
                        <strong>No notifications yet.</strong>
                        <span>System alerts will appear here.</span>
                      </div>
                    ) : (
                      <div className={styles.notificationList}>
                        {recentNotifications.map((notification) => (
                          <article
                            data-read={notification.isRead}
                            key={notification.id}
                            role="button"
                            tabIndex={0}
                            title={`Open ${notificationRoute(notification)}`}
                            onClick={() => {
                              setNotificationsOpen(false);
                              router.push(notificationRoute(notification));
                            }}
                            onKeyDown={(event) => {
                              if (event.key === "Enter" || event.key === " ") {
                                event.preventDefault();
                                setNotificationsOpen(false);
                                router.push(notificationRoute(notification));
                              }
                            }}
                          >
                            <div>
                              <strong>{notification.title}</strong>
                              <span data-tone={notificationTone(notification.notificationType)}>
                                {notification.notificationType}
                              </span>
                            </div>
                            <p>{notification.message}</p>
                            <small>{formatDateTime(notification.createdAt)}</small>
                            {notification.source === "notification" ? (
                              <div
                                className={styles.notificationActions}
                                onClick={(event) => event.stopPropagation()}
                                onKeyDown={(event) => event.stopPropagation()}
                              >
                                <form action={markNotificationReadAction}>
                                  <input name="notification_id" type="hidden" value={notification.id} />
                                  <input
                                    name="is_read"
                                    type="hidden"
                                    value={String(!notification.isRead)}
                                  />
                                  <button
                                    aria-label={notification.isRead ? "Mark unread" : "Mark read"}
                                    type="submit"
                                  >
                                    <MailCheck size={15} />
                                  </button>
                                </form>
                                {profile.roleName === "System Administrator" ? (
                                  <form action={deleteNotificationAction}>
                                    <input name="notification_id" type="hidden" value={notification.id} />
                                    <ConfirmSubmitButton
                                      aria-label="Delete notification"
                                      confirmMessage="Are you sure you want to delete this notification?"
                                      type="submit"
                                    >
                                      <Trash2 size={15} />
                                    </ConfirmSubmitButton>
                                  </form>
                                ) : null}
                              </div>
                            ) : null}
                          </article>
                        ))}
                      </div>
                    )}
                  </section>
                </div>
      ) : null}

      {confirmSignOut ? (
        <div className={styles.modalBackdrop} role="presentation">
          <section
            className={styles.modal}
            role="dialog"
            aria-modal="true"
            aria-label="Sign out confirmation"
          >
            <header className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>Are you sure?</h3>
              <button
                aria-label="Close modal"
                className={styles.modalCloseButton}
                type="button"
                onClick={() => setConfirmSignOut(false)}
              >
                <X size={18} />
              </button>
            </header>
            <p className={styles.modalMessage}>
              You are about to sign out of the SeedRover web console.
            </p>
            <div className={styles.modalActions}>
              <button
                className={styles.cancelButton}
                type="button"
                onClick={() => setConfirmSignOut(false)}
              >
                Cancel
              </button>
              <form action={signOutAction}>
                <button className={styles.confirmButton} type="submit">
                  <LogOut size={16} />
                  <span>Sign out</span>
                </button>
              </form>
            </div>
          </section>
        </div>
      ) : null}
    </div>
  );
}
