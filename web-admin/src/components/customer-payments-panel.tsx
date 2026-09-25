"use client";

import { type FormEvent, type ReactNode, useEffect, useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createPortal } from "react-dom";
import { CalendarDays, Check, ChevronDown, ChevronLeft, ChevronRight, FileText, Filter, Search, X } from "lucide-react";
import { recordInstallmentPaymentAction } from "@/app/(portal)/customers/payments-actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { CalendarField } from "@/components/calendar-field";
import { FileUploadField } from "@/components/file-upload-field";
import uploadStyles from "@/components/file-upload-field.module.css";
import type { InstallmentPlan, InstallmentSchedule } from "@/lib/customer-payments";
import { formatCurrency, formatDate } from "@/lib/format";
import styles from "@/app/(portal)/customers/page.module.css";

export function CustomerPaymentsPanel({
  plans,
}: {
  plans: InstallmentPlan[];
}) {
  const router = useRouter();
  const plansPerPage = 4;
  const [currentPage, setCurrentPage] = useState(1);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [frequencyFilter, setFrequencyFilter] = useState("All");
  const [selectedPlan, setSelectedPlan] = useState<InstallmentPlan | null>(null);
  const [selectedPayment, setSelectedPayment] = useState<{ plan: InstallmentPlan; schedule: InstallmentSchedule } | null>(null);
  const { notify: sendFeedback } = useActionFeedback();
  const openPlans = plans.filter((plan) => plan.status === "Active").length;
  const filteredPlans = useMemo(() => {
    const normalized = query.trim().toLowerCase();

    return plans.filter((plan) => {
      const haystack = [
        plan.customerName,
        plan.receiptNumber,
        plan.salesOrderId,
        plan.frequency,
        plan.status,
      ].join(" ").toLowerCase();

      return (
        (!normalized || haystack.includes(normalized)) &&
        (statusFilter === "All" || plan.status === statusFilter) &&
        (frequencyFilter === "All" || plan.frequency === frequencyFilter)
      );
    });
  }, [frequencyFilter, plans, query, statusFilter]);

  useEffect(() => {
    const resetPage = window.setTimeout(() => setCurrentPage(1), 0);

    return () => window.clearTimeout(resetPage);
  }, [frequencyFilter, plans.length, query, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredPlans.length / plansPerPage));
  const safePage = Math.min(currentPage, totalPages);
  const visiblePlans = filteredPlans.slice((safePage - 1) * plansPerPage, safePage * plansPerPage);

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  return (
    <section className={styles.paymentPanel}>
      <header className={styles.sectionHeader}>
        <div>
          <p className={styles.eyebrow}>Customer finance</p>
          <h2>Installment schedules</h2>
        </div>
        <span className={styles.paymentCount}>{openPlans} active plans · {plans.length} total</span>
      </header>

      {plans.length > 0 ? (
        <div className={`${styles.filters} ${styles.installmentFilters}`} aria-label="Installment schedule filters">
          <label className={styles.searchBox}>
            <Search size={18} />
            <input placeholder="Search customer or sales ID..." value={query} onChange={(event) => setQuery(event.target.value)} />
          </label>
          <InstallmentFilterSelect icon={<Filter size={17} />} label="Status" options={["All", "Active", "Completed", "Cancelled"]} value={statusFilter} onChange={setStatusFilter} />
          <InstallmentFilterSelect icon={<CalendarDays size={17} />} label="Frequency" options={["All", "Weekly", "Monthly", "Yearly"]} value={frequencyFilter} onChange={setFrequencyFilter} />
        </div>
      ) : null}

      {plans.length === 0 ? <div className={styles.paymentEmpty}>No installment schedules recorded yet.</div> : null}
      {plans.length > 0 && filteredPlans.length === 0 ? <div className={styles.paymentEmpty}><strong>No installment schedules found.</strong><span>Try adjusting the search or filters.</span></div> : null}

      {filteredPlans.length > 0 ? <div className={styles.installmentPlans}>
        {visiblePlans.map((plan) => {
          const nextSchedule = plan.schedule.find((schedule) => schedule.status !== "Paid");

          return (
            <article className={styles.installmentPlanCard} key={plan.id}>
              <div className={styles.installmentPlanHeader}>
                <span>
                  <strong>{plan.customerName}</strong>
                  <small>{plan.receiptNumber} · {plan.frequency} · {plan.schedule.length} periods</small>
                </span>
                <span className={styles.installmentPlanTotals}>
                  <strong>{formatCurrency(plan.paidAmount)} <small>of {formatCurrency(plan.totalAmount)}</small></strong>
                  <em data-status={plan.status.toLowerCase()}>{plan.status}</em>
                </span>
              </div>
              <div className={styles.installmentProgress} aria-label={`${formatCurrency(plan.paidAmount)} paid of ${formatCurrency(plan.totalAmount)}`}><span style={{ width: `${Math.min((plan.paidAmount / plan.totalAmount) * 100, 100)}%` }} /></div>
              <div className={styles.installmentPlanMeta}>
                <span>Remaining <strong>{formatCurrency(plan.remainingAmount)}</strong></span>
                <span>Next due <strong>{nextSchedule ? formatDate(nextSchedule.dueDate) : "Completed"}</strong></span>
              </div>
              <div className={styles.installmentPlanActions}>
                <button aria-label={`View schedule for ${plan.customerName}`} className={styles.installmentExpandButton} type="button" onClick={() => setSelectedPlan(plan)}>
                  VIEW SCHEDULE
                  <CalendarDays size={16} />
                </button>
              </div>
            </article>
          );
        })}
      </div> : null}

      {totalPages > 1 ? (
        <div className={styles.paginationBar} aria-label="Installment plan pagination">
          <button aria-label="Previous installment plans" disabled={safePage === 1} type="button" onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}><ChevronLeft size={17} /></button>
          <div className={styles.pageNumbers}>
            {Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => (
              <button aria-current={page === safePage ? "page" : undefined} data-active={page === safePage ? "true" : "false"} key={page} type="button" onClick={() => setCurrentPage(page)}>{page}</button>
            ))}
          </div>
          <button aria-label="Next installment plans" disabled={safePage === totalPages} type="button" onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}><ChevronRight size={17} /></button>
        </div>
      ) : null}

      {selectedPlan ? <InstallmentScheduleModal plan={selectedPlan} onClose={() => setSelectedPlan(null)} onRecordPayment={(schedule) => { setSelectedPayment({ plan: selectedPlan, schedule }); }} /> : null}
      {selectedPayment ? <InstallmentPaymentModal
        selection={selectedPayment}
        onClose={() => { setSelectedPayment(null); setSelectedPlan(selectedPayment.plan); }}
        onError={(message) => notify("error", message)}
        onRecorded={() => {
          setSelectedPayment(null);
          setSelectedPlan(null);
          router.refresh();
          notify("success", "Installment payment recorded.");
        }}
      /> : null}
    </section>
  );
}

