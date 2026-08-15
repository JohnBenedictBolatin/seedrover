"use client";

import { markCustomerPaymentPaidAction } from "@/app/(portal)/customers/payments-actions";
import type { CustomerPayment } from "@/lib/customer-payments";
import { formatCurrency } from "@/lib/format";
import styles from "@/app/(portal)/customers/page.module.css";

export function CustomerPaymentsPanel({ payments }: { payments: CustomerPayment[] }) {
  return (
    <section className={styles.paymentPanel}>
      <header className={styles.sectionHeader}>
        <div><p className={styles.eyebrow}>Customer finance</p><h2>Installment payments</h2><p className={styles.paymentSubtitle}>Track balances, due dates, and completed customer payments.</p></div>
        <span className={styles.paymentCount}>{payments.filter((payment) => payment.status !== "Paid").length} open balances</span>
      </header>
      {payments.length === 0 ? <div className={styles.paymentEmpty}>No installment balances recorded yet.</div> : (
        <div className={styles.paymentTable}>
          <div className={styles.paymentTableHeader}><span>Customer</span><span>Balance</span><span>Due date</span><span>Status</span><span /></div>
          {payments.map((payment) => <div className={styles.paymentRow} key={payment.id}>
            <strong>{payment.customerName}</strong><span className={styles.paymentAmount}>{formatCurrency(payment.amount)}</span><span>{payment.dueDate ?? "No due date"}</span><span className={styles.paymentStatus} data-status={payment.status.toLowerCase()}>{payment.status}</span>
            {payment.status !== "Paid" ? <form action={markCustomerPaymentPaidAction}><input name="id" type="hidden" value={payment.id} /><button className={styles.paymentMarkButton} type="submit">MARK PAID</button></form> : <span className={styles.paymentComplete}>Completed</span>}
          </div>)}
        </div>
      )}
    </section>
  );
}
