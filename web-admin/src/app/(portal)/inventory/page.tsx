import { redirect } from "next/navigation";
import { AlertTriangle, Boxes, CircleDollarSign, PackageX, ShoppingCart, CalendarDays, Award } from "lucide-react";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getInventoryDashboard } from "@/lib/inventory";
import { CountUpValue } from "@/components/count-up-value";
import { InventoryWorkspace } from "@/components/inventory-workspace";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import styles from "./page.module.css";

type InventoryPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function InventoryPage({ searchParams }: InventoryPageProps) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const { items, summary, sales, error } = await getInventoryDashboard();
  const params = await searchParams;
  const itemParam = params?.item;
  const initialItemId = Array.isArray(itemParam) ? itemParam[0] : itemParam;

  return (
    <div className={styles.page}>
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="inventory">
            <p className={styles.eyebrow}>Operations</p>
            <h1>Inventory</h1>
            <p>Stock quantities, prices, locations, and movement history.</p>
          </ModuleHeaderIntro>
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
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon}><ShoppingCart size={20} /></span><p>Sales today</p></div>
          <CountUpValue currency value={sales?.salesToday ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon}><CalendarDays size={20} /></span><p>Sales this month</p></div>
          <CountUpValue currency value={sales?.salesThisMonth ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon}><Award size={20} /></span><p>Best-selling item</p></div>
          <strong className={styles.metricTextValue}>{sales?.bestSellingItem ?? "No sales yet"}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon}><CircleDollarSign size={20} /></span><p>Potential sales value</p></div>
          <CountUpValue currency value={summary?.estimatedSalesValue ?? 0} />
        </article>
      </section>

      <InventoryWorkspace initialItemId={initialItemId} items={items} />
    </div>
  );
}
