import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import { getSalesReceipt } from "@/lib/sales";
import { PrintButton } from "@/components/print-button";
import styles from "./page.module.css";

export default async function SalesReceiptPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Planting Manager") {
    redirect("/dashboard");
  }

  const { id } = await params;
  const { receipt, error } = await getSalesReceipt(id);

  if (!receipt) {
    if (error) {
      notFound();
    }

    notFound();
  }

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/sales">Back to sales</Link>
        <PrintButton />
      </header>

      <article className={styles.receipt}>
        <header className={styles.receiptHeader}>
          <div>
            <p className={styles.brand}>SeedRover</p>
            <h1>Sales Receipt</h1>
            <span>Internal farm tracking</span>
          </div>
          <div className={styles.receiptMeta}>
            <strong>{receipt.receiptNumber}</strong>
            <span>{formatDateTime(receipt.saleDate)}</span>
            <span>{receipt.status}</span>
          </div>
        </header>

        <section className={styles.infoGrid}>
          <div>
            <span>Customer</span>
            <strong>{receipt.customerName}</strong>
            <small>{receipt.customerContact}</small>
          </div>
          <div>
            <span>Payment</span>
            <strong>{receipt.paymentMethod}</strong>
            <small>Recorded by {receipt.recordedBy}</small>
          </div>
        </section>

        <table className={styles.items}>
          <thead>
            <tr>
              <th>Item</th>
              <th>Qty</th>
              <th>Unit Price</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {receipt.items.map((item) => (
              <tr key={item.id}>
                <td>{item.itemName}</td>
                <td>{formatQuantity(item.quantitySold, item.unit)}</td>
                <td>{formatCurrency(item.unitPrice)}</td>
                <td>{formatCurrency(item.lineTotal)}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <section className={styles.totals}>
          <div>
            <span>Subtotal</span>
            <strong>{formatCurrency(receipt.subtotal)}</strong>
          </div>
          <div>
            <span>
              Discount
              {receipt.discountType !== "None"
                ? ` (${receipt.discountType}: ${receipt.discountValue})`
                : ""}
            </span>
            <strong>{formatCurrency(receipt.discountAmount)}</strong>
          </div>
          <div className={styles.grandTotal}>
            <span>Total</span>
            <strong>{formatCurrency(receipt.totalAmount)}</strong>
          </div>
          <div>
            <span>Amount paid</span>
            <strong>
              {receipt.amountPaid === null
                ? "Not recorded"
                : formatCurrency(receipt.amountPaid)}
            </strong>
          </div>
          <div>
            <span>Change</span>
            <strong>
              {receipt.changeAmount === null
                ? "Not recorded"
                : formatCurrency(receipt.changeAmount)}
            </strong>
          </div>
        </section>

        {receipt.remarks ? (
          <section className={styles.remarks}>
            <span>Remarks</span>
            <p>{receipt.remarks}</p>
          </section>
        ) : null}
      </article>
    </div>
  );
}
