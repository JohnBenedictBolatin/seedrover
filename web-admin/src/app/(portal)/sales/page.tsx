import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getExistingSaleCustomers } from "@/lib/customers";
import { getReleasedDiscounts, getSalesWorkspaceData, getSellableInventory } from "@/lib/sales";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { SalesWorkspace } from "@/components/sales-workspace";
import styles from "./page.module.css";

export default async function SalesPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const [{ items, error }, salesData, discountData, customerData] = await Promise.all([
    getSellableInventory(),
    getSalesWorkspaceData(),
    getReleasedDiscounts(),
    getExistingSaleCustomers(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="sales">
            <p className={styles.eyebrow}>Operations</p>
            <h1>Sales</h1>
            <p>Receipts and voided sales.</p>
          </ModuleHeaderIntro>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Sales cannot load inventory yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      {discountData.error ? (
        <section className={styles.notice}>
          <strong>Some discount data could not load.</strong>
          <span>{discountData.error}</span>
        </section>
      ) : null}

      {salesData.error ? (
        <section className={styles.notice} role="status">
          <strong>Sales data unavailable.</strong>
          <span>{salesData.error} Retry the page when the connection is restored.</span>
        </section>
      ) : (
        <SalesWorkspace
          canVoidSales={[
            "System Administrator",
            "Farm Inventory Manager",
          ].includes(profile.roleName)}
          customers={customerData.customers}
          discounts={discountData.discounts}
          items={items}
          orders={salesData.orders}
          summary={salesData.summary}
        />
      )}
    </div>
  );
}
