import { redirect } from "next/navigation";
import Link from "next/link";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatCurrency, formatDateTime } from "@/lib/format";
import { getRecentSalesOrders, getSellableInventory } from "@/lib/sales";
import { SalesOrderForm } from "@/components/sales-order-form";
import styles from "./page.module.css";

export default async function SalesPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const [{ items, error }, { orders, error: ordersError }] = await Promise.all([
    getSellableInventory(),
    getRecentSalesOrders(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Sales</h1>
          <p>
            Record multi-item farm sales with customer details, payment method, discounts,
            and receipt-ready totals.
          </p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Sales cannot load inventory yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <SalesOrderForm items={items} />

      <section className={styles.receipts}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Receipts</p>
            <h2>Recent sales</h2>
          </div>
        </div>

        {ordersError ? (
          <div className={styles.emptyState}>
            <strong>Recent receipts are not available.</strong>
            <span>{ordersError}</span>
          </div>
        ) : orders.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No sales receipts yet.</strong>
            <span>Completed web sales will appear here.</span>
          </div>
        ) : (
          <div className={styles.receiptList}>
            {orders.map((order) => (
              <Link className={styles.receiptItem} href={`/sales/${order.id}`} key={order.id}>
                <span>
                  <strong>{order.receiptNumber}</strong>
                  <small>{order.customerName}</small>
                </span>
                <span>{order.paymentMethod}</span>
                <span>{formatDateTime(order.saleDate)}</span>
                <strong>{formatCurrency(order.totalAmount)}</strong>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
