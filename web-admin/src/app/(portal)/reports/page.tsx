import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import styles from "./page.module.css";

const reportCards = [
  {
    title: "Inventory Report",
    description: "Stock levels, pricing, valuation, and storage locations.",
    csv: "/api/exports/inventory.csv",
    excel: "/api/exports/inventory.xls",
    print: "/reports/inventory/print",
  },
  {
    title: "Sales Report",
    description: "Receipt line items, customers, payments, discounts, and totals.",
    csv: "/api/exports/sales.csv",
    excel: "/api/exports/sales.xls",
    print: "/reports/sales/print",
  },
];

export default async function ReportsPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Operations</p>
          <h1>Reports</h1>
          <p>Export farm inventory and sales records for internal tracking.</p>
        </div>
      </header>

      <section className={styles.grid}>
        {reportCards.map((report) => (
          <article className={styles.card} key={report.title}>
            <div>
              <p className={styles.eyebrow}>Export</p>
              <h2>{report.title}</h2>
              <span>{report.description}</span>
            </div>
            <div className={styles.actions}>
              <Link href={report.csv}>CSV</Link>
              <Link href={report.excel}>Excel</Link>
              <Link href={report.print}>Print / PDF</Link>
            </div>
          </article>
        ))}
      </section>
    </div>
  );
}
