import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getStockMovementExportRows } from "@/lib/exports";
import { formatDateTime } from "@/lib/format";
import styles from "../../inventory/print/page.module.css";

export default async function StockMovementsPrintPage({
  searchParams,
}: {
  searchParams: Promise<{
    end?: string;
    search?: string;
    source?: string;
    start?: string;
    type?: string;
  }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const rows = await getStockMovementExportRows(await searchParams);

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/inventory">Back to inventory</Link>
        <PrintButton />
      </header>

      <article className={styles.report} data-print-ready="true">
        <header className={styles.reportHeader}>
          <div>
            <p>SeedRover</p>
            <h1>Stock Movement Report</h1>
          </div>
          <span>{formatDateTime(new Date().toISOString())}</span>
        </header>

        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Type</th>
              <th>Qty</th>
              <th>Source</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={`${row.stockCode}-${row.createdAt}-${index}`}>
                <td>
                  <strong>{row.itemName}</strong>
                  <span>{row.stockCode}</span>
                </td>
                <td>{row.movementType}</td>
                <td>{row.quantity}</td>
                <td>{row.source}</td>
                <td>{formatDateTime(row.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
