import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getInstallmentCollectionReceipt } from "@/lib/customer-payments";
import { formatCurrency, formatDate } from "@/lib/format";
import { PrintButton } from "@/components/print-button";
import { InstallmentPaymentReceiptActions } from "@/components/installment-payment-receipt-actions";
import styles from "../../[id]/page.module.css";

export default async function InstallmentPaymentReceiptPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const profile = await getCurrentAdminProfile();
  if (!profile) redirect("/login");
  if (["Farm Planting Manager", "Planting Staff"].includes(profile.roleName)) redirect("/dashboard");
  const { id } = await params;
  const { receipt, error } = await getInstallmentCollectionReceipt(id);
  if (!receipt && !error) notFound();
  if (error) {
    return <main className={styles.page}><article className={styles.receipt}><h1>Payment receipt unavailable</h1><p>{error}</p><Link href="/sales">Back to sales</Link></article></main>;
  }
  if (!receipt) notFound();
  const canReverse = ["System Administrator", "Farm Inventory Manager"].includes(profile.roleName);

  return (
    <div className={styles.page}>
      <header className={styles.toolbar}>
        <Link href="/sales">Back to sales</Link>
        <PrintButton />
      </header>
      <article className={styles.receipt}>
        <header className={styles.receiptHeader}>
          <div><p className={styles.brand}>SeedRover</p><h1>Payment Receipt</h1></div>
          <div className={styles.receiptMeta}><strong>{receipt.receiptNumber}</strong><span>{formatDate(receipt.paymentDate)}</span><span>{receipt.reversed ? "Reversed" : "Recorded"}</span></div>
        </header>
        <section className={styles.infoGrid}>
          <div><span>Customer</span><strong>{receipt.customerName}</strong></div>
          <div><span>Payment method</span><strong>{receipt.paymentMethod}{receipt.otherPaymentMethod ? ` · ${receipt.otherPaymentMethod}` : ""}</strong><small>{receipt.transactionReference ? `Transaction ID: ${receipt.transactionReference}` : "Cash payment"}</small></div>
          <div><span>Purchase receipt</span><strong><Link href={`/sales/${receipt.saleId}`}>{receipt.saleReceiptNumber}</Link></strong></div>
        </section>
        <section className={styles.totals}>
          <div><span>Amount collected</span><strong>{formatCurrency(receipt.amount)}</strong></div>
          {receipt.cashTendered !== null ? <div><span>Cash tendered</span><strong>{formatCurrency(receipt.cashTendered)}</strong></div> : null}
          {receipt.cashTendered !== null ? <div><span>Change</span><strong>{formatCurrency(receipt.changeAmount)}</strong></div> : null}
          <div className={styles.grandTotal}><span>{receipt.reversed ? "Balance after reversal" : "Balance after payment"}</span><strong>{formatCurrency(receipt.reversalBalanceAfter ?? receipt.balanceAfter)}</strong></div>
        </section>
        {receipt.notes ? <section className={styles.remarks}><span>Notes</span><p>{receipt.notes}</p></section> : null}
        {receipt.receiptUrl ? <section className={styles.remarks}><span>Proof of payment</span><p><a href={receipt.receiptUrl} target="_blank" rel="noreferrer">Open attachment</a></p></section> : null}
        {receipt.reversed ? <section className={styles.remarks}><span>Reversal {receipt.reversalReceiptNumber}</span><p>{receipt.reversalReason}</p></section> : null}
        <InstallmentPaymentReceiptActions paymentId={receipt.id} saleId={receipt.saleId} canReverse={canReverse} reversed={receipt.reversed} />
      </article>
    </div>
  );
}
