import { redirect } from "next/navigation";
import { LiveDateTime } from "@/components/live-date-time";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getUsersDashboard } from "@/lib/users";
import { UsersWorkspace } from "./users-workspace";
import styles from "./page.module.css";

export default async function UsersPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName !== "System Administrator") {
    redirect("/dashboard");
  }

  const { users, roles, summary, error } = await getUsersDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>System</p>
          <h1>User Management</h1>
          <p>Supervise staff accounts, access roles, and account status.</p>
        </div>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Users are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <UsersWorkspace users={users} roles={roles} summary={summary} />
    </div>
  );
}
