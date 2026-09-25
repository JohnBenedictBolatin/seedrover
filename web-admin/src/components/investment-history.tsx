"use client";

import type { ReactNode } from "react";
import { useMemo, useState, useTransition } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { Check, ChevronDown, ChevronLeft, ChevronRight, Eye, FileText, Filter, ReceiptText, Search, SlidersHorizontal, Trash2, X } from "lucide-react";
import { deleteExpenseAction } from "@/app/(portal)/investments/actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { CalendarField } from "@/components/calendar-field";
import uploadStyles from "@/components/file-upload-field.module.css";
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
  const [sortBy, setSortBy] = useState("Newest");
  const [pending, startTransition] = useTransition();
  const { notify: sendFeedback } = useActionFeedback();
  const router = useRouter();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const categories = ["All", ...new Set(records.map((record) => record.category))];
  const filteredRecords = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return records
      .filter((record) => {
        const haystack = [record.description, record.category, record.vendor ?? "", record.paymentMethod, record.referenceNumber ?? "", record.expenseType, record.cropName ?? "", record.inventoryName ?? ""].join(" ").toLowerCase();
        return (!normalizedQuery || haystack.includes(normalizedQuery))
          && (!startDate || record.expenseDate >= startDate)
          && (!endDate || record.expenseDate <= endDate)
          && (category === "All" || record.category === category);
      })
      .sort((left, right) => {
        if (sortBy === "Oldest") return left.expenseDate.localeCompare(right.expenseDate);
        if (sortBy === "Amount: High to low") return right.amount - left.amount;
        if (sortBy === "Amount: Low to high") return left.amount - right.amount;
        if (sortBy === "Item") return left.description.localeCompare(right.description);
        return right.expenseDate.localeCompare(left.expenseDate);
      });
  }, [category, endDate, query, records, sortBy, startDate]);
  const totalPages = Math.max(1, Math.ceil(filteredRecords.length / 8));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const visibleRecords = filteredRecords.slice((safeCurrentPage - 1) * 8, safeCurrentPage * 8);
  const pageStart = Math.min(Math.max(safeCurrentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  async function removeRecord(record: InvestmentRecord) {
    const approved = await confirm({
      title: "Remove farm cost?",
      message: `Remove ${record.description}? This cannot be undone.`,
      confirmLabel: "Remove cost",
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
        notify("success", "Farm cost removed.");
      } catch (error) {
        notify("error", error instanceof Error ? error.message : "Unable to remove the farm cost.");
      }
    });
  }

  return (
    <>
      <div className={styles.filters}>
        <label className={styles.searchBox}>
          <Search size={18} />
          <input aria-label="Search investments" placeholder="Search item, vendor, reference, crop..." type="search" value={query} onChange={(event) => { setQuery(event.target.value); setCurrentPage(1); }} />
        </label>
        <CalendarField className={styles.dateField} label="From" value={startDate} onChange={(nextValue) => { setStartDate(nextValue); setCurrentPage(1); }} />
        <CalendarField className={styles.dateField} label="To" value={endDate} onChange={(nextValue) => { setEndDate(nextValue); setCurrentPage(1); }} />
        <FilterSelect icon={<Filter size={17} />} label="Category" options={categories} value={category} onChange={(value) => { setCategory(value); setCurrentPage(1); }} />
        <FilterSelect icon={<SlidersHorizontal size={17} />} label="Sort" options={["Newest", "Oldest", "Amount: High to low", "Amount: Low to high", "Item"]} value={sortBy} onChange={(value) => { setSortBy(value); setCurrentPage(1); }} />
      </div>

      {filteredRecords.length === 0 ? (
        <div className={styles.empty}>
          <strong>{records.length === 0 ? "No farm costs recorded yet." : "No farm costs match the current filters."}</strong>
          {records.length > 0 ? <span>Change the search, dates, or filters.</span> : null}
        </div>
      ) : (
        <div className={styles.history}>
          <div className={styles.historyHeader}>
            <span>Item</span><span>Category</span><span>Vendor</span>
            <span>Amount (PHP)</span><span>Date</span><span>Actions</span>
          </div>
          {visibleRecords.map((record) => (
            <div className={styles.historyRow} key={record.id}>
              <strong data-label="Item">{record.description}</strong>
              <span data-label="Category">{record.category}</span>
              <span data-label="Vendor">{record.vendor ?? "Not recorded"}</span>
              <span className={styles.amount} data-label="Amount (PHP)">{money(record.amount)}</span>
              <span className={styles.historyDate} data-label="Date">{record.expenseDate}</span>
              <div className={styles.rowActions} data-label="Actions">
                <button aria-label="View farm cost details" type="button" onClick={() => setSelected(record)}><Eye size={17} /></button>
                <button aria-label="Remove farm cost" className={styles.removeAction} disabled={pending} type="button" onClick={() => removeRecord(record)}><Trash2 size={17} /></button>
              </div>
            </div>
          ))}
          <div className={styles.paginationBar} aria-label="Farm cost history pagination">
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

      {selected && typeof document !== "undefined"
        ? createPortal(
            <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
              <section className={`${styles.modal} ${styles.detailModal}`} data-ui-modal="true" role="dialog" aria-modal="true" aria-label="Farm cost details">
                <header className={styles.modalHeader}>
                  <h3 className={styles.modalTitle}>
                    <span className={styles.modalTitleIcon} aria-hidden="true"><ReceiptText size={18} /></span>
                    <span>
                      <small className={styles.detailEyebrow}>Farm cost details</small>
                      <strong>{selected.description}</strong>
                    </span>
                  </h3>
                  <button aria-label="Close modal" className={styles.modalCloseButton} type="button" onClick={() => setSelected(null)}><X size={18} /></button>
                </header>
                <div className={styles.detailHero}>
                  <div className={styles.detailHeroInfo}>
                    <span className={styles.detailHeroLabel}>{selected.category}</span>
                    <span className={styles.detailHeroMeta}>{selected.expenseType} · {selected.expenseDate}</span>
                  </div>
                  <div className={styles.detailHeroAmount}>
                    <span>Total amount (PHP)</span>
                    <strong>{money(selected.amount)}</strong>
                  </div>
                </div>
                <dl className={styles.detailGrid}>
                  <div><dt>Vendor / payee</dt><dd>{selected.vendor ?? "Not recorded"}</dd></div>
                  <div><dt>Payment method</dt><dd>{selected.paymentMethod}</dd></div>
                  <div><dt>Reference number</dt><dd>{selected.referenceNumber ?? "Not recorded"}</dd></div>
                  <div><dt>Receipt</dt><dd>{selected.hasReceipt ? "Uploaded" : "Not uploaded"}</dd></div>
                  <div><dt>Related crop</dt><dd>{selected.cropName ?? "None"}</dd></div>
                  <div><dt>Related inventory</dt><dd>{selected.inventoryName ?? "None"}</dd></div>
                  <div><dt>Quantity</dt><dd>{selected.quantity ?? "Not recorded"}</dd></div>
                  <div><dt>Unit cost (PHP)</dt><dd>{selected.unitCost === null ? "Not recorded" : money(selected.unitCost)}</dd></div>
                  <div className={styles.detailNotes}><dt>Notes</dt><dd>{selected.notes ?? "No notes recorded."}</dd></div>
                  <div className={styles.detailReceipt}>
                    <dt>Receipt attachment</dt>
                    <dd>
                      {selected.receiptUrl && selected.receiptKind === "image" ? (
                        <a className={`${uploadStyles.uploadArea} ${styles.receiptUploadLink}`} href={selected.receiptUrl} target="_blank" rel="noreferrer" title="Open receipt image">
                          <span className={uploadStyles.icon}><FileText size={20} strokeWidth={1.8} /></span>
                          <span className={uploadStyles.copy}>
                            <span className={uploadStyles.fileName}>{selected.receiptFileName ?? "Receipt image"}</span>
                            <small>Image receipt · opens in new tab</small>
                          </span>
                          <span className={uploadStyles.browse}>OPEN</span>
                        </a>
                      ) : selected.receiptUrl && selected.receiptKind === "pdf" ? (
                        <a className={`${uploadStyles.uploadArea} ${styles.receiptUploadLink}`} href={selected.receiptUrl} target="_blank" rel="noreferrer" title="Open receipt PDF">
                          <span className={uploadStyles.icon}><FileText size={20} strokeWidth={1.8} /></span>
                          <span className={uploadStyles.copy}>
                            <span className={uploadStyles.fileName}>{selected.receiptFileName ?? "Receipt PDF"}</span>
                            <small>PDF receipt · opens in new tab</small>
                          </span>
                          <span className={uploadStyles.browse}>OPEN</span>
                        </a>
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