function InstallmentFilterSelect({
  icon,
  label,
  onChange,
  options,
  value,
}: {
  icon?: ReactNode;
  label: string;
  onChange: (value: string) => void;
  options: string[];
  value: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div
      className={styles.themedSelect}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        <span className={styles.themedSelectLabel}>{label}</span>
        <span className={styles.themedSelectValue}>{value}</span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? (
        <div className={styles.themedSelectMenu}>
          {options.map((option) => {
            const selected = option === value;

            return (
              <button
                className={styles.themedSelectOption}
                data-selected={selected ? "true" : "false"}
                key={option}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onChange(option);
                  setOpen(false);
                }}
              >
                <span>{option}</span>
                {selected ? <Check size={15} /> : null}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

export function InstallmentSaleSchedule({ plan }: { plan: InstallmentPlan }) {
  const router = useRouter();
  const [selectedPayment, setSelectedPayment] = useState<InstallmentSchedule | null>(null);
  const [scheduleOpen, setScheduleOpen] = useState(false);
  const { notify: sendFeedback } = useActionFeedback();

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  return (
    <section className={styles.installmentPlanCard}>
      <div className={styles.installmentPlanHeader}>
        <span><strong>Installment schedule</strong><small>{plan.frequency} · {formatCurrency(plan.paymentAmount)} planned per period</small></span>
        <span className={styles.installmentPlanTotals}><strong>{formatCurrency(plan.paidAmount)} <small>of {formatCurrency(plan.totalAmount)}</small></strong><em data-status={plan.status.toLowerCase()}>{plan.status}</em></span>
      </div>
      <div className={styles.installmentProgress}><span style={{ width: `${Math.min((plan.paidAmount / plan.totalAmount) * 100, 100)}%` }} /></div>
      <div className={styles.installmentPlanMeta}>
        <span>Remaining <strong>{formatCurrency(plan.remainingAmount)}</strong></span>
      </div>
      <div className={styles.installmentPlanActions}>
        <button aria-label="View installment schedule" className={styles.installmentExpandButton} type="button" onClick={() => setScheduleOpen(true)}>
          VIEW SCHEDULE
          <CalendarDays size={16} />
        </button>
      </div>
      {scheduleOpen ? <InstallmentScheduleModal plan={plan} onClose={() => setScheduleOpen(false)} onRecordPayment={(schedule) => { setSelectedPayment(schedule); }} /> : null}
      {selectedPayment ? <InstallmentPaymentModal
        selection={{ plan, schedule: selectedPayment }}
        onClose={() => { setSelectedPayment(null); setScheduleOpen(true); }}
        onError={(message) => notify("error", message)}
        onRecorded={() => {
          setSelectedPayment(null);
          setScheduleOpen(false);
          router.refresh();
          notify("success", "Installment payment recorded.");
        }}
      /> : null}
    </section>
  );
}

function InstallmentScheduleModal({
  plan,
  onClose,
  onRecordPayment,
}: {
  plan: InstallmentPlan;
  onClose: () => void;
  onRecordPayment: (schedule: InstallmentSchedule) => void;
}) {
  const nextPayableSchedule = plan.schedule.find((schedule) => schedule.status !== "Paid");
  const [detailsSchedule, setDetailsSchedule] = useState<InstallmentSchedule | null>(null);

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
      <section className={styles.installmentScheduleModal} role="dialog" aria-modal="true" aria-label="Installment schedule">
        <header className={styles.modalHeader}>
          <div><h3 className={styles.installmentModalTitle}>{plan.customerName}</h3><p className={styles.installmentModalSubtitle}>Installment schedule</p></div>
          <button aria-label="Close installment schedule" type="button" onClick={onClose}><X size={18} /></button>
        </header>
        <div className={styles.installmentPaymentSummary}><span><strong className={styles.installmentReceiptNumber}>{plan.receiptNumber}</strong> · {plan.frequency} payments</span><strong>{formatCurrency(plan.remainingAmount)} remaining</strong></div>
        <div className={`${styles.installmentScheduleList} ${styles.installmentScheduleModalList}`}>
          <div className={styles.installmentTimeline}>
            {plan.schedule.map((schedule) => {
              const completed = schedule.status === "Paid";

              return (
                <div className={`${styles.installmentTimelineItem} ${completed ? styles.installmentTimelineItemCompleted : ""}`} key={schedule.id}>
                  <div className={styles.installmentTimelineTrack} aria-hidden="true">
                    <span className={styles.installmentTimelinePoint}>{completed ? <Check size={22} strokeWidth={4} /> : schedule.installmentNumber}</span>
                  </div>
                  <div className={styles.installmentScheduleRow}>
                    <div><strong>Period {schedule.installmentNumber}</strong><small>Due {formatDate(schedule.dueDate)}</small></div>
                    <div><span>{formatCurrency(schedule.paidAmount)} / {formatCurrency(schedule.scheduledAmount)}</span><small>Remaining {formatCurrency(schedule.remainingAmount)}</small></div>
                    <em data-status={schedule.status.toLowerCase().replace(" ", "-")}>{schedule.status}</em>
                    {schedule.status === "Paid" ? <button className={styles.paymentDetailsButton} type="button" onClick={() => setDetailsSchedule(schedule)}>View details</button> : plan.status === "Active" ? <button className={`${styles.paymentMarkButton} ${schedule.id === nextPayableSchedule?.id ? "" : styles.paymentMarkButtonDisabled}`} disabled={schedule.id !== nextPayableSchedule?.id} type="button" onClick={() => onRecordPayment(schedule)}><span>Record</span></button> : <span className={styles.paymentComplete}>Unavailable</span>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>
      {detailsSchedule ? <InstallmentPaymentDetailsModal plan={plan} schedule={detailsSchedule} onClose={() => setDetailsSchedule(null)} /> : null}
    </div>
  );
}

function InstallmentPaymentDetailsModal({
  plan,
  schedule,
  onClose,
}: {
  plan: InstallmentPlan;
  schedule: InstallmentSchedule;
  onClose: () => void;
}) {
  const modal = (
    <div className={`${styles.modalBackdrop} ${styles.secondaryModalBackdrop}`} data-ui-backdrop="true" role="presentation">
      <section className={`${styles.installmentPaymentModal} ${styles.installmentDetailsModal}`} role="dialog" aria-modal="true" aria-label="Installment payment details">
        <header className={styles.modalHeader}>
          <div><p className={styles.eyebrow}>Period {schedule.installmentNumber}</p><h3>Payment details</h3></div>
          <button aria-label="Close payment details" type="button" onClick={onClose}><X size={18} /></button>
        </header>
        <div className={styles.installmentPaymentSummary}><span><strong className={styles.installmentReceiptNumber}>{plan.receiptNumber}</strong> · {plan.customerName}</span><strong>{formatCurrency(schedule.paidAmount)} paid</strong></div>
        <div className={styles.installmentDetailsSummary}>
          <span>Due <strong>{formatDate(schedule.dueDate)}</strong></span>
          <span>Scheduled <strong>{formatCurrency(schedule.scheduledAmount)}</strong></span>
          <span>Status <strong>{schedule.status}</strong></span>
        </div>
        <div className={styles.installmentPaymentHistory}>
          <h4>Recorded payments</h4>
          {schedule.payments.map((payment) => (
            <article className={styles.installmentPaymentHistoryRow} key={payment.id}>
              <div><strong>{formatCurrency(payment.amount)}</strong><small>{formatDate(payment.paymentDate)} · {payment.paymentMethod}{payment.otherPaymentMethod ? ` (${payment.otherPaymentMethod})` : ""}</small></div>
              <div>
                <span className={styles.paymentReference}>{payment.transactionReference ? `Ref: ${payment.transactionReference}` : "No transaction reference"}</span>
                {payment.notes ? <small>{payment.notes}</small> : null}
                {payment.receiptUrl ? (
                  <a className={`${uploadStyles.uploadArea} ${styles.recordedPaymentReceipt}`} href={payment.receiptUrl} rel="noreferrer" target="_blank" title="Open payment receipt">
                    <span className={uploadStyles.icon}><FileText size={18} strokeWidth={1.8} /></span>
                    <span className={uploadStyles.copy}>
                      <span className={uploadStyles.fileName}>Receipt attached</span>
                      <small>Opens in new tab</small>
                    </span>
                    <span className={uploadStyles.browse}>OPEN</span>
                  </a>
                ) : null}
              </div>
            </article>
          ))}
        </div>
        <div className={styles.modalActions}><button className={styles.secondaryButton} type="button" onClick={onClose}>Close</button></div>
      </section>
    </div>
  );

  return typeof document !== "undefined" ? createPortal(modal, document.body) : null;
}

function InstallmentPaymentModal({
  selection,
  onClose,
  onError,
  onRecorded,
}: {
  selection: { plan: InstallmentPlan; schedule: InstallmentSchedule };
  onClose: () => void;
  onError: (message: string) => void;
  onRecorded: () => void;
}) {
  const { plan, schedule } = selection;
  const today = new Date().toISOString().slice(0, 10);
  const [pending, startTransition] = useTransition();
  const [paymentMethod, setPaymentMethod] = useState("Cash");
  const [transactionReference, setTransactionReference] = useState("");
  const [otherPaymentMethod, setOtherPaymentMethod] = useState("");
  const { confirm, confirmationDialog } = useConfirmationDialog();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (pending) return;
    if (!form.reportValidity()) return;
    const formData = new FormData(form);
    const amount = Number(formData.get("amount"));

    const confirmed = await confirm({
      title: "Record installment payment?",
      message: `Record this payment for ${plan.customerName}, Period ${schedule.installmentNumber}.`,
      summary: <strong>{formatCurrency(amount)} via {paymentMethod}</strong>,
      confirmLabel: "Record payment",
      cancelLabel: "Review payment",
    });

    if (!confirmed) return;

    startTransition(async () => {
      try {
        await recordInstallmentPaymentAction(formData);
        onRecorded();
      } catch (error) {
        onError(error instanceof Error ? error.message : "The installment payment could not be recorded.");
      }
    });
  }

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
      <section className={styles.installmentPaymentModal} role="dialog" aria-modal="true" aria-label="Record installment payment">
        <header className={styles.modalHeader}><div><p className={styles.eyebrow}>Period {schedule.installmentNumber}</p><h3>Record payment</h3></div><button aria-label="Close payment modal" type="button" onClick={onClose}><X size={18} /></button></header>
        <div className={styles.installmentPaymentSummary}><span>{plan.customerName} · Due {formatDate(schedule.dueDate)}</span><strong>{formatCurrency(schedule.remainingAmount)} remaining</strong></div>
        <form className={styles.installmentPaymentForm} onSubmit={handleSubmit}>
          <input name="schedule_id" type="hidden" value={schedule.id} /><input name="sales_order_id" type="hidden" value={plan.salesOrderId} />
          <label>Amount received (PHP)<input max={schedule.remainingAmount} min="0.01" name="amount" required step="0.01" type="number" /></label>
          <CalendarField defaultValue={today} label="Payment date" max={today} name="payment_date" required />
          <InstallmentPaymentSelect label="Payment method" name="payment_method" options={["Cash", "GCash", "Bank Transfer", "Card", "Other"]} required value={paymentMethod} onChange={(value) => { setPaymentMethod(value); if (value === "Cash") setTransactionReference(""); if (value !== "Other") setOtherPaymentMethod(""); }} />
          {paymentMethod !== "Cash" ? <label>Transaction ID<input name="transaction_reference" placeholder="e.g. TXN-2026-0012" required type="text" value={transactionReference} onChange={(event) => setTransactionReference(event.target.value)} /></label> : null}
          {paymentMethod === "Other" ? <label>Other payment method<input name="other_payment_method" placeholder="e.g. Maya, cheque, farm credit" required type="text" value={otherPaymentMethod} onChange={(event) => setOtherPaymentMethod(event.target.value)} /></label> : null}
          <FileUploadField accept="image/jpeg,image/png,image/webp,application/pdf" helperText="JPG, PNG, WEBP or PDF · up to 5MB" kind="document" label="Receipt (optional)" name="receipt" prompt="Choose receipt file" />
          <label>Notes (optional)<textarea name="notes" placeholder="Add a collection note if needed" rows={3} /></label>
          <div className={styles.modalActions}><button className={styles.secondaryButton} disabled={pending} type="button" onClick={onClose}>Cancel</button><button className={styles.paymentPrimaryButton} disabled={pending} type="submit"><span>{pending ? "Recording..." : "Record payment"}</span></button></div>
        </form>
      </section>
      {confirmationDialog}
    </div>
  );
}

function InstallmentPaymentSelect({
  label,
  name,
  onChange,
  options,
  required = false,
  value,
}: {
  label: string;
  name: string;
  onChange: (value: string) => void;
  options: string[];
  required?: boolean;
  value: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <label className={styles.installmentPaymentSelectLabel}>
      <span>{label}{required ? <b aria-hidden="true" className={styles.installmentRequiredMark}> *</b> : null}</span>
      <input name={name} type="hidden" value={value} />
      <div className={`${styles.themedSelect} ${styles.themedSelectForm}`} onBlur={() => window.setTimeout(() => setOpen(false), 100)}>
        <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
          <span className={styles.themedSelectValue}>{value}</span>
          <ChevronDown size={17} />
        </button>
        {open ? (
          <div className={styles.themedSelectMenu}>
            {options.map((option) => (
              <button key={option} className={styles.themedSelectOption} data-selected={option === value ? "true" : "false"} type="button" onMouseDown={(event) => event.preventDefault()} onClick={() => { onChange(option); setOpen(false); }}>
                <span>{option}</span>
                {option === value ? <Check size={15} /> : null}
              </button>
            ))}
          </div>
        ) : null}
      </div>
    </label>
  );
}
