import Link from "next/link";
import type { AdminProfile } from "@/lib/auth";
import { signOutAction } from "@/app/(portal)/actions";
import { BrandMark } from "./brand-mark";
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
            { label: "Reports", href: "/reports" },
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
            { label: "Notifications", href: "/notifications" },
            { label: "Activity Log", href: "/activity-log" },
          ],
        }
      : null,
  ].filter((group) => group !== null);
}

export function AppShell({
  children,
  profile,
}: {
  children: React.ReactNode;
  profile: AdminProfile;
}) {
  const navGroups = navGroupsFor(profile.roleName);

  return (
    <div className={styles.shell}>
      <aside className={styles.sidebar}>
        <div className={styles.sidebarTop}>
          <BrandMark />
          <span className={styles.status}>Single farm mode</span>
        </div>

        <nav className={styles.nav} aria-label="SeedRover admin navigation">
          {navGroups.map((group) => (
            <div className={styles.navGroup} key={group.label}>
              <p className={styles.navLabel}>{group.label}</p>
              {group.items.map((item) =>
                item.href ? (
                  <Link
                    className={styles.navItem}
                    href={item.href}
                    key={item.label}
                  >
                    {item.label}
                  </Link>
                ) : (
                  <span className={styles.navItem} aria-disabled="true" key={item.label}>
                    {item.label}
                  </span>
                ),
              )}
            </div>
          ))}
        </nav>

        <form className={styles.account} action={signOutAction}>
          <div>
            <strong>{profile.fullName}</strong>
            <span>{profile.roleName}</span>
          </div>
          <button type="submit">Sign out</button>
        </form>
      </aside>

      <main className={styles.main}>{children}</main>
    </div>
  );
}
