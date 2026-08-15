"use client";

import type { ReactNode } from "react";
import { useMemo, useRef, useState, useTransition } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { Check, ChevronDown, ChevronLeft, ChevronRight, ExternalLink, Eye, FileText, Filter, ReceiptText, Search, SlidersHorizontal, Trash2, WalletCards, X } from "lucide-react";
import { deleteExpenseAction } from "@/app/(portal)/investments/actions";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import styles from "@/app/(portal)/investments/page.module.css";

export type InvestmentRecord = {
  id: string;
  description: string;
  category: string;
  amount: number;
  expenseDate: string;
  vendor: string | null;
  paymentMethod: string;
  referenceNumber: string | null;
  expenseType: string;
  cropName: string | null;
  inventoryName: string | null;
  quantity: number | null;
  unitCost: number | null;
  notes: string | null;
  frequency: string | null;
  nextDueDate: string | null;
  endDate: string | null;
  hasReceipt: boolean;
  receiptUrl: string | null;
  receiptFileName: string | null;
  receiptKind: "image" | "pdf" | null;
};

function money(value: number) {
  return new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(value);
}

function FilterSelect({ icon, label, onChange, options, value }: { icon: ReactNode; label: string; onChange: (value: string) => void; options: string[]; value: string }) {
  const [open, setOpen] = useState(false);

  return (
    <div className={styles.themedSelect} onBlur={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setOpen(false); }}>
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
        <span className={styles.themedSelectIcon}>{icon}</span>
        <span className={styles.themedSelectLabel}>{label}</span>
        <span className={styles.themedSelectValue}>{value}</span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? (
        <div className={styles.themedSelectMenu}>
          {options.map((option) => (
            <button className={styles.themedSelectOption} data-selected={option === value ? "true" : "false"} key={option} type="button" onMouseDown={(event) => event.preventDefault()} onClick={() => { onChange(option); setOpen(false); }}>
              <span>{option}</span>{option === value ? <Check size={15} /> : null}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export function InvestmentHistory({ records }: { records: InvestmentRecord[] }) {
  const [selected, setSelected] = useState<InvestmentRecord | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [query, setQuery] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [category, setCategory] = useState("All");
  const [expenseType, setExpenseType] = useState("All");
  const [paymentMethod, setPaymentMethod] = useState("All");
  const [sortBy, setSortBy] = useState("Newest");
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);
  const [pending, startTransition] = useTransition();
  const alertIdRef = useRef(0);
  const router = useRouter();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const categories = ["All", ...new Set(records.map((record) => record.category))];
  const expenseTypes = ["All", ...new Set(records.map((record) => record.expenseType))];
  const paymentMethods = ["All", ...new Set(records.map((record) => record.paymentMethod))];
  const filteredRecords = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return records
      .filter((record) => {
        const haystack = [record.description, record.category, record.vendor ?? "", record.paymentMethod, record.referenceNumber ?? "", record.expenseType, record.cropName ?? "", record.inventoryName ?? ""].join(" ").toLowerCase();
        return (!normalizedQuery || haystack.includes(normalizedQuery))
          && (!startDate || record.expenseDate >= startDate)
          && (!endDate || record.expenseDate <= endDate)
          && (category === "All" || record.category === category)
          && (expenseType === "All" || record.expenseType === expenseType)
          && (paymentMethod === "All" || record.paymentMethod === paymentMethod);
      })
      .sort((left, right) => {
        if (sortBy === "Oldest") return left.expenseDate.localeCompare(right.expenseDate);
        if (sortBy === "Amount: High to low") return right.amount - left.amount;
        if (sortBy === "Amount: Low to high") return left.amount - right.amount;
        if (sortBy === "Description") return left.description.localeCompare(right.description);
        return right.expenseDate.localeCompare(left.expenseDate);
      });
  }, [category, endDate, expenseType, paymentMethod, query, records, sortBy, startDate]);
  const totalPages = Math.max(1, Math.ceil(filteredRecords.length / 8));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const visibleRecords = filteredRecords.slice((safeCurrentPage - 1) * 8, safeCurrentPage * 8);
  const pageStart = Math.min(Math.max(safeCurrentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);

  function notify(tone: AlertTone, text: string) {
    const id = ++alertIdRef.current;
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => setAlerts((current) => current.filter((alert) => alert.id !== id)), 4200);
  }

  async function removeRecord(record: InvestmentRecord) {
    const approved = await confirm({
      title: "Remove investment?",
      message: `Are you sure you want to remove ${record.description}? This cannot be undone.`,
      confirmLabel: "Remove Investment",
      cancelLabel: "Cancel",
      tone: "danger",
    });
    if (!approved) return;

    const formData = new FormData();
    formData.set("id", record.id);
    startTransition(async () => {
      try {
        await deleteExpenseAction(formData);
        setSelected(null);
        router.refresh();
        notify("success", "Success - Investment record removed.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Unable to remove investment."}`);
      }
    });
  }

  return (
    <>
      <div className={styles.filters}>
        <label className={styles.searchBox}>
          <Search size={18} />
          <input aria-label="Search investments" placeholder="Search description, vendor, reference, crop..." type="search" value={query} onChange={(event) => { setQuery(event.target.value); setCurrentPage(1); }} />
        </label>
        <label className={styles.dateField}>From<input type="date" value={startDate} onChange={(event) => { setStartDate(event.target.value); setCurrentPage(1); }} /></label>
        <label className={styles.dateField}>To<input type="date" value={endDate} onChange={(event) => { setEndDate(event.target.value); setCurrentPage(1); }} /></label>
        <FilterSelect icon={<Filter size={17} />} label="Category" options={categories} value={category} onChange={(value) => { setCategory(value); setCurrentPage(1); }} />
        <FilterSelect icon={<ReceiptText size={17} />} label="Type" options={expenseTypes} value={expenseType} onChange={(value) => { setExpenseType(value); setCurrentPage(1); }} />
        <FilterSelect icon={<WalletCards size={17} />} label="Payment" options={paymentMethods} value={paymentMethod} onChange={(value) => { setPaymentMethod(value); setCurrentPage(1); }} />
        <FilterSelect icon={<SlidersHorizontal size={17} />} label="Sort" options={["Newest", "Oldest", "Amount: High to low", "Amount: Low to high", "Description"]} value={sortBy} onChange={(value) => { setSortBy(value); setCurrentPage(1); }} />
      </div>

      {filteredRecords.length === 0 ? (
        <div className={styles.empty}>
          <strong>{records.length === 0 ? "No investments recorded yet." : "No investments match the current filters."}</strong>
          <span>{records.length === 0 ? "Use Record Investment to add the first farm cost." : "Try changing the search, dates, or filter selections."}</span>
        </div>
      ) : (
        <div className={styles.history}>
          <div className={styles.historyHeader}>
            <span>Description</span><span>Category</span><span>Vendor</span>
            <span>Amount</span><span>Date</span><span>Actions</span>
          </div>
          {visibleRecords.map((record) => (
            <div className={styles.historyRow} key={record.id}>
              <strong>{record.description}</strong>
              <span>{record.category}</span>
              <span>{record.vendor ?? "Not recorded"}</span>
              <span className={styles.amount}>{money(record.amount)}</span>
              <span>{record.expenseDate}</span>
              <div className={styles.rowActions}>
                <button aria-label="View investment details" type="button" onClick={() => setSelected(record)}><Eye size={17} /></button>
                <button aria-label="Remove investment" className={styles.removeAction} disabled={pending} type="button" onClick={() => removeRecord(record)}><Trash2 size={17} /></button>
              </div>
            </div>
          ))}
          <div className={styles.paginationBar} aria-label="Investment history pagination">
            <button aria-label="Previous investment page" disabled={safeCurrentPage === 1} type="button" onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}><ChevronLeft size={17} /></button>
            <div className={styles.pageNumbers}>
              {pageNumbers.map((page) => (
                <button aria-current={page === safeCurrentPage ? "page" : undefined} data-active={page === safeCurrentPage ? "true" : "false"} key={page} type="button" onClick={() => setCurrentPage(page)}>{page}</button>
              ))}
            </div>
            <button aria-label="Next investment page" disabled={safeCurrentPage === totalPages} type="button" onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}><ChevronRight size={17} /></button>
          </div>
        </div>
      )}

      {confirmationDialog}
      <ActionAlertStack alerts={alerts} onDismiss={(id) => setAlerts((current) => current.filter((alert) => alert.id !== id))} />

      {selected && typeof document !== "undefined"
        ? createPortal(
            <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
              <section className={`${styles.modal} ${styles.detailModal}`} data-ui-modal="true" role="dialog" aria-modal="true" aria-label="Investment details">
                <header className={styles.modalHeader}>
                  <h3 className={styles.modalTitle}>
                    <span className={styles.modalTitleIcon} aria-hidden="true"><ReceiptText size={18} /></span>
                    <span>Investment Details</span>
                  </h3>
                  <button aria-label="Close modal" className={styles.modalCloseButton} type="button" onClick={() => setSelected(null)}><X size={18} /></button>
                </header>
                <dl className={styles.detailGrid}>
                  <div><dt>Description</dt><dd>{selected.description}</dd></div>
                  <div><dt>Category</dt><dd>{selected.category}</dd></div>
                  <div><dt>Expense type</dt><dd>{selected.expenseType}</dd></div>
                  <div><dt>Total amount</dt><dd>{money(selected.amount)}</dd></div>
                  <div><dt>Expense date</dt><dd>{selected.expenseDate}</dd></div>
                  <div><dt>Vendor / payee</dt><dd>{selected.vendor ?? "Not recorded"}</dd></div>
                  <div><dt>Payment method</dt><dd>{selected.paymentMethod}</dd></div>
                  <div><dt>Reference number</dt><dd>{selected.referenceNumber ?? "Not recorded"}</dd></div>
                  <div><dt>Receipt</dt><dd>{selected.hasReceipt ? "Uploaded" : "Not uploaded"}</dd></div>
                  <div><dt>Related crop</dt><dd>{selected.cropName ?? "None"}</dd></div>
                  <div><dt>Related inventory</dt><dd>{selected.inventoryName ?? "None"}</dd></div>
                  <div><dt>Quantity</dt><dd>{selected.quantity ?? "Not recorded"}</dd></div>
                  <div><dt>Unit cost</dt><dd>{selected.unitCost === null ? "Not recorded" : money(selected.unitCost)}</dd></div>
                  <div><dt>Frequency</dt><dd>{selected.frequency ?? "Not recurring"}</dd></div>
                  <div><dt>Next due date</dt><dd>{selected.nextDueDate ?? "Not applicable"}</dd></div>
                  <div><dt>End date</dt><dd>{selected.endDate ?? "Not set"}</dd></div>
                  <div className={styles.detailNotes}><dt>Notes</dt><dd>{selected.notes ?? "No notes recorded."}</dd></div>
                  <div className={styles.detailReceipt}>
                    <dt>Receipt attachment</dt>
                    <dd>
                      {selected.receiptUrl && selected.receiptKind === "image" ? (
                        <a className={styles.receiptPreviewLink} href={selected.receiptUrl} target="_blank" rel="noreferrer" title="Open receipt image">
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img className={styles.receiptImage} src={selected.receiptUrl} alt={`Receipt for ${selected.description}`} />
                          <span><ExternalLink size={16} /> OPEN FULL IMAGE</span>
                        </a>
                      ) : selected.receiptUrl && selected.receiptKind === "pdf" ? (
                        <a className={styles.receiptFileLink} href={selected.receiptUrl} target="_blank" rel="noreferrer"><FileText size={20} /><span>{selected.receiptFileName ?? "Receipt PDF"}</span><ExternalLink size={16} /></a>
                      ) : selected.hasReceipt ? (
                        <span className={styles.receiptUnavailable}>The receipt is stored, but a preview link could not be created.</span>
                      ) : (
                        <span className={styles.receiptUnavailable}>No receipt was uploaded for this investment.</span>
                      )}
                    </dd>
                  </div>
                </dl>
              </section>
            </div>,
            document.body,
          )
        : null}
    </>
  );
}
