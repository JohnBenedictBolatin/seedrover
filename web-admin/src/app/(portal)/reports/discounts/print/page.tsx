import Link from "next/link";
import { redirect } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getDiscountExportRows } from "@/lib/exports";
import { formatCurrency, formatDateTime } from "@/lib/format";
import styles from "../../inventory/print/page.module.css";

export default async function DiscountsPrintPage({
  searchParams,
}: {
  searchParams: Promise<{ end?: string; search?: string; start?: string; status?: string }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const rows = await getDiscountExportRows(await searchParams);

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
            <h1>Discount Usage Report</h1>
          </div>
          <span>{formatDateTime(new Date().toISOString())}</span>
        </header>

        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Customer</th>
              <th>Value</th>
              <th>Redeemed</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.code}>
                <td>
                  <strong>{row.code}</strong>
                  <span>{formatDateTime(row.releasedAt)}</span>
                </td>
                <td>{row.customerName}</td>
                <td>{row.discountType === "Amount" ? formatCurrency(row.discountValue) : `${row.discountValue}%`}</td>
                <td>{row.redeemedAt ? formatDateTime(row.redeemedAt) : "Not redeemed"}</td>
                <td>{row.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </article>
    </div>
  );
}
