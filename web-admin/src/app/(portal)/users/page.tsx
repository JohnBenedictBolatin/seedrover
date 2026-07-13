import { redirect } from "next/navigation";
import { updateUserAction } from "@/app/(portal)/users/actions";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDate } from "@/lib/format";
import { getUsersDashboard } from "@/lib/users";
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
          <h1>Users</h1>
          <p>Manage existing SeedRover staff profile details, roles, and account status.</p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Users are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="User summary">
        <article className={styles.metric}>
          <p>Total users</p>
          <strong className="mono">{summary?.totalUsers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Active</p>
          <strong className="mono">{summary?.activeUsers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Inactive</p>
          <strong className="mono">{summary?.inactiveUsers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Admins</p>
          <strong className="mono">{summary?.administrators ?? 0}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Staff profiles</p>
            <h2>Existing accounts</h2>
          </div>
        </div>

        {users.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No users found.</strong>
            <span>Profiles will appear here after Supabase Auth users exist.</span>
          </div>
        ) : (
          <div className={styles.userList}>
            {users.map((user) => {
              const currentRole = roles.find((role) => role.roleName === user.roleName);

              return (
                <form className={styles.userCard} action={updateUserAction} key={user.id}>
                  <input name="user_id" type="hidden" value={user.id} />
                  <div className={styles.identity}>
                    <strong>{user.employeeId}</strong>
                    <span>{user.username}</span>
                    <small>{user.email}</small>
                  </div>
                  <label>
                    Full name
                    <input name="full_name" defaultValue={user.fullName} />
                  </label>
                  <label>
                    Role
                    <select name="role_id" defaultValue={currentRole?.id ?? ""}>
                      {roles.map((role) => (
                        <option value={role.id} key={role.id}>
                          {role.roleName}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    Status
                    <select name="is_active" defaultValue={String(user.isActive)}>
                      <option value="true">Active</option>
                      <option value="false">Inactive</option>
                    </select>
                  </label>
                  <div className={styles.cardFooter}>
                    <span>Joined {formatDate(user.createdAt)}</span>
                    <button type="submit">Save</button>
                  </div>
                </form>
              );
            })}
          </div>
        )}
      </section>

      <section className={styles.note}>
        <strong>Account creation note</strong>
        <span>
          Creating new Supabase Auth users still needs a secure admin Edge Function.
          This page only manages profiles that already exist.
        </span>
      </section>
    </div>
  );
}
