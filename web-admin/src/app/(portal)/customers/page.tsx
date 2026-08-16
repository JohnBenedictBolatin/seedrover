import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCustomersDashboard } from "@/lib/customers";
import { getCustomerPayments } from "@/lib/customer-payments";
import { CustomersWorkspace } from "@/components/customers-workspace";
import { CustomerPaymentsPanel } from "@/components/customer-payments-panel";
import { LiveDateTime } from "@/components/live-date-time";
import styles from "./page.module.css";

export default async function CustomersPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const [{ customers, discounts, stats, error, profileError }, paymentData] = await Promise.all([
    getCustomersDashboard(),
    getCustomerPayments(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Customers</h1>
          <p>Buyer profiles, purchase history, discounts, and payments.</p>
        </div>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Customers are not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      {profileError ? (
        <section className={styles.notice}>
          <strong>Saved customer profiles are not available yet.</strong>
          <span>{profileError}</span>
        </section>
      ) : null}

      <CustomersWorkspace customers={customers} discounts={discounts} stats={stats} />
      {paymentData.error ? <section className={styles.notice}><strong>Installment tracking is unavailable.</strong><span>{paymentData.error}</span></section> : null}
      <CustomerPaymentsPanel payments={paymentData.payments} />
    </div>
  );
}
