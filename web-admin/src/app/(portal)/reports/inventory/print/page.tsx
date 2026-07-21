import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getInventoryExportRows } from "@/lib/exports";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import styles from "./page.module.css";

export default async function InventoryPrintPage({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; search?: string; status?: string }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const filters = await searchParams;
  const rows = await getInventoryExportRows(filters);

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
            <h1>Inventory Report</h1>
          </div>
          <span>{formatDateTime(new Date().toISOString())}</span>
        </header>

        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Category</th>
              <th>Qty</th>
              <th>Price</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.stockCode + row.itemName}>
                <td>
                  <strong>{row.itemName}</strong>
                  <span>{row.stockCode}</span>
                </td>
                <td>{row.category}</td>
                <td>{formatQuantity(row.quantity, row.unit)}</td>
                <td>{formatCurrency(row.sellingPrice)}</td>
                <td>{formatCurrency(row.inventoryValue)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
