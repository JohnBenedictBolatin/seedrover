"use client";

import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  CalendarDays,
  CheckCircle2,
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Eye,
  FileDown,
  Filter,
  Hash,
  Package,
  Printer,
  Receipt,
  Search,
  TrendingUp,
  Undo2,
  WalletCards,
  X,
} from "lucide-react";
import { voidSalesRecordAction } from "@/app/(portal)/sales/actions";
import { formatCurrency, formatDate, formatDateTime, formatQuantity } from "@/lib/format";
import type {
  ReleasedDiscount,
  RecentSalesOrder,
  SalesSummary,
  SellableItem,
} from "@/lib/sales";
import { CountUpValue } from "@/components/count-up-value";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { ReportPrintButton } from "@/components/report-print-button";
import { SalesOrderForm } from "@/components/sales-order-form";
import { ExportDownloadButton } from "@/components/export-download-button";
import { CalendarField } from "@/components/calendar-field";
import styles from "@/app/(portal)/sales/page.module.css";

type SalesWorkspaceProps = {
  discounts: ReleasedDiscount[];
  items: SellableItem[];
  orders: RecentSalesOrder[];
  summary: SalesSummary;
};

const SALES_ROWS_PER_PAGE = 8;

function todayInputValue(offsetDays = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function matchesDateRange(order: RecentSalesOrder, start: string, end: string) {
  const time = new Date(order.saleDate).getTime();
  const startTime = start ? new Date(`${start}T00:00:00`).getTime() : -Infinity;
  const endTime = end ? new Date(`${end}T23:59:59`).getTime() : Infinity;
  return time >= startTime && time <= endTime;
}

function FilterSelect({
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
      className={`${styles.themedSelect} ${styles.themedSelectToolbar}`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      <button
        aria-expanded={open}
        className={styles.themedSelectButton}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
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

export function SalesWorkspace({
  discounts,
  items,
  orders,
  summary,
}: SalesWorkspaceProps) {
  const [query, setQuery] = useState("");
  const [payment, setPayment] = useState("All");
  const [status, setStatus] = useState("All");
  const [startDate, setStartDate] = useState(todayInputValue(-30));
  const [endDate, setEndDate] = useState(todayInputValue());
  const [saleDetail, setSaleDetail] = useState<RecentSalesOrder | null>(null);
  const [salesModalOpen, setSalesModalOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const voidReasons = useRef<Record<string, string>>({});
  const [voidPending, startVoidTransition] = useTransition();
  const router = useRouter();
  const { notify: sendFeedback } = useActionFeedback();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const closeSalesModal = useCallback(() => setSalesModalOpen(false), []);

  const notify = useCallback((tone: AlertTone, text: string) => {
    sendFeedback({ tone, text });
  }, [sendFeedback]);

  async function handleVoid(order: RecentSalesOrder) {
    if (voidPending) return;
    const source = order.source;
    if (source !== "receipt" && source !== "market") {
      notify("error", "This sales record cannot be voided.");
      return;
    }
    const voidReason = voidReasons.current[order.id] ?? "Incorrect sales transaction.";
    const confirmed = await confirm({
      title: "Void this sale?",
      message: `Void receipt ${order.receiptNumber} and return the sold quantity to inventory?`,
      summary: <label>Void reason<textarea rows={3} defaultValue={voidReason} onChange={(event) => { voidReasons.current[order.id] = event.target.value; }} /></label>,
      confirmLabel: "Void sale",
      tone: "danger",
    });
    if (!confirmed) return;
    const formData = new FormData();
    formData.set("id", order.id);
    formData.set("source", source);
    formData.set("reason", voidReasons.current[order.id] ?? voidReason);

    startVoidTransition(async () => {
      try {
        await voidSalesRecordAction(formData);
        delete voidReasons.current[order.id];
        router.refresh();
        notify("success", "Sale voided and inventory restored.");
      } catch (error) {
        notify(
          "error",
          error instanceof Error ? error.message : "Unable to void sale.",
        );
      }
    });
  }

  const filteredOrders = useMemo(() => {
    const normalized = query.trim().toLowerCase();

    return orders.filter((order) => {
      const haystack = [
        order.receiptNumber,
        order.customerName,
        order.transactionReference ?? "",
        order.marketItemName ?? "",
        order.paymentMethod,
        order.entryLabel ?? "",
        order.status,
      ]
        .join(" ")
        .toLowerCase();

      return (
        (!normalized || haystack.includes(normalized)) &&
        (payment === "All" || order.paymentMethod === payment) &&
        (status === "All" || order.status === status) &&
        matchesDateRange(order, startDate, endDate)
      );
    });
  }, [endDate, orders, payment, query, startDate, status]);

  useEffect(() => {
    const resetPage = window.setTimeout(() => setCurrentPage(1), 0);

    return () => window.clearTimeout(resetPage);
  }, [endDate, payment, query, startDate, status]);

  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / SALES_ROWS_PER_PAGE));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const paginatedOrders = filteredOrders.slice(
    (safeCurrentPage - 1) * SALES_ROWS_PER_PAGE,
    safeCurrentPage * SALES_ROWS_PER_PAGE,
  );
  const pageStart = Math.min(Math.max(safeCurrentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);

  const paymentOptions = ["All", ...new Set(orders.map((order) => order.paymentMethod))];
  const statusOptions = ["All", ...new Set(orders.map((order) => order.status))];
  const exportParams = new URLSearchParams();

  if (startDate) {
    exportParams.set("start", startDate);
  }

  if (endDate) {
    exportParams.set("end", endDate);
  }

  if (payment !== "All") {
    exportParams.set("payment", payment);
  }

  if (status !== "All") {
    exportParams.set("status", status);
  }

  const exportQuery = exportParams.toString();

  return (
    <>
      <section className={styles.metricGrid} aria-label="Sales summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <CalendarDays size={20} />
            </span>
            <p>Sales today</p>
          </div>
          <CountUpValue className="mono" currency value={summary.salesToday} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <TrendingUp size={20} />
            </span>
            <p>Sales this month</p>
          </div>
          <CountUpValue className="mono" currency value={summary.salesThisMonth} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Receipt size={20} />
            </span>
            <p>Transactions</p>
          </div>
          <CountUpValue className="mono" value={summary.transactions} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <WalletCards size={20} />
            </span>
            <p>Average sale</p>
          </div>
          <CountUpValue className="mono" currency value={summary.averageTransactionValue} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <CheckCircle2 size={20} />
            </span>
            <p>Completed sales</p>
          </div>
          <CountUpValue className="mono" value={summary.completedSalesCount} />
        </article>
      </section>

      <section className={`${styles.metricGrid} ${styles.collectionMetricGrid}`} aria-label="Collections summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon} aria-hidden="true"><WalletCards size={20} /></span><p>Collected today</p></div>
          <CountUpValue className="mono" currency value={summary.collectedToday} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}><span className={styles.metricIcon} aria-hidden="true"><WalletCards size={20} /></span><p>Collected this month</p></div>
          <CountUpValue className="mono" currency value={summary.collectedThisMonth} />
        </article>
      </section>

      <section className={styles.quickActions}>
        <div>
          <p className={styles.eyebrow}>Quick action</p>
          <h2>Record a new sale</h2>
          <span>Create a receipt and deduct the sold quantities from inventory.</span>
        </div>
        <button
          className={styles.recordSaleButton}
          type="button"
          onClick={() => setSalesModalOpen(true)}
        >
          <span className={styles.recordSaleText}>Record Sale</span>
          <span className={styles.recordSaleIcon} aria-hidden="true">
            <Receipt size={22} />
          </span>
        </button>
      </section>

      <section className={styles.receipts}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Receipts</p>
            <h2>Sales history</h2>
          </div>
          <div className={styles.exportActions}>
            <ExportDownloadButton href={`/api/exports/sales.csv${exportQuery ? `?${exportQuery}` : ""}`}>
              <FileDown size={17} />
              CSV
            </ExportDownloadButton>
            <ExportDownloadButton href={`/api/exports/sales.xls${exportQuery ? `?${exportQuery}` : ""}`}>
              <FileDown size={17} />
              Excel
            </ExportDownloadButton>
            <ReportPrintButton href={`/reports/sales/print${exportQuery ? `?${exportQuery}` : ""}`}>
              <Printer size={17} />
              Print / PDF
            </ReportPrintButton>
          </div>
        </div>

        <div className={styles.filters}>
          <label className={styles.searchBox}>
            <Search size={18} />
            <input
              placeholder="Search receipt, customer, payment..."
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          <CalendarField label="From" value={startDate} onChange={setStartDate} />
          <CalendarField label="To" value={endDate} onChange={setEndDate} />
          <FilterSelect
            icon={<Filter size={17} />}
            label="Payment"
            options={paymentOptions}
            value={payment}
            onChange={setPayment}
          />
          <FilterSelect
            icon={<CheckCircle2 size={17} />}
            label="Status"
            options={statusOptions}
            value={status}
            onChange={setStatus}
          />
        </div>

        {filteredOrders.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No sales found.</strong>
            <span>Try adjusting the filters or record a new transaction.</span>
          </div>
        ) : (
          <div className={styles.salesTable}>
            <div className={styles.salesTableHead}>
              <span>Receipt</span>
              <span>Date/Time</span>
              <span>Customer</span>
              <span>Type</span>
              <span>Items</span>
              <span>Payment</span>
              <span>Discount</span>
              <span>Sale / payment</span>
              <span>Status</span>
              <span>Actions</span>
            </div>
            {paginatedOrders.map((order) => (
              <div className={styles.salesTableRow} key={`${order.source}-${order.id}`}>
                {order.source === "payment" ? (
                  <Link className={styles.receiptCellLink} data-label="Receipt" href={`/sales/${order.relatedSaleId ?? order.id}`}>{order.receiptNumber}</Link>
                ) : (
                  <strong className={styles.receiptCell} data-label="Receipt">{order.receiptNumber}</strong>
                )}
                <span className={styles.dateCell} data-label={order.source === "payment" ? "Collection date" : "Date / time"}>{order.source === "payment" ? formatDate(order.saleDate) : formatDateTime(order.saleDate)}</span>
                <strong className={styles.customerCell} data-label="Customer">{order.customerName}</strong>
                <span className={styles.typeCell} data-label="Type">
                  {order.source === "payment" ? order.entryLabel : order.source === "market" ? "Market distribution" : order.paymentMethod === "Installment" ? "Installment sale" : "Receipt sale"}
                </span>
                <span className={styles.itemsCell} data-label="Items">{order.source === "payment" ? "-" : order.itemCount ?? 1}</span>
                <span className={styles.paymentCell} data-label="Payment">
                  {order.paymentMethod}
                  {order.source === "payment" && order.transactionReference ? <small>Ref: {order.transactionReference}</small> : null}
                </span>
                <span className={styles.discountCell} data-label="Discount">{order.source === "payment" ? "-" : formatCurrency(order.discountAmount ?? 0)}</span>
                <strong className={styles.totalCell} data-label={order.source === "payment" ? "Collected" : "Sale total"}>{formatCurrency(order.source === "payment" ? order.paymentAmount ?? 0 : order.totalAmount)}</strong>
                <div className={styles.statusCell} data-label="Status">
                  <span className={styles.statusPill} data-status={order.status.toLowerCase()}>
                    {order.source === "payment" && order.status === "Voided" ? "Sale voided" : order.source === "payment" ? "Recorded" : order.status}
                  </span>
                </div>
                <div className={styles.tableActions} data-label="Actions">
                  {order.source === "payment" ? (
                    <Link aria-label="View linked sale receipt" href={`/sales/${order.relatedSaleId ?? order.id}`}>
                      <Eye size={17} />
                    </Link>
                  ) : order.source === "receipt" ? (
                    <button
                      aria-label="View receipt details"
                      type="button"
                      onClick={() => setSaleDetail(order)}
                    >
                      <Eye size={17} />
                    </button>
                  ) : (
                    <button
                      aria-label="View market distribution details"
                      type="button"
                      onClick={() => setSaleDetail(order)}
                    >
                      <Eye size={17} />
                    </button>
                  )}
                  {order.source !== "payment" && order.status === "Completed" ? (
                    <button
                      aria-label="Void sale"
                      type="button"
                      onClick={() => void handleVoid(order)}
                    >
                      <Undo2 size={17} />
                    </button>
                  ) : null}
                </div>
              </div>
            ))}
            <div className={styles.paginationBar} aria-label="Sales history pagination">
              <button
                aria-label="Previous sales page"
                disabled={safeCurrentPage === 1}
                type="button"
                onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}
              >
                <ChevronLeft size={17} />
              </button>
              <div className={styles.pageNumbers}>
                {pageNumbers.map((page) => (
                  <button
                    aria-current={page === safeCurrentPage ? "page" : undefined}
                    data-active={page === safeCurrentPage ? "true" : "false"}
                    key={page}
                    type="button"
                    onClick={() => setCurrentPage(page)}
                  >
                    {page}
                  </button>
                ))}
              </div>
              <button
                aria-label="Next sales page"
                disabled={safeCurrentPage === totalPages}
                type="button"
                onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}
              >
                <ChevronRight size={17} />
              </button>
            </div>
          </div>
        )}
      </section>

      {saleDetail ? (
        <SalesRecordDetailModal
          order={saleDetail}
          onClose={() => setSaleDetail(null)}
        />
      ) : null}

      {salesModalOpen ? (
        <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
          <section
            aria-label="Record sale"
            aria-modal="true"
            className={`${styles.modal} ${styles.salesModal}`}
            role="dialog"
          >
            <header className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>
                <span className={styles.modalTitleIcon} aria-hidden="true">
                  <Receipt size={18} />
                </span>
                Record Sale
              </h3>
              <button
                aria-label="Close modal"
                className={styles.modalCloseButton}
                type="button"
                onClick={() => setSalesModalOpen(false)}
              >
                <X size={18} />
              </button>
            </header>
            <SalesOrderForm
              discounts={discounts}
              items={items}
              notify={notify}
              onRecorded={closeSalesModal}
            />
          </section>
        </div>
      ) : null}

      {confirmationDialog}
    </>
  );
}

