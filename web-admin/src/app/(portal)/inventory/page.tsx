import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import { getInventoryDashboard, stockStatus } from "@/lib/inventory";
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
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Inventory is not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Inventory summary">
        <article className={styles.metric}>
          <p>Total items</p>
          <strong className="mono">{summary?.totalItems ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Low stock</p>
          <strong className="mono">{summary?.lowStockItems ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Out of stock</p>
          <strong className="mono">{summary?.outOfStockItems ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Inventory value</p>
          <strong>{formatCurrency(summary?.inventoryValue ?? 0)}</strong>
        </article>
      </section>

      <section className={styles.salesBand} aria-label="Sales summary">
        <div>
          <p>Sales today</p>
          <strong>{formatCurrency(sales?.salesToday ?? 0)}</strong>
        </div>
        <div>
          <p>Sales this month</p>
          <strong>{formatCurrency(sales?.salesThisMonth ?? 0)}</strong>
        </div>
        <div>
          <p>Completed sales</p>
          <strong className="mono">{sales?.completedTransactions ?? 0}</strong>
        </div>
        <div>
          <p>Potential sales value</p>
          <strong>{formatCurrency(summary?.estimatedSalesValue ?? 0)}</strong>
        </div>
      </section>

      <section className={styles.tableSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Stock list</p>
            <h2>Current farm inventory</h2>
          </div>
        </div>

        {items.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No inventory items found.</strong>
            <span>Add inventory from the mobile app or the upcoming web item form.</span>
          </div>
        ) : (
          <div className={styles.tableWrap}>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Item</th>
                  <th>Category</th>
                  <th>Quantity</th>
                  <th>Status</th>
                  <th>Price</th>
                  <th>Location</th>
                  <th>Updated</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => {
                  const status = stockStatus(item);

                  return (
                    <tr key={item.id}>
                      <td>
                        <span className={styles.itemName}>{item.itemName}</span>
                        <span className={styles.itemCode}>{item.stockCode}</span>
                      </td>
                      <td>{item.category}</td>
                      <td className="mono">{formatQuantity(item.quantity, item.unit)}</td>
                      <td>
                        <span className={styles.status} data-status={status}>
                          {status}
                        </span>
                      </td>
                      <td>
                        {item.sellingPrice === null
                          ? "Not set"
                          : formatCurrency(item.sellingPrice)}
                      </td>
                      <td>{item.storageLocation}</td>
                      <td>{formatDateTime(item.updatedAt)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
