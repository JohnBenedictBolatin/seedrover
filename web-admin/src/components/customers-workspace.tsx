"use client";

import { type FormEvent, type ReactNode, useEffect, useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  BadgePercent,
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Eye,
  FileDown,
  Filter,
  NotebookPen,
  Printer,
  Receipt,
  Search,
  Tag,
  Users,
  WalletCards,
  X,
} from "lucide-react";
import {
  createCustomerDiscountAction,
  saveCustomerProfileAction,
} from "@/app/(portal)/customers/actions";
import {
  ActionAlertStack,
  type ActionAlert,
  type AlertTone,
} from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { ReportPrintButton } from "@/components/report-print-button";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import type { CustomerDiscount, CustomerStats, CustomerSummary } from "@/lib/customers";
import { CountUpValue } from "@/components/count-up-value";
import styles from "@/app/(portal)/customers/page.module.css";

type CustomersWorkspaceProps = {
  customers: CustomerSummary[];
  discounts: CustomerDiscount[];
  stats: CustomerStats | null;
};

const CUSTOMER_ROWS_PER_PAGE = 8;
const customerTypes = ["Farm Buyer", "Market Buyer", "Wholesale", "Restaurant", "Retail", "Other"];
const tagOptions = ["Market Buyer", "Repeat Buyer", "Walk-in", "Wholesale", "Priority"];

function todayInputValue(offsetDays = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function matchesDateRange(customer: CustomerSummary, start: string, end: string) {
  const time = new Date(customer.lastPurchaseAt).getTime();
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
      className={styles.themedSelect}
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

function FormSelect({
  disabled = false,
  label,
  name,
  onChange,
  options,
  value,
}: {
  disabled?: boolean;
  label: string;
  name: string;
  onChange: (value: string) => void;
  options: string[];
  value: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <label className={styles.formSelectLabel}>
      {label}
      <input name={name} type="hidden" value={disabled ? "" : value} />
      <div
        className={`${styles.themedSelect} ${styles.themedSelectForm}`}
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
            setOpen(false);
          }
        }}
      >
        <button
          aria-expanded={open}
          className={styles.themedSelectButton}
          disabled={disabled}
          type="button"
          onClick={() => setOpen((current) => !current)}
        >
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
    </label>
  );
}