function SalesRecordDetailModal({
  order,
  onClose,
}: {
  order: RecentSalesOrder;
  onClose: () => void;
}) {
  const showTransactionReference =
    order.paymentMethod !== "Cash" && Boolean(order.transactionReference);
  const isMarket = order.source === "market";
  const items =
    isMarket
      ? [
          {
            id: order.id,
            itemName: order.marketItemName ?? "Market distribution item",
            unit: order.marketItemUnit ?? "unit",
            quantitySold: order.marketQuantitySold ?? 1,
            unitPrice: order.marketUnitPrice ?? order.totalAmount,
            lineTotal: order.totalAmount,
          },
        ]
      : (order.receiptItems ?? []);

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
      <section
        aria-label="Sales record details"
        aria-modal="true"
        className={`${styles.modal} ${styles.marketDetailModal}`}
        role="dialog"
      >
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {isMarket ? <Package size={18} /> : <Receipt size={18} />}
            </span>
            {isMarket ? "Market Distribution Details" : "Receipt Sale Details"}
          </h3>
          <button
            aria-label="Close modal"
            className={styles.modalCloseButton}
            type="button"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </header>

        <div className={styles.marketDetailHero}>
          <div>
            <span>Reference</span>
            <strong>{order.receiptNumber}</strong>
          </div>
          <span className={styles.statusPill} data-status={order.status.toLowerCase()}>
            {order.status}
          </span>
        </div>

        <div className={styles.marketDetailGrid}>
          <ReadOnlyDetail label="Date/time" value={formatDateTime(order.saleDate)} />
          <ReadOnlyDetail label="Customer" value={order.customerName} />
          {order.customerContact ? (
            <ReadOnlyDetail label="Contact" value={order.customerContact} />
          ) : null}
          <ReadOnlyDetail label="Payment method" value={order.paymentMethod} />
          {showTransactionReference ? (
            <ReadOnlyDetail
              icon={<Hash size={16} />}
              label="Transaction ID"
              value={order.transactionReference ?? "Not recorded"}
            />
          ) : null}
        </div>

        <section className={styles.marketItemsPanel}>
          <div className={styles.marketItemsHead}>
            <span>Item bought</span>
            <span>Qty</span>
            <span>Unit price (PHP)</span>
            <span>Total (PHP)</span>
          </div>
          {items.length > 0 ? (
            items.map((item) => (
              <div className={styles.marketItemsRow} key={item.id}>
                <strong>{item.itemName}</strong>
                <span>{formatQuantity(item.quantitySold, item.unit)}</span>
                <span>{formatCurrency(item.unitPrice)}</span>
                <strong>{formatCurrency(item.lineTotal)}</strong>
              </div>
            ))
          ) : (
            <div className={styles.marketItemsRow}>
              <strong>Receipt items</strong>
              <span>{order.itemCount ?? 0} items</span>
              <span>Not shown</span>
              <strong>{formatCurrency(order.totalAmount)}</strong>
            </div>
          )}
        </section>

        {order.marketRemarks ? (
          <section className={styles.marketRemarks}>
            <span>Remarks</span>
            <p>{order.marketRemarks}</p>
          </section>
        ) : null}
      </section>
    </div>
  );
}

function ReadOnlyDetail({
  icon,
  label,
  value,
}: {
  icon?: ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className={styles.readOnlyDetail}>
      <span>
        {icon}
        {label}
      </span>
      <strong>{value}</strong>
    </div>
  );
}
