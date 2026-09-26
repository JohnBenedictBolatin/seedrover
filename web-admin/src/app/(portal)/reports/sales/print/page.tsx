import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getSalesExportRows } from "@/lib/exports";
import { formatCurrency, formatDate, formatDateTime, formatQuantity } from "@/lib/format";
import styles from "./page.module.css";

export default async function SalesPrintPage({
  searchParams,
}: {
  searchParams: Promise<{ end?: string; payment?: string; start?: string; status?: string }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const rows = await getSalesExportRows(await searchParams);

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/sales">Back to sales</Link>
        <PrintButton />
      </header>

      <article className={styles.report} data-print-ready="true">
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
              <th>Entry type</th>
              <th>Receipt / reference</th>
              <th>Customer</th>
              <th>Item / payment</th>
              <th>Qty</th>
              <th>Reference</th>
              <th>Sale line</th>
              <th>Payment received</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={`${row.receiptNumber}-${row.itemName}-${index}`}>
                <td>{row.entryType}</td>
                <td>
                  {row.receiptLink ? (
                    <Link href={row.receiptLink}><strong>{row.receiptNumber}</strong></Link>
                  ) : (
                    <strong>{row.receiptNumber}</strong>
                  )}
                  <span>{row.entryKind === "collection" ? formatDate(row.saleDate) : formatDateTime(row.saleDate)}</span>
                </td>
                <td>{row.customerName}</td>
                <td>{row.itemName}</td>
                <td>{row.entryKind === "sale" ? formatQuantity(row.quantitySold, row.unit) : "-"}</td>
                <td>{row.transactionReference || "-"}</td>
                <td>{row.entryKind === "sale" ? formatCurrency(row.lineTotal) : "-"}</td>
                <td>{row.collectionAmount === null ? "-" : formatCurrency(row.collectionAmount)}</td>
                <td>{row.status === "Voided" ? "Voided" : row.status === "Recorded" ? "Recorded" : row.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
