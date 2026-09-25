"use client";

import type { FormEvent } from "react";
import { useState, useTransition } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { Check, ChevronDown, X, TrendingUp } from "lucide-react";
import { createExpenseAction } from "@/app/(portal)/investments/actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { CalendarField } from "@/components/calendar-field";
import { FileUploadField } from "@/components/file-upload-field";
import styles from "@/app/(portal)/investments/page.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";

function RecordCostSelect({ defaultValue, label, name, options, required = false }: { defaultValue: string; label: string; name: string; options: string[]; required?: boolean }) {
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(defaultValue || options[0] || "");

  return (
    <div className={styles.modalSelectField}>
      <span>{label}{required ? <b aria-hidden="true"> *</b> : null}</span>
      <div
        className={styles.themedSelect}
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setOpen(false);
        }}
      >
        <input name={name} type="hidden" value={value} />
        <button aria-expanded={open} aria-haspopup="listbox" aria-label={label} className={`${styles.themedSelectButton} ${styles.modalSelectButton}`} type="button" onClick={() => setOpen((current) => !current)}>
          <span className={styles.themedSelectValue}>{value}</span>
          <ChevronDown className={styles.themedSelectChevron} size={16} />
        </button>
        {open ? (
          <div className={styles.themedSelectMenu} role="listbox">
            {options.map((option) => {
              const selected = option === value;
              return (
                <button
                  aria-selected={selected}
                  className={styles.themedSelectOption}
                  data-selected={selected ? "true" : "false"}
                  key={option}
                  role="option"
                  type="button"
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => { setValue(option); setOpen(false); }}
                >
                  <span>{option}</span>
                  {selected ? <Check size={15} /> : null}
                </button>
              );
            })}
          </div>
        ) : null}
      </div>
    </div>
  );
}

export function InvestmentsWorkspace() {
  const [open, setOpen] = useState(false);
  const { notify: sendFeedback } = useActionFeedback();
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const { confirm, confirmationDialog } = useConfirmationDialog();

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  function closeModal() {
    if (!pending) setOpen(false);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const approved = await confirm({
      title: "Record farm cost?",
      message: "This will add the expense to farm financial records.",
      confirmLabel: "Save cost",
    });
    if (!approved) return;
    const formData = new FormData(form);
    startTransition(async () => {
      try {
        await createExpenseAction(formData);
        form.reset();
        setOpen(false);
        router.refresh();
        notify("success", "Farm cost saved.");
      } catch (error) {
        notify("error", error instanceof Error ? error.message : "Unable to save the farm cost.");
      }
    });
  }

  return (
    <>
    <section className={quickActionStyles.quickActions}>
      <div>
        <p className={quickActionStyles.eyebrow}>Quick action</p>
        <h2>Record a farm cost</h2>
        <span>Add an actual capital investment or operating expense with its payment and receipt.</span>
      </div>
      <button className={`${quickActionStyles.recordSaleButton} ${styles.investmentButton}`} type="button" onClick={() => setOpen(true)}>
          <span className={`${quickActionStyles.recordSaleText} ${styles.investmentButtonText}`}>RECORD COST</span>
          <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><TrendingUp size={22} /></span>
      </button>
      {open && typeof document !== "undefined" ? createPortal((
        <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
          <section aria-label="Record farm cost" aria-modal="true" className={styles.modal} data-ui-modal="true" role="dialog">
            <header className={styles.modalHeader}><h3 className={styles.modalTitle}><span className={styles.modalTitleIcon} aria-hidden="true"><TrendingUp size={18} /></span><span>Record Farm Cost</span></h3><button aria-label="Close modal" className={styles.modalCloseButton} disabled={pending} type="button" onClick={closeModal}><X size={18} /></button></header>
            <form className={styles.modalForm} onSubmit={handleSubmit}>
              <label><span>Item</span><input name="description" required placeholder="e.g. Fertilizer" /></label>
              <div className={styles.modalColumns}><RecordCostSelect label="Category" name="category" options={["Resources", "Equipment", "Labor", "Utilities", "Transport", "Other"]} defaultValue="Resources" required /><RecordCostSelect defaultValue="Capital investment" label="Cost type" name="expense_type" options={["Capital investment", "Operating expense"]} required /></div>
              <div className={styles.modalColumns}><label>Vendor / payee<input name="vendor" placeholder="e.g. AgriSupply Trading" /></label><RecordCostSelect defaultValue="Cash" label="Payment method" name="payment_method" options={["Cash", "GCash", "Bank Transfer", "Card", "Other"]} required /></div>
              <div className={styles.modalColumns}><label><span>Amount (PHP)</span><input name="amount" min="0.01" placeholder="e.g. 2500.00" required step="0.01" type="number" /></label><CalendarField label="Expense date" name="expense_date" required /></div>
              <label>Receipt / reference number<input name="reference_number" placeholder="e.g. INV-2026-0042" /></label>
              <FileUploadField accept="image/jpeg,image/png,image/webp,application/pdf" helperText="JPG, PNG, WEBP or PDF" kind="document" label="Receipt image or PDF" name="receipt" prompt="Choose receipt file" />
              <label>Notes<textarea name="notes" placeholder="e.g. Supplies for the upcoming planting cycle" rows={3} /></label>
              <div className={styles.modalActions}><button className={styles.modalCancel} disabled={pending} type="button" onClick={closeModal}>CANCEL</button><button className={styles.primaryAction} disabled={pending} type="submit"><span>{pending ? "SAVING..." : "SAVE COST"}</span></button></div>
            </form>
            {confirmationDialog}
          </section>
        </div>
      ), document.body) : null}
    </section>
    </>
  );
}
