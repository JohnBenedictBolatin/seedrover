import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getCustomerExportRows } from "@/lib/exports";
import { formatCurrency, formatDateTime } from "@/lib/format";
import styles from "../../inventory/print/page.module.css";

export default async function CustomersPrintPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const rows = await getCustomerExportRows(await searchParams);

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/customers">Back to customers</Link>
        <PrintButton />
      </header>

      <article className={styles.report} data-print-ready="true">
        <header className={styles.reportHeader}>
          <div>
            <p>SeedRover</p>
            <h1>Customers Report</h1>
          </div>
          <span>{formatDateTime(new Date().toISOString())}</span>
        </header>

        <table>
          <thead>
            <tr>
              <th>Customer</th>
              <th>Type</th>
              <th>Receipts</th>
              <th>Total Spent</th>
              <th>Last Purchase</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={`${row.name}-${row.contact}`}>
                <td>
                  <strong>{row.name}</strong>
                  <span>{row.contact}</span>
                </td>
                <td>{row.customerType}</td>
                <td>{row.receiptCount}</td>
                <td>{formatCurrency(row.totalSpent)}</td>
                <td>{row.lastPurchaseAt ? formatDateTime(row.lastPurchaseAt) : "No purchase"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
