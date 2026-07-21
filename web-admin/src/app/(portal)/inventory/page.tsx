import { redirect } from "next/navigation";
import { AlertTriangle, Boxes, CircleDollarSign, PackageX } from "lucide-react";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getInventoryDashboard } from "@/lib/inventory";
import { CountUpValue } from "@/components/count-up-value";
import { InventoryWorkspace } from "@/components/inventory-workspace";
import { LiveDateTime } from "@/components/live-date-time";
import styles from "./page.module.css";

export default async function InventoryPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const { items, summary, sales, error } = await getInventoryDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Inventory</h1>
          <p>
            Track stock levels, item pricing, locations, and sales readiness for the farm.
          </p>
        </div>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Inventory is not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Inventory summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Boxes size={20} />
            </span>
            <p>Total items</p>
          </div>
          <CountUpValue className="mono" value={summary?.totalItems ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <AlertTriangle size={20} />
            </span>
            <p>Low stock</p>
          </div>
          <CountUpValue className="mono" value={summary?.lowStockItems ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <PackageX size={20} />
            </span>
            <p>Out of stock</p>
          </div>
          <CountUpValue className="mono" value={summary?.outOfStockItems ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <CircleDollarSign size={20} />
            </span>
            <p>Inventory value</p>
          </div>
          <CountUpValue className="mono" currency value={summary?.inventoryValue ?? 0} />
        </article>
      </section>

      <section className={styles.salesBand} aria-label="Sales summary">
        <div>
          <p>Sales today</p>
          <CountUpValue currency value={sales?.salesToday ?? 0} />
        </div>
        <div>
          <p>Sales this month</p>
          <CountUpValue currency value={sales?.salesThisMonth ?? 0} />
        </div>
        <div>
          <p>Best-selling item</p>
          <strong>{sales?.bestSellingItem ?? "No sales yet"}</strong>
        </div>
        <div>
          <p>Potential sales value</p>
          <CountUpValue currency value={summary?.estimatedSalesValue ?? 0} />
        </div>
      </section>

      <section className={styles.tableSection}>
        <InventoryWorkspace items={items} />
      </section>
    </div>
  );
}
