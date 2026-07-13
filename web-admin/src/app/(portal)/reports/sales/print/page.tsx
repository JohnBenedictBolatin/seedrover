import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getSalesExportRows } from "@/lib/exports";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import styles from "./page.module.css";

export default async function SalesPrintPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const rows = await getSalesExportRows();

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/reports">Back to reports</Link>
        <PrintButton />
      </header>

      <article className={styles.report}>
        <header className={styles.reportHeader}>
          <div>
            <p>SeedRover</p>
            <h1>Sales Report</h1>
          </div>
          <span>{formatDateTime(new Date().toISOString())}</span>
        </header>

        <table>
          <thead>
            <tr>
              <th>Receipt</th>
              <th>Customer</th>
              <th>Item</th>
              <th>Qty</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={`${row.receiptNumber}-${row.itemName}-${index}`}>
                <td>
                  <strong>{row.receiptNumber}</strong>
                  <span>{formatDateTime(row.saleDate)}</span>
                </td>
                <td>{row.customerName}</td>
                <td>{row.itemName}</td>
                <td>{formatQuantity(row.quantitySold, row.unit)}</td>
                <td>{formatCurrency(row.lineTotal)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
