import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCustomersDashboard } from "@/lib/customers";
import { getInstallmentPlans } from "@/lib/customer-payments";
import { CustomersWorkspace } from "@/components/customers-workspace";
import { CustomerPaymentsPanel } from "@/components/customer-payments-panel";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import styles from "./page.module.css";

export default async function CustomersPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const [{ customers, discounts, stats, error }, installmentData] = await Promise.all([
    getCustomersDashboard(),
    getInstallmentPlans(),
  ]);

  return (
    <div className={styles.page}>
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="customers">
            <p className={styles.eyebrow}>Operations</p>
            <h1>Customers</h1>
            <p>Customer records and purchase history are built from completed sales.</p>
          </ModuleHeaderIntro>
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

      <CustomersWorkspace customers={customers} discounts={discounts} stats={stats} />
      <CustomerPaymentsPanel plans={installmentData.plans} />
      {installmentData.error ? <section className={styles.notice}><strong>Installment schedules are unavailable.</strong><span>{installmentData.error}</span></section> : null}
    </div>
  );
}
