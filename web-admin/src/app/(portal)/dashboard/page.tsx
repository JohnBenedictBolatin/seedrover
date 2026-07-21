import { redirect } from "next/navigation";
import { LiveDateTime } from "@/components/live-date-time";
import { OperationsDashboardWorkspace } from "@/components/operations-dashboard-workspace";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getOperationsDashboard, normalizeDashboardRange } from "@/lib/dashboard";
import styles from "./page.module.css";

type DashboardPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function DashboardPage({ searchParams }: DashboardPageProps) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  const params = await searchParams;
  const range = normalizeDashboardRange(params?.range);
  const data = await getOperationsDashboard(range);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>SeedRover Overview</p>
          <h1>Operations Dashboard</h1>
          <p>
            Full farm overview for stock, sales, crops, customers, and rover activity.
          </p>
        </div>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {data.error ? (
        <section className={styles.notice}>
          <strong>Some dashboard data could not load.</strong>
          <span>{data.error}</span>
        </section>
      ) : null}

      <OperationsDashboardWorkspace data={data} />
    </div>
  );
}