export function CustomersWorkspace({ customers, discounts, stats }: CustomersWorkspaceProps) {
  const [query, setQuery] = useState("");
  const [customerFilter, setCustomerFilter] = useState("All");
  const [paymentFilter, setPaymentFilter] = useState("All");
  const [sortBy, setSortBy] = useState("Total spent");
  const [startDate, setStartDate] = useState(todayInputValue(-90));
  const [endDate, setEndDate] = useState(todayInputValue());
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerSummary | null>(null);
  const [discountModalOpen, setDiscountModalOpen] = useState(false);
  const [discountListOpen, setDiscountListOpen] = useState(false);
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);

  function notify(tone: AlertTone, text: string) {
    const id = Date.now();
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => {
      setAlerts((current) => current.filter((alert) => alert.id !== id));
    }, 4200);
  }

  const paymentOptions = [
    "All",
    ...new Set(customers.flatMap((customer) => customer.paymentMethods)),
  ];

  const filteredCustomers = useMemo(() => {
    const normalized = query.trim().toLowerCase();

    return customers
      .filter((customer) => {
        const haystack = [
          customer.name,
          customer.contact,
          customer.alternateContact,
          customer.location,
          customer.customerType,
          customer.paymentMethods.join(" "),
          customer.tags.join(" "),
          customer.purchasedItems.map((item) => item.itemName).join(" "),
        ]
          .join(" ")
          .toLowerCase();

        const repeatMatch =
          customerFilter === "All" ||
          (customerFilter === "Repeat" && customer.receiptCount > 1) ||
          (customerFilter === "New" && customer.receiptCount <= 1);

        return (
          (!normalized || haystack.includes(normalized)) &&
          repeatMatch &&
          (paymentFilter === "All" || customer.paymentMethods.includes(paymentFilter)) &&
          matchesDateRange(customer, startDate, endDate)
        );
      })
      .sort((left, right) => {
        if (sortBy === "Latest purchase") {
          return new Date(right.lastPurchaseAt).getTime() - new Date(left.lastPurchaseAt).getTime();
        }

        if (sortBy === "Receipt count") {
          return right.receiptCount - left.receiptCount;
        }

        if (sortBy === "Name") {
          return left.name.localeCompare(right.name);
        }

        return right.totalSpent - left.totalSpent;
      });
  }, [customerFilter, customers, endDate, paymentFilter, query, sortBy, startDate]);

  useEffect(() => {
    setCurrentPage(1);
  }, [customerFilter, endDate, paymentFilter, query, sortBy, startDate]);

  const totalPages = Math.max(1, Math.ceil(filteredCustomers.length / CUSTOMER_ROWS_PER_PAGE));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const paginatedCustomers = filteredCustomers.slice(
    (safeCurrentPage - 1) * CUSTOMER_ROWS_PER_PAGE,
    safeCurrentPage * CUSTOMER_ROWS_PER_PAGE,
  );
  const pageNumbers = Array.from({ length: totalPages }, (_, index) => index + 1);

  return (
    <>
      <section className={styles.metricGrid} aria-label="Customer summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Users size={20} />
            </span>
            <p>Total customers</p>
          </div>
          <CountUpValue className="mono" value={stats?.totalCustomers ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Receipt size={20} />
            </span>
            <p>Repeat customers</p>
          </div>
          <CountUpValue className="mono" value={stats?.repeatCustomers ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <WalletCards size={20} />
            </span>
            <p>Average spend</p>
          </div>
          <CountUpValue className="mono" currency value={stats?.averageSpendPerCustomer ?? 0} />
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Tag size={20} />
            </span>
            <p>Top customer</p>
          </div>
          <strong>{stats?.topCustomer ?? "None yet"}</strong>
        </article>
      </section>

      <section className={styles.quickActions}>
        <div>
          <p className={styles.eyebrow}>Quick action</p>
          <h2>Create a customer discount</h2>
          <span>Open the discount form only when you need to prepare a buyer offer.</span>
        </div>
        <div className={styles.quickActionButtons}>
          <button
            className={styles.recordSaleButton}
            type="button"
            onClick={() => setDiscountModalOpen(true)}
          >
            <span className={styles.recordSaleText}>Create Discount</span>
            <span className={styles.recordSaleIcon} aria-hidden="true">
              <BadgePercent size={22} />
            </span>
          </button>
          <button
            className={styles.recordSaleButton}
            type="button"
            onClick={() => setDiscountListOpen(true)}
          >
            <span className={styles.recordSaleText}>Discount List</span>
            <span className={styles.recordSaleIcon} aria-hidden="true">
              <Receipt size={22} />
            </span>
          </button>
        </div>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Customer list</p>
            <h2>Farm buyer records</h2>
          </div>
          <div className={styles.exportActions}>
            <Link href="/api/exports/customers.csv">
              <FileDown size={17} />
              CSV
            </Link>
            <Link href="/api/exports/customers.xls">
              <FileDown size={17} />
              Excel
            </Link>
            <ReportPrintButton href="/reports/customers/print">
              <Printer size={17} />
              Print / PDF
            </ReportPrintButton>
          </div>
        </div>

        <div className={styles.filters}>
          <label className={styles.searchBox}>
            <Search size={18} />
            <input
              placeholder="Search customer, contact, payment, item..."
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          <label className={styles.dateField}>
            From
            <input
              type="date"
              value={startDate}
              onChange={(event) => setStartDate(event.target.value)}
            />
          </label>
          <label className={styles.dateField}>
            To
            <input
              type="date"
              value={endDate}
              onChange={(event) => setEndDate(event.target.value)}
            />
          </label>
          <FilterSelect
            icon={<Filter size={17} />}
            label="Type"
            options={["All", "Repeat", "New"]}
            value={customerFilter}
            onChange={setCustomerFilter}
          />
          <FilterSelect
            icon={<WalletCards size={17} />}
            label="Payment"
            options={paymentOptions}
            value={paymentFilter}
            onChange={setPaymentFilter}
          />
          <FilterSelect
            icon={<ChevronDown size={17} />}
            label="Sort"
            options={["Total spent", "Latest purchase", "Receipt count", "Name"]}
            value={sortBy}
            onChange={setSortBy}
          />
        </div>

        {filteredCustomers.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No customers found.</strong>
            <span>Try adjusting the filters or record a sale with customer details.</span>
          </div>
        ) : (
          <div className={styles.customerTable}>
            <div className={styles.customerTableHead}>
              <span>Customer</span>
              <span>Contact Details</span>
              <span>Type</span>
              <span>Receipts</span>
              <span>Total spent</span>
              <span>Last purchase</span>
              <span>Payment</span>
              <span>Actions</span>
            </div>
            {paginatedCustomers.map((customer) => (
              <article className={styles.customerRow} key={customer.key}>
                <div className={styles.customerIdentity}>
                  <strong>{customer.name}</strong>
                </div>
                <div className={styles.contactCell}>
                  <strong>{customer.contact}</strong>
                  <span>{customer.alternateContact || "No alternate contact"}</span>
                </div>
                <span className={styles.typeCell}>{customer.customerType}</span>
                <strong className={styles.receiptsCell}>{customer.receiptCount}</strong>
                <strong className={styles.totalCell}>{formatCurrency(customer.totalSpent)}</strong>
                <span className={styles.dateCell}>{formatDateTime(customer.lastPurchaseAt)}</span>
                <span className={styles.paymentCell}>{customer.paymentMethods.join(", ")}</span>
                <div className={styles.tableActions}>
                  <button
                    aria-label={`View ${customer.name}`}
                    type="button"
                    onClick={() => setSelectedCustomer(customer)}
                  >
                    <Eye size={17} />
                  </button>
                </div>
              </article>
            ))}
            <div className={styles.paginationBar} aria-label="Customer pagination">
              <button
                aria-label="Previous customer page"
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
                aria-label="Next customer page"
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

      {selectedCustomer ? (
        <CustomerDetailModal
          customer={selectedCustomer}
          notify={notify}
          onClose={() => setSelectedCustomer(null)}
        />
      ) : null}

      {discountModalOpen ? (
        <CreateDiscountModal
          customers={customers}
          notify={notify}
          onClose={() => setDiscountModalOpen(false)}
        />
      ) : null}

      {discountListOpen ? (
        <DiscountListModal discounts={discounts} onClose={() => setDiscountListOpen(false)} />
      ) : null}

      <ActionAlertStack
        alerts={alerts}
        onDismiss={(id) =>
          setAlerts((current) => current.filter((alert) => alert.id !== id))
        }
      />
    </>
  );
}

function formatDiscountAmount(discount: CustomerDiscount) {
  if (discount.discountType === "Amount") {
    return formatCurrency(discount.discountValue);
  }

  return `${discount.discountValue}%`;
}

function DiscountListModal({
  discounts,
  onClose,
}: {
  discounts: CustomerDiscount[];
  onClose: () => void;
}) {
  return (
    <div className={styles.modalBackdrop} role="presentation">
      <section className={styles.discountListModal} role="dialog" aria-modal="true" aria-label="Discount list">
        <header className={styles.modalHeader}>
          <h3>
            <Receipt size={19} />
            Discount List
          </h3>
          <button aria-label="Close discount list" type="button" onClick={onClose}>
            <X size={18} />
          </button>
        </header>

        {discounts.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No discounts released yet.</strong>
            <span>Create and release a discount to see its code and redemption status here.</span>
          </div>
        ) : (
          <div className={styles.discountListTable}>
            <div className={styles.discountListHead}>
              <span>Code</span>
              <span>Name</span>
              <span>Amount</span>
              <span>Date redeemed</span>
              <span>Status</span>
            </div>
            {discounts.map((discount) => {
              const redeemed = discount.status === "Used";

              return (
                <article className={styles.discountListRow} key={discount.id}>
                  <strong>{discount.code}</strong>
                  <span>{discount.customerName}</span>
                  <span>{formatDiscountAmount(discount)}</span>
                  <span>{discount.usedAt ? formatDateTime(discount.usedAt) : "Not redeemed"}</span>
                  <small data-status={redeemed ? "redeemed" : "available"}>
                    {redeemed ? "Redeemed" : "Not redeemed"}
                  </small>
                </article>
              );
            })}
          </div>
        )}

        <div className={styles.discountActions}>
          <button className={styles.secondaryButton} type="button" onClick={onClose}>
            <span>Close</span>
          </button>
        </div>
      </section>
    </div>
  );
}

function CreateDiscountModal({
  customers,
  notify,
  onClose,
}: {
  customers: CustomerSummary[];
  notify: (tone: AlertTone, text: string) => void;
  onClose: () => void;
}) {
  const customerOptions = customers.map((customer) => customer.name);
  const [customerName, setCustomerName] = useState(customerOptions[0] ?? "No customers yet");
  const [discountType, setDiscountType] = useState("Percent");
  const [discountValue, setDiscountValue] = useState("0");
  const [validUntil, setValidUntil] = useState("");
  const [notes, setNotes] = useState("");
  const [coupon, setCoupon] = useState<{
    customerName: string;
    discountType: string;
    discountValue: string;
    validUntil: string;
    notes: string;
    code: string;
  } | null>(null);
  const [releasedCode, setReleasedCode] = useState("");
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const hasCustomers = customers.length > 0;
  const selectedCustomer = customers.find((customer) => customer.name === customerName);

  function handleCreateDiscount() {
    if (!hasCustomers) {
      return;
    }

    setCoupon({
      customerName,
      discountType,
      discountValue: discountValue.trim() || "0",
      validUntil,
      notes: notes.trim(),
      code: `SR-${Date.now().toString(36).toUpperCase().slice(-6)}`,
    });
    setReleasedCode("");
  }

  async function handleReleaseDiscount() {
    if (!coupon || !selectedCustomer) {
      return;
    }

    const confirmed = await confirm({
      message: `Are you sure you want to release discount ${coupon.code} to ${coupon.customerName}?`,
      confirmLabel: "Release Discount",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData();
    formData.set("customer_name", coupon.customerName);
    formData.set("customer_contact", selectedCustomer.contact);
    formData.set("discount_code", coupon.code);
    formData.set("discount_type", coupon.discountType);
    formData.set("discount_value", coupon.discountValue);
    formData.set("valid_until", coupon.validUntil);
    formData.set("notes", coupon.notes);

    startTransition(async () => {
      try {
        const result = await createCustomerDiscountAction(formData);
        setReleasedCode(result.code);
        onClose();
        router.refresh();
        notify("success", `Success - Discount ${result.code} released.`);
      } catch (error) {
        notify(
          "error",
          `Error - ${error instanceof Error ? error.message : "Unable to release discount."}`,
        );
      }
    });
  }

  return (
    <div className={styles.modalBackdrop} role="presentation">
      {!coupon ? (
        <section className={styles.discountModal} role="dialog" aria-modal="true" aria-label="Create discount">
          <header className={styles.modalHeader}>
            <h3>
              <BadgePercent size={19} />
              Create Discount
            </h3>
            <button aria-label="Close modal" type="button" onClick={onClose}>
              <X size={18} />
            </button>
          </header>

          <form className={styles.discountForm}>
            <FormSelect
              disabled={!hasCustomers}
              label="Customer"
              name="customer_name"
              options={hasCustomers ? customerOptions : ["No customers yet"]}
              value={customerName}
              onChange={setCustomerName}
            />

            <FormSelect
              label="Discount type"
              name="discount_type"
              options={["Percent", "Amount"]}
              value={discountType}
              onChange={setDiscountType}
            />

            <label>
              Value
              <input
                min="0"
                name="discount_value"
                type="number"
                value={discountValue}
                onChange={(event) => setDiscountValue(event.target.value)}
              />
            </label>

            <label>
              Valid until
              <input
                name="valid_until"
                type="date"
                value={validUntil}
                onChange={(event) => setValidUntil(event.target.value)}
              />
            </label>

            <label className={styles.discountNotes}>
              Notes
              <textarea
                name="notes"
                placeholder="Preferred buyer offer, loyalty note, or approval reminder"
                rows={4}
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
              />
            </label>

            <div className={styles.discountActions}>
              <button className={styles.secondaryButton} type="button" onClick={onClose}>
                <span>Close</span>
              </button>
              <button className={styles.primaryButton} disabled={!hasCustomers} type="button" onClick={handleCreateDiscount}>
                <span>Create Discount</span>
              </button>
            </div>
          </form>

        </section>
      ) : null}

      {coupon ? (
        <section className={styles.couponModal} role="dialog" aria-modal="true" aria-label="Discount coupon preview">
          <header className={styles.modalHeader}>
            <h3>
              <BadgePercent size={19} />
              Discount Coupon
            </h3>
            <button aria-label="Close coupon preview" type="button" onClick={() => setCoupon(null)}>
              <X size={18} />
            </button>
          </header>
          <DiscountCoupon coupon={coupon} />
          <div className={styles.discountActions}>
            <button className={styles.secondaryButton} type="button" onClick={() => setCoupon(null)}>
              <span>Cancel</span>
            </button>
            <button
              className={styles.primaryButton}
              disabled={pending || releasedCode === coupon.code}
              type="button"
              onClick={handleReleaseDiscount}
            >
              <span>{releasedCode === coupon.code ? "Released" : pending ? "Releasing..." : "Release discount"}</span>
            </button>
          </div>
        </section>
      ) : null}
      {confirmationDialog}
    </div>
  );
}

function DiscountCoupon({
  coupon,
}: {
  coupon: {
    customerName: string;
    discountType: string;
    discountValue: string;
    validUntil: string;
    notes: string;
    code: string;
  };
}) {
  const discountLabel =
    coupon.discountType === "Amount"
      ? `PHP ${Number(coupon.discountValue || 0).toLocaleString("en-US")}`
      : `${coupon.discountValue || 0}%`;
  const validLabel = coupon.validUntil
    ? new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      }).format(new Date(`${coupon.validUntil}T00:00:00`))
    : "No expiry set";

  return (
    <div className={styles.couponCanvas} aria-live="polite">
      <div className={styles.couponWrapper}>
        <article className={styles.couponTicket}>
          <div className={styles.couponMain}>
            <div className={styles.couponContent}>
              <div className={styles.couponHeader}>
                <div className={styles.couponLogo}>
                  <BadgePercent size={18} />
                  SeedRover
                </div>
                <div className={styles.couponType}>Discount</div>
              </div>

              <div className={styles.couponTitle}>{discountLabel}</div>
              <div className={styles.couponSubtitle}>Customer buyer offer</div>

              <div className={styles.couponDetails}>
                <div>
                  <span>Customer</span>
                  <strong>{coupon.customerName}</strong>
                </div>
                <div>
                  <span>Valid until</span>
                  <strong>{validLabel}</strong>
                </div>
                <div>
                  <span>Notes</span>
                  <strong>{coupon.notes || "Internal tracking"}</strong>
                </div>
              </div>
            </div>
            <div className={styles.couponPerforation}>
              <span />
            </div>
          </div>

          <div className={styles.couponStub}>
            <div>
              <div className={styles.couponBarcode} />
              <p>{coupon.code}</p>
            </div>
            <div className={styles.couponValue}>
              <span>Value</span>
              <strong>{discountLabel}</strong>
            </div>
          </div>
        </article>
      </div>
    </div>
  );
}

function CustomerDetailModal({
  customer,
  notify,
  onClose,
}: {
  customer: CustomerSummary;
  notify: (tone: AlertTone, text: string) => void;
  onClose: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const [customerType, setCustomerType] = useState(customer.customerType);
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const confirmed = await confirm({
      message: `Are you sure you want to save the profile for ${customer.name}?`,
      confirmLabel: "Save Profile",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      try {
        await saveCustomerProfileAction(formData);
        router.refresh();
        notify("success", "Success - Customer profile saved.");
      } catch (error) {
        notify(
          "error",
          `Error - ${error instanceof Error ? error.message : "Unable to save profile."}`,
        );
      }
    });
  }

  return (
    <div className={styles.modalBackdrop} role="presentation">
      <section className={styles.modal} role="dialog" aria-modal="true" aria-label="Customer details">
        <header className={styles.modalHeader}>
          <h3>
            <NotebookPen size={19} />
            Customer Details
          </h3>
          <button aria-label="Close modal" type="button" onClick={onClose}>
            <X size={18} />
          </button>
        </header>

        <div className={styles.detailGrid}>
          <div className={styles.profilePanel}>
            <div className={styles.customerHero}>
              <div>
                <p>{customer.customerType}</p>
                <h2>{customer.name}</h2>
                <span>{customer.contact}</span>
              </div>
              <strong>{formatCurrency(customer.totalSpent)}</strong>
            </div>
            <div className={styles.detailStats}>
              <div>
                <span>Receipts</span>
                <strong>{customer.receiptCount}</strong>
              </div>
              <div>
                <span>Average spend</span>
                <strong>{formatCurrency(customer.averageSpend)}</strong>
              </div>
              <div>
                <span>Last purchase</span>
                <strong>{formatDateTime(customer.lastPurchaseAt)}</strong>
              </div>
            </div>

            <form className={styles.profileForm} onSubmit={handleSubmit}>
              <input name="display_name" type="hidden" value={customer.name} />
              <input name="contact_number" type="hidden" value={customer.contact} />
              <FormSelect
                label="Customer type"
                name="customer_type"
                options={customerTypes}
                value={customerType}
                onChange={setCustomerType}
              />
              <label>
                Location
                <input name="location" defaultValue={customer.location} placeholder="Market, barangay, or delivery area" />
              </label>
              <label>
                Alternate contact
                <input name="alternate_contact" defaultValue={customer.alternateContact} placeholder="Optional" />
              </label>
              <label>
                Tags
                <input
                  name="tags"
                  defaultValue={customer.tags.join(", ")}
                  placeholder={tagOptions.join(", ")}
                />
              </label>
              <label>
                Internal notes
                <textarea
                  name="notes"
                  defaultValue={customer.notes}
                  placeholder="Preferences, delivery notes, or manager observations"
                  rows={4}
                />
              </label>
              <button disabled={pending} type="submit">
                <NotebookPen size={17} />
                <span>{pending ? "Saving..." : "Save Profile"}</span>
              </button>
            </form>
          </div>

          <div className={styles.historyPanel}>
            <section>
              <h4>Purchased Items</h4>
              <div className={styles.compactList}>
                {customer.purchasedItems.slice(0, 6).map((item) => (
                  <div key={item.itemName}>
                    <strong>{item.itemName}</strong>
                    <span>{formatQuantity(item.quantity, "units")}</span>
                    <small>{formatCurrency(item.totalAmount)}</small>
                  </div>
                ))}
              </div>
            </section>

            <section>
              <h4>Purchase History</h4>
              <div className={styles.receiptList}>
                {customer.receipts.map((receipt) => (
                  <div key={`${receipt.source}-${receipt.id}`}>
                    <div>
                      <strong>{receipt.receiptNumber}</strong>
                      <span>{formatDateTime(receipt.saleDate)}</span>
                    </div>
                    <div>
                      <small>{receipt.paymentMethod}</small>
                      <strong>{formatCurrency(receipt.totalAmount)}</strong>
                      {receipt.source === "receipt" ? (
                        <Link href={`/sales/${receipt.id}`} aria-label="View receipt">
                          <Eye size={16} />
                        </Link>
                      ) : null}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        </div>
      </section>
      {confirmationDialog}
    </div>
  );
}
