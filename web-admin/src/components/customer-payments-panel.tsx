"use client";

import { markCustomerPaymentPaidAction } from "@/app/(portal)/customers/payments-actions";
import type { CustomerPayment } from "@/lib/customer-payments";
import { formatCurrency } from "@/lib/format";
import styles from "@/app/(portal)/customers/page.module.css";

export function CustomerPaymentsPanel({ payments }: { payments: CustomerPayment[] }) {
  return (
    <section className={styles.paymentPanel}>
      <header className={styles.sectionHeader}>
        <div><p className={styles.eyebrow}>Customer finance</p><h2>Installment payments</h2></div>
        <span className={styles.paymentCount}>{payments.filter((payment) => payment.status !== "Paid").length} open balances</span>
      </header>
      {payments.length === 0 ? <div className={styles.paymentEmpty}>No installment balances recorded yet.</div> : (
        <div className={styles.paymentTable}>
          <div className={styles.paymentTableHeader}><span>Customer</span><span>Balance</span><span>Due date</span><span>Status</span><span>Action</span></div>
          {payments.map((payment) => (
            <div className={styles.paymentRow} key={payment.id}>
              <strong data-label="Customer">{payment.customerName}</strong>
              <span className={styles.paymentAmount} data-label="Balance">{formatCurrency(payment.amount)}</span>
              <span className={styles.paymentDate} data-label="Due date">{payment.dueDate ?? "No due date"}</span>
              <div className={styles.paymentStatusCell} data-label="Status">
                <span className={styles.paymentStatus} data-status={payment.status.toLowerCase()}>{payment.status}</span>
              </div>
              <div className={styles.paymentActionCell} data-label="Action">
                {payment.status !== "Paid" ? (
                  <form action={markCustomerPaymentPaidAction}>
                    <input name="id" type="hidden" value={payment.id} />
                    <button className={styles.paymentMarkButton} type="submit">MARK PAID</button>
                  </form>
                ) : <span className={styles.paymentComplete}>Completed</span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
