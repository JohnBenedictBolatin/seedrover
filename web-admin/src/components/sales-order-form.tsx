"use client";

import { FormEvent, useActionState, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Check,
  ChevronDown,
  PackageSearch,
  Plus,
  Receipt,
  Trash2,
} from "lucide-react";
import { recordSalesOrderAction, type SalesFormState } from "@/app/(portal)/sales/actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { ContactNumberInput, NumericInput } from "@/components/constrained-inputs";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { PendingActionLabel } from "@/components/pending-action-label";
import { formatCurrency, formatQuantity } from "@/lib/format";
import { isContactNumber } from "@/lib/contact-number.mjs";
import type { ExistingSaleCustomer } from "@/lib/customers";
import type { ReleasedDiscount, SellableItem } from "@/lib/sales";
import styles from "./sales-order-form.module.css";

type LineItem = {
  key: string;
  inventoryId: string;
  quantity: string;
};

const initialState: SalesFormState = {
  message: "",
};

const paymentMethodOptions = ["Cash", "Installment", "GCash", "Bank Transfer", "Card", "Other"];

function newLineItem(items: SellableItem[], excludedIds: string[] = []): LineItem {
  const firstItem = items.find((item) => !excludedIds.includes(item.id));

  return {
    key: crypto.randomUUID(),
    inventoryId: firstItem?.id ?? "",
    quantity: "",
  };
}

