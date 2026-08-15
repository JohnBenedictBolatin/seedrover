"use client";

import type { FormEvent } from "react";
import { useRef, useState, useTransition } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { FileUp, X, TrendingUp } from "lucide-react";
import { createExpenseAction } from "@/app/(portal)/investments/actions";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import styles from "@/app/(portal)/investments/page.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";

export function InvestmentsWorkspace({ crops, inventoryItems }: { crops: Array<{ id: string; name: string }>; inventoryItems: Array<{ id: string; name: string }> }) {
  const [open, setOpen] = useState(false);
  const [expenseType, setExpenseType] = useState("One-time investment");
  const [receiptName, setReceiptName] = useState("");
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);
  const [pending, startTransition] = useTransition();
  const alertIdRef = useRef(0);
  const router = useRouter();
  const { confirm, confirmationDialog } = useConfirmationDialog();

  function notify(tone: AlertTone, text: string) {
    const id = ++alertIdRef.current;
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => setAlerts((current) => current.filter((alert) => alert.id !== id)), 4200);
  }

  function closeModal() {
    if (!pending) setOpen(false);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const approved = await confirm({
      message: "Are you sure you want to save this investment record?",
      confirmLabel: "Save Investment",
    });
    if (!approved) return;
    const formData = new FormData(form);
    startTransition(async () => {
      try {
        await createExpenseAction(formData);
        form.reset();
        setExpenseType("One-time investment");
        setReceiptName("");
        setOpen(false);
        router.refresh();
        notify("success", "Success - Investment record saved.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Unable to save investment."}`);
      }
    });
  }

  return (
    <>
    <section className={quickActionStyles.quickActions}>
      <div>
        <p className={quickActionStyles.eyebrow}>Quick action</p>
        <h2>Record a new investment</h2>
        <span>Open the investment form only when you need to add a farm cost.</span>
      </div>
      <button className={`${quickActionStyles.recordSaleButton} ${styles.investmentButton}`} type="button" onClick={() => setOpen(true)}>
          <span className={`${quickActionStyles.recordSaleText} ${styles.investmentButtonText}`}>RECORD INVESTMENT</span>
          <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><TrendingUp size={22} /></span>
      </button>
      {open && typeof document !== "undefined" ? createPortal((
        <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
          <section aria-label="Record investment" aria-modal="true" className={styles.modal} data-ui-modal="true" role="dialog">
            <header className={styles.modalHeader}><h3 className={styles.modalTitle}><span className={styles.modalTitleIcon} aria-hidden="true"><TrendingUp size={18} /></span><span>Record Investment</span></h3><button aria-label="Close modal" className={styles.modalCloseButton} disabled={pending} type="button" onClick={closeModal}><X size={18} /></button></header>
            <form className={styles.modalForm} onSubmit={handleSubmit}>
              <label>Description<input name="description" required placeholder="e.g. Fertilizer purchase" /></label>
              <div className={styles.modalColumns}><label>Category<select name="category"><option>Resources</option><option>Equipment</option><option>Labor</option><option>Utilities</option><option>Transport</option><option>Other</option></select></label><label>Expense type<select name="expense_type" value={expenseType} onChange={(event) => setExpenseType(event.target.value)}><option>One-time investment</option><option>Recurring expense</option></select></label></div>
              <div className={styles.modalColumns}><label>Vendor / payee<input name="vendor" placeholder="e.g. AgriSupply Trading" /></label><label>Payment method<select name="payment_method"><option>Cash</option><option>GCash</option><option>Bank Transfer</option><option>Card</option><option>Other</option></select></label></div>
              <div className={styles.modalColumns}><label>Amount<input name="amount" min="0.01" placeholder="e.g. 2500.00" required step="0.01" type="number" /></label><label>Expense date<input name="expense_date" type="date" /></label></div>
              <div className={styles.modalColumns}><label>Quantity<input name="quantity" min="0.01" placeholder="e.g. 10" step="0.01" type="number" /></label><label>Unit cost<input name="unit_cost" min="0" placeholder="e.g. 250.00" step="0.01" type="number" /></label></div>
              <label>Receipt / reference number<input name="reference_number" placeholder="e.g. INV-2026-0042" /></label>
              <div className={styles.modalColumns}><label>Related crop<select name="related_crop_id"><option value="">No related crop</option>{crops.map((crop) => <option key={crop.id} value={crop.id}>{crop.name}</option>)}</select></label><label>Related inventory item<select name="related_inventory_id"><option value="">No related inventory item</option>{inventoryItems.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label></div>
              {expenseType === "Recurring expense" ? <><div className={styles.modalColumns}><label>Frequency<select name="frequency" required><option>Weekly</option><option>Monthly</option><option>Quarterly</option><option>Yearly</option></select></label><label>Next due date<input name="next_due_date" required type="date" /></label></div><label>End date<input name="end_date" type="date" /></label></> : null}
              <label className={styles.filePicker}><span>Receipt image or PDF</span><input accept="image/jpeg,image/png,image/webp,application/pdf" name="receipt" type="file" onChange={(event) => setReceiptName(event.target.files?.[0]?.name ?? "")} /><i><FileUp size={17} /><span>{receiptName || "Choose receipt file"}</span></i></label>
              <label>Notes<textarea name="notes" placeholder="e.g. Supplies for the upcoming planting cycle" rows={3} /></label>
              <div className={styles.modalActions}><button className={styles.modalCancel} disabled={pending} type="button" onClick={closeModal}>CANCEL</button><button className={styles.primaryAction} disabled={pending} type="submit"><span>{pending ? "SAVING..." : "SAVE INVESTMENT"}</span></button></div>
            </form>
            {confirmationDialog}
          </section>
        </div>
      ), document.body) : null}
    </section>
    <ActionAlertStack alerts={alerts} onDismiss={(id) => setAlerts((current) => current.filter((alert) => alert.id !== id))} />
    </>
  );
}
