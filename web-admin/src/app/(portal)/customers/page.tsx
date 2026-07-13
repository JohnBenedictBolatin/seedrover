import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCustomersDashboard } from "@/lib/customers";
import { formatCurrency, formatDateTime } from "@/lib/format";
import styles from "./page.module.css";

export default async function CustomersPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const { customers, stats, error } = await getCustomersDashboard();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Customers</h1>
          <p>
            Review customer activity from recorded sales receipts and spot repeat buyers.
          </p>
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Customers are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Customer summary">
        <article className={styles.metric}>
          <p>Total customers</p>
          <strong className="mono">{stats?.totalCustomers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Repeat customers</p>
          <strong className="mono">{stats?.repeatCustomers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <p>Customer sales</p>
          <strong>{formatCurrency(stats?.totalCustomerSales ?? 0)}</strong>
        </article>
        <article className={styles.metric}>
          <p>Top customer</p>
          <strong>{stats?.topCustomer ?? "None yet"}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Customer list</p>
            <h2>Sales-derived customer records</h2>
          </div>
        </div>

        {customers.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No customers found yet.</strong>
            <span>Customers will appear after sales receipts are recorded.</span>
          </div>
        ) : (
          <div className={styles.customerList}>
            {customers.map((customer) => (
              <article className={styles.customerCard} key={customer.key}>
                <div>
                  <strong>{customer.name}</strong>
                  <span>{customer.contact}</span>
                </div>
                <div>
                  <span>Receipts</span>
                  <strong className="mono">{customer.receiptCount}</strong>
                </div>
                <div>
                  <span>Total spent</span>
                  <strong>{formatCurrency(customer.totalSpent)}</strong>
                </div>
                <div>
                  <span>Last purchase</span>
                  <strong>{formatDateTime(customer.lastPurchaseAt)}</strong>
                </div>
                <div>
                  <span>Payment</span>
                  <strong>{customer.paymentMethods.join(", ")}</strong>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