function toNumber(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function nextInstallmentDateLabel(frequency: string) {
  const date = new Date();

  if (frequency === "Weekly") date.setDate(date.getDate() + 7);
  if (frequency === "Monthly") date.setMonth(date.getMonth() + 1);
  if (frequency === "Yearly") date.setFullYear(date.getFullYear() + 1);

  return new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function ItemPicker({
  item,
  items,
  excludedIds,
  onChange,
}: {
  item: LineItem;
  items: SellableItem[];
  excludedIds: string[];
  onChange: (inventoryId: string) => void;
}) {
  const selectedItem = items.find((entry) => entry.id === item.inventoryId);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState(selectedItem?.label ?? "");

  useEffect(() => {
    const updateQuery = window.setTimeout(
      () => setQuery(selectedItem?.label ?? ""),
      0,
    );

    return () => window.clearTimeout(updateQuery);
  }, [selectedItem?.label]);

  const filteredItems = items.filter((entry) =>
    (entry.id === item.inventoryId || !excludedIds.includes(entry.id)) &&
    `${entry.label} ${entry.stockCode}`.toLowerCase().includes(query.toLowerCase()),
  );

  return (
    <label className={styles.itemPickerLabel}>
      Item
      <input name="inventory_id" type="hidden" value={item.inventoryId} />
      <div className={styles.itemPicker}>
        <PackageSearch size={18} />
        <input
          placeholder="Search crop or stock code..."
          value={query}
          onBlur={() => window.setTimeout(() => setOpen(false), 120)}
          onChange={(event) => {
            setQuery(event.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
        />
        {open ? (
          <div className={styles.itemPickerMenu}>
            {filteredItems.length === 0 ? (
              <span>No matching available stock.</span>
            ) : (
              filteredItems.map((entry) => (
                <button
                  key={entry.id}
                  type="button"
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => {
                    onChange(entry.id);
                    setQuery(entry.label);
                    setOpen(false);
                  }}
                >
                  <strong>{entry.label}</strong>
                  <small>
                    {entry.stockCode} · {formatQuantity(entry.quantity, entry.unit)}
                  </small>
                </button>
              ))
            )}
          </div>
        ) : null}
      </div>
    </label>
  );
}

function ThemedSelect({
  emptyLabel,
  label,
  name,
  onChange,
  optionLabels,
  options,
  required = false,
  value,
}: {
  emptyLabel?: string;
  label: string;
  name: string;
  onChange?: (value: string) => void;
  optionLabels?: Record<string, string>;
  options: string[];
  required?: boolean;
  value: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <label className={styles.themedSelectLabel}>
      <span className={styles.themedSelectText}>
        {label}
        {required ? (
          <>
            <span aria-hidden="true" className={styles.requiredMarker}>*</span>
            <span className={styles.visuallyHidden}> (required)</span>
          </>
        ) : null}
      </span>
      <input name={name} type="hidden" value={value} />
      <div
        className={styles.themedSelect}
        onBlur={() => window.setTimeout(() => setOpen(false), 100)}
      >
        <button
          className={styles.themedSelectButton}
          type="button"
          onClick={() => setOpen((current) => !current)}
        >
          <span>{value ? optionLabels?.[value] ?? value : emptyLabel ?? "Choose an option"}</span>
          <ChevronDown size={17} />
        </button>
        {open ? (
          <div className={styles.themedSelectMenu}>
            {options.map((option) => (
              <button
                key={option}
                className={styles.themedSelectOption}
                data-selected={option === value}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onChange?.(option);
                  setOpen(false);
                }}
              >
                <span>{optionLabels?.[option] ?? option}</span>
                {option === value ? <Check size={15} /> : null}
              </button>
            ))}
          </div>
        ) : null}
      </div>
    </label>
  );
}

export function SalesOrderForm({
  customers,
  discounts,
  items,
  notify,
  onRecorded,
}: {
  customers: ExistingSaleCustomer[];
  discounts: ReleasedDiscount[];
  items: SellableItem[];
  notify?: (tone: AlertTone, text: string) => void;
  onRecorded?: () => void;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const confirmedRef = useRef(false);
  const router = useRouter();
  const [state, formAction, pending] = useActionState(
    recordSalesOrderAction,
    initialState,
  );
  const [lineItems, setLineItems] = useState<LineItem[]>(() => [newLineItem(items)]);
  const [discountCode, setDiscountCode] = useState("");
  const [amountPaid, setAmountPaid] = useState("");
  const [paymentMethod, setPaymentMethod] = useState("Cash");
  const [otherPaymentMethod, setOtherPaymentMethod] = useState("");
  const [transactionReference, setTransactionReference] = useState("");
  const [installmentFrequency, setInstallmentFrequency] = useState("Monthly");
  const [installmentCount, setInstallmentCount] = useState("12");
  const [initialPaymentMethod, setInitialPaymentMethod] = useState("Cash");
  const [initialPaymentReference, setInitialPaymentReference] = useState("");
  const [customerMode, setCustomerMode] = useState<"new" | "existing">("new");
  const [selectedCustomerKey, setSelectedCustomerKey] = useState("");
  const { confirm, confirmationDialog } = useConfirmationDialog();

  const itemById = useMemo(
    () => new Map(items.map((item) => [item.id, item])),
    [items],
  );
  const selectableCustomers = useMemo(
    () => customers.filter((customer) => isContactNumber(customer.contact)),
    [customers],
  );
  const selectedCustomer = selectableCustomers.find(
    (customer) => customer.key === selectedCustomerKey,
  );

  const subtotal = lineItems.reduce(
    (total, item) =>
      total +
      toNumber(item.quantity) * (itemById.get(item.inventoryId)?.sellingPrice ?? 0),
    0,
  );
  const normalizedDiscountCode = discountCode.trim().toUpperCase();
  const selectedDiscount = discounts.find(
    (discount) => discount.code.toUpperCase() === normalizedDiscountCode,
  );
  const discountAmount = selectedDiscount
    ? selectedDiscount.discountType === "Amount"
      ? Math.min(selectedDiscount.discountValue, subtotal)
      : subtotal * Math.min(selectedDiscount.discountValue, 100) / 100
    : 0;
  const total = Math.max(subtotal - discountAmount, 0);
  const paid = toNumber(amountPaid);
  const change = amountPaid.trim() ? Math.max(paid - total, 0) : 0;
  const remainingBalance = Math.max(total - paid, 0);
  const installmentCountNumber = Number(installmentCount);
  const installmentPayment = installmentCountNumber > 0
    ? Math.round((total / installmentCountNumber) * 100) / 100
    : 0;
  const installmentAmount = installmentPayment.toFixed(2);

  useEffect(() => {
    confirmedRef.current = false;

    if (!state.message) return;

    if (state.receiptId && state.receiptNumber) {
      notify?.("success", `Receipt ${state.receiptNumber} recorded.`);
      onRecorded?.();
      router.refresh();
      return;
    }

    notify?.("error", state.message);
  }, [notify, onRecorded, router, state]);

  function updateLineItem(key: string, patch: Partial<LineItem>) {
    setLineItems((current) =>
      current.map((item) => {
        if (item.key !== key) {
          return item;
        }

        const next = { ...item, ...patch };

        return next;
      }),
    );
  }

  function addLineItem() {
    setLineItems((current) => [
      ...current,
      newLineItem(items, current.map((item) => item.inventoryId).filter(Boolean)),
    ]);
  }

  function removeLineItem(key: string) {
    setLineItems((current) =>
      current.length === 1 ? current : current.filter((item) => item.key !== key),
    );
  }

  function validateTransaction() {
    if (customerMode === "existing" && !selectedCustomer) {
      return "Select an existing customer for this receipt.";
    }

    if (lineItems.length === 0) {
      return "Add at least one item.";
    }

    for (const [index, lineItem] of lineItems.entries()) {
      const selectedItem = itemById.get(lineItem.inventoryId);
      const quantity = toNumber(lineItem.quantity);

      if (!selectedItem) {
        return `Choose an item for line ${index + 1}.`;
      }

      if (quantity <= 0) {
        return `Enter a valid quantity for ${selectedItem.label}.`;
      }

      if (quantity > selectedItem.quantity) {
        return `${selectedItem.label} only has ${formatQuantity(selectedItem.quantity, selectedItem.unit)} available.`;
      }
    }

    if (paymentMethod !== "Installment" && amountPaid.trim() && paid < total) {
      return "Amount paid cannot be lower than the total.";
    }

    if (paymentMethod !== "Cash" && paymentMethod !== "Installment" && amountPaid.trim() && paid > total) {
      return "Non-cash payment cannot exceed the sale total.";
    }

    if (paymentMethod === "Installment" && !amountPaid.trim()) {
      return "Enter the initial payment amount, or enter 0 if none is collected.";
    }

    if (paymentMethod === "Installment" && remainingBalance <= 0) {
      return "An installment sale must have a remaining balance.";
    }

    if (paymentMethod === "Installment" && (!Number.isInteger(installmentCountNumber) || installmentCountNumber < 1 || installmentCountNumber > 120)) {
      return "Enter a number of payments between 1 and 120.";
    }

    if (paymentMethod === "Installment" && installmentCountNumber > Math.floor(total * 100)) {
      return "Number of payments is too high for the sale total.";
    }

    if (paymentMethod === "Other" && !otherPaymentMethod.trim()) {
      return "Enter the other payment method used.";
    }

    if (
      paymentMethod === "Installment" &&
      paid > 0 &&
      initialPaymentMethod !== "Cash" &&
      !initialPaymentReference.trim()
    ) {
      return "Enter the transaction ID for the non-cash initial payment.";
    }

    if (
      paymentMethod !== "Cash" &&
      paymentMethod !== "Installment" &&
      !transactionReference.trim()
    ) {
      return "Enter the transaction ID for non-cash payment.";
    }

    if (normalizedDiscountCode && !selectedDiscount) {
      return "Enter a valid released discount code.";
    }

    return "";
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    if (confirmedRef.current) {
      confirmedRef.current = false;
      return;
    }

    event.preventDefault();
    const error = validateTransaction();

    if (error) {
      notify?.("error", error);
      return;
    }

    const approved = await confirm({
      title: "Record this sale?",
      message: "This will create the receipt and deduct the sold quantities from inventory.",
      summary: <strong>Total amount: {formatCurrency(total)}</strong>,
      confirmLabel: "Record sale",
    });
    if (!approved) return;
    confirmedRef.current = true;
    formRef.current?.requestSubmit();
  }

  if (items.length === 0) {
    return (
      <div className={styles.emptyState}>
        <strong>No sellable inventory available.</strong>
        <span>Add stock and selling prices before recording a sale.</span>
      </div>
    );
  }

  return (
    <form ref={formRef} className={styles.form} action={formAction} onSubmit={handleSubmit}>
      <input name="customer_mode" type="hidden" value={customerMode} />
      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <div>
            <p>Receipt items</p>
            <h2>Multi-item transaction</h2>
          </div>
          <button className={`${styles.actionButton} ${styles.addItemButton}`} type="button" onClick={addLineItem}>
            <span className={styles.actionButtonText}>ADD ITEM</span>
            <span className={styles.actionButtonIcon} aria-hidden="true">
              <Plus size={18} />
            </span>
          </button>
        </div>

        <div className={styles.lines}>
          {lineItems.map((lineItem, index) => {
            const selectedItem = itemById.get(lineItem.inventoryId);

            return (
              <div className={styles.lineItem} key={lineItem.key}>
                <ItemPicker
                  item={lineItem}
                  items={items}
                  excludedIds={lineItems.filter((entry) => entry.key !== lineItem.key).map((entry) => entry.inventoryId).filter(Boolean)}
                  onChange={(inventoryId) =>
                    updateLineItem(lineItem.key, {
                      inventoryId,
                    })
                  }
                />

                <input
                  name="unit_price"
                  type="hidden"
                  value={selectedItem?.sellingPrice ?? 0}
                />

                <label>
                  Quantity
                  <NumericInput
                    min="0.01"
                    name="quantity"
                    step="0.01"
                    value={lineItem.quantity}
                    onChange={(event) =>
                      updateLineItem(lineItem.key, { quantity: event.target.value })
                    }
                  />
                </label>

                <div className={styles.lineMeta}>
                  <span>
                    Available: {" "}
                    {selectedItem
                      ? formatQuantity(selectedItem.quantity, selectedItem.unit)
                      : "0 kg"} ({formatCurrency(selectedItem?.sellingPrice ?? 0)}/kg)
                  </span>
                  <strong>
                    {formatCurrency(
                      toNumber(lineItem.quantity) * (selectedItem?.sellingPrice ?? 0),
                    )}
                  </strong>
                </div>

                <button
                  aria-label={`Remove item ${index + 1}`}
                  className={styles.removeButton}
                  type="button"
                  onClick={() => removeLineItem(lineItem.key)}
                >
                  <Trash2 size={17} />
                </button>
              </div>
            );
          })}
        </div>
      </section>

      <section className={styles.twoColumn}>
        <div className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p>Customer and payment</p>
              <h2>Receipt details</h2>
              <span className={styles.panelHint}>
                Select a saved customer to add this receipt to their purchase history, or enter a new buyer.
              </span>
            </div>
          </div>

          <div className={styles.fields}>
            <div className={styles.customerMode} aria-label="Customer type" role="group">
              <button
                aria-pressed={customerMode === "new"}
                className={customerMode === "new" ? styles.customerModeActive : ""}
                type="button"
                onClick={() => setCustomerMode("new")}
              >
                New customer
              </button>
              <button
                aria-pressed={customerMode === "existing"}
                className={customerMode === "existing" ? styles.customerModeActive : ""}
                type="button"
                onClick={() => setCustomerMode("existing")}
              >
                Existing customer
              </button>
            </div>
            {customerMode === "new" ? (
              <>
                <label>First name<input name="customer_first_name" placeholder="e.g. Juan" required type="text" /></label>
                <label>Middle initial<input name="customer_middle_initial" placeholder="e.g. D" maxLength={1} type="text" /></label>
                <label>Last name<input name="customer_last_name" placeholder="e.g. Cruz" required type="text" /></label>
                <label>
                  Customer contact
                  <ContactNumberInput autoComplete="tel-national" name="customer_contact" placeholder="e.g. 09171234567" required />
                </label>
              </>
            ) : (
              <>
                <input name="existing_customer_name" type="hidden" value={selectedCustomer?.name ?? ""} />
                <input name="customer_contact" type="hidden" value={selectedCustomer?.contact ?? ""} />
                <ThemedSelect
                  emptyLabel="Choose a customer"
                  label="Select customer"
                  name="existing_customer_key"
                  optionLabels={Object.fromEntries(selectableCustomers.map((customer) => [customer.key, `${customer.name} · ${customer.contact}`]))}
                  options={selectableCustomers.map((customer) => customer.key)}
                  required
                  value={selectedCustomerKey}
                  onChange={setSelectedCustomerKey}
                />
                {selectableCustomers.length === 0 ? (
                  <p className={styles.customerPickerHint}>
                    No saved customer with a valid contact number is available. Choose New customer to enter receipt details.
                  </p>
                ) : null}
                {selectedCustomer ? (
                  <p className={styles.customerPickerHint}>
                    This receipt will be recorded for {selectedCustomer.name} and included in their customer history.
                  </p>
                ) : null}
              </>
            )}
            <ThemedSelect
              label="Payment method"
              name="payment_method"
              options={paymentMethodOptions}
              required
              value={paymentMethod}
              onChange={(value) => {
                if (value !== paymentMethod) setAmountPaid("");
                setPaymentMethod(value);
                if (value === "Cash" || value === "Installment") {
                  setTransactionReference("");
                }
                if (value !== "Other") {
                  setOtherPaymentMethod("");
                }
              }}
            />
            {paymentMethod === "Other" ? (
              <label>
                Other payment method
                <input
                  name="other_payment_method"
                  placeholder="e.g. Maya, cheque, farm credit"
                  required
                  type="text"
                  value={otherPaymentMethod}
                  onChange={(event) => setOtherPaymentMethod(event.target.value)}
                />
              </label>
            ) : null}
            {paymentMethod !== "Cash" ? (
              paymentMethod !== "Installment" ? (
              <label>
                Transaction ID
                <input
                  name="transaction_reference"
                  placeholder="e.g. TXN-2026-0012"
                  required
                  type="text"
                  value={transactionReference}
                  onChange={(event) => setTransactionReference(event.target.value)}
                />
              </label>
              ) : null
            ) : null}
            {paymentMethod === "Installment" ? (
              <>
                <div className={styles.installmentTermsGrid}>
                  <ThemedSelect
                    label="Payment frequency"
                    name="installment_frequency"
                    options={["Weekly", "Monthly", "Yearly"]}
                    required
                    value={installmentFrequency}
                    onChange={setInstallmentFrequency}
                  />
                  <label>
                    Number of payments
                    <NumericInput
                      max="120"
                      min="1"
                      name="installment_count"
                      required
                      step="1"
                      value={installmentCount}
                      onChange={(event) => setInstallmentCount(event.target.value)}
                    />
                  </label>
                  <label>
                    Amount per payment (PHP)
                    <NumericInput
                      min="0.01"
                      readOnly
                      step="0.01"
                      value={installmentAmount}
                    />
                    <small className={styles.installmentAmountHint}>Auto-calculated from sale total ÷ number of payments.</small>
                  </label>
                </div>
                <div className={styles.installmentInitialGrid}>
                  <ThemedSelect
                    label="Initial payment method"
                    name="initial_payment_method"
                    options={["Cash", "GCash", "Bank Transfer", "Card", "Other"]}
                    required
                    value={initialPaymentMethod}
                    onChange={(value) => {
                      setInitialPaymentMethod(value);
                      if (value === "Cash") setInitialPaymentReference("");
                    }}
                  />
                  <label>
                    Initial payment amount (PHP)
                    <NumericInput
                      min="0"
                      name="amount_paid"
                      placeholder="Enter 0 if none"
                      required
                      step="0.01"
                      value={amountPaid}
                      onChange={(event) => setAmountPaid(event.target.value)}
                    />
                  </label>
                  <p>Recorded to the sale and customer installment progress immediately.</p>
                </div>
                {paid > 0 && initialPaymentMethod !== "Cash" ? (
                  <label>
                    Initial payment transaction ID
                    <input
                      autoComplete="off"
                      name="initial_payment_transaction_reference"
                      placeholder="Enter transaction ID or reference"
                      required
                      value={initialPaymentReference}
                      onChange={(event) => setInitialPaymentReference(event.target.value)}
                    />
                  </label>
                ) : null}
                <div className={styles.installmentDueHint}>
                  <span>Next payment due</span>
                  <strong>{nextInstallmentDateLabel(installmentFrequency)}</strong>
                  <small>Calculated from the transaction date and payment frequency.</small>
                </div>
              </>
            ) : null}
            <label>
              Remarks
              <textarea name="remarks" placeholder="e.g. Customer requested delivery on Friday" rows={4} />
            </label>
          </div>
        </div>

        <div className={`${styles.panel} ${styles.summaryPanel}`}>
          <div className={styles.panelHeader}>
            <div>
              <p>Payment summary</p>
              <h2>Totals</h2>
            </div>
          </div>

          <div className={styles.fields}>
            <label>
              Discount code
              <input
                name="discount_code"
                placeholder="e.g. Save10"
                type="text"
                value={discountCode}
                onChange={(event) => setDiscountCode(event.target.value)}
              />
            </label>
            {normalizedDiscountCode ? (
              <p className={selectedDiscount ? styles.discountCodeHint : styles.discountCodeError}>
                {selectedDiscount
                  ? `${selectedDiscount.discountType}: ${selectedDiscount.discountValue}${selectedDiscount.discountType === "Percent" ? "%" : " PHP"} for ${selectedDiscount.customerName}`
                  : "Code not found or already used."}
              </p>
            ) : null}
            {paymentMethod !== "Installment" ? (
              <label>
                Amount paid (PHP)
                <NumericInput
                  min="0"
                  name="amount_paid"
                  step="0.01"
                  value={amountPaid}
                  onChange={(event) => setAmountPaid(event.target.value)}
                />
              </label>
            ) : null}
          </div>

          <div className={styles.totals}>
            <div>
              <span>Subtotal (PHP)</span>
              <strong>{formatCurrency(subtotal)}</strong>
            </div>
            <div>
              <span>Discount (PHP)</span>
              <strong>{formatCurrency(discountAmount)}</strong>
            </div>
            <div className={styles.grandTotal}>
              <span>Total (PHP)</span>
              <strong>{formatCurrency(total)}</strong>
            </div>
            <div>
              <span>Change (PHP)</span>
              <strong>{formatCurrency(change)}</strong>
            </div>
          </div>

          <button className={styles.submitButton} disabled={pending} type="submit">
            <PendingActionLabel pending={pending} pendingText="Recording sale...">Record sale</PendingActionLabel>
            <span aria-hidden="true">
              <Receipt size={18} />
            </span>
          </button>
          {state.message && !state.receiptId ? (
            <p className={styles.message} data-tone="error" role="alert">
              {state.message}
            </p>
          ) : null}
        </div>
      </section>

      {confirmationDialog}
    </form>
  );
}
