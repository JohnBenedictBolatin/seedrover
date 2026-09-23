import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getStockMovementExportRows } from "@/lib/exports";
import { formatDateTime } from "@/lib/format";
import styles from "../page.module.css";

export default async function InventoryHistoryPage() {
  const profile = await getCurrentAdminProfile();
  if (!profile) redirect("/login");
  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) redirect("/dashboard");
  const rows = await getStockMovementExportRows();

  return <div className={styles.page}>
    <header className={styles.header}><div><p className={styles.eyebrow}>Operations</p><h1>Inventory History</h1><p>All stock-in and stock-out movements from crops, sales, and manual adjustments.</p></div><Link href="/inventory">Back to inventory</Link></header>
    <section className={styles.inventoryTableWrap}><table><thead><tr><th>Item</th><th>Movement</th><th>Quantity</th><th>Source</th><th>Date</th><th>Remarks</th></tr></thead><tbody>{rows.map((row, index) => <tr key={`${row.stockCode}-${row.createdAt}-${index}`}><td>{row.itemName}<small>{row.stockCode}</small></td><td>{row.movementType}</td><td>{row.quantity}</td><td>{row.source}</td><td>{formatDateTime(row.createdAt)}</td><td>{row.remarks || "—"}</td></tr>)}</tbody></table>{rows.length === 0 ? <p>No inventory movements recorded yet.</p> : null}</section>
  </div>;
}
