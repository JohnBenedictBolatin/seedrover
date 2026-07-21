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
  X,
} from "lucide-react";
import { recordSalesOrderAction, type SalesFormState } from "@/app/(portal)/sales/actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { formatCurrency, formatQuantity } from "@/lib/format";
import type { ReleasedDiscount, SellableItem } from "@/lib/sales";
import styles from "./sales-order-form.module.css";

type LineItem = {
  key: string;
  inventoryId: string;
  quantity: string;
  unitPrice: string;
};

const initialState: SalesFormState = {
  message: "",
};

function newLineItem(items: SellableItem[]): LineItem {
  const firstItem = items[0];

  return {
    key: crypto.randomUUID(),
    inventoryId: firstItem?.id ?? "",
    quantity: "",
    unitPrice: firstItem ? String(firstItem.sellingPrice) : "0",
  };
}

function toNumber(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function ItemPicker({
  item,
  items,
  onChange,
}: {
  item: LineItem;
  items: SellableItem[];
  onChange: (inventoryId: string) => void;
}) {
  const selectedItem = items.find((entry) => entry.id === item.inventoryId);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState(selectedItem?.label ?? "");

  useEffect(() => {
    setQuery(selectedItem?.label ?? "");
  }, [selectedItem?.label]);

  const filteredItems = items.filter((entry) =>
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
              <span>No matching stock.</span>
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
  label,
  name,
  onChange,
  options,
  value,
}: {
  label: string;
  name: string;
  onChange?: (value: string) => void;
  options: string[];
  value: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <label className={styles.themedSelectLabel}>
      {label}
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
          <span>{value}</span>
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

export function SalesOrderForm({
  discounts,
  items,
  notify,
  onRecorded,
}: {
  discounts: ReleasedDiscount[];
  items: SellableItem[];
  notify?: (tone: AlertTone, text: string) => void;
  onRecorded?: () => void;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const confirmedRef = useRef(false);
  const lastMessageRef = useRef("");
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
  const [showConfirm, setShowConfirm] = useState(false);

  const itemById = useMemo(
    () => new Map(items.map((item) => [item.id, item])),
    [items],
  );

  const subtotal = lineItems.reduce(
    (total, item) => total + toNumber(item.quantity) * toNumber(item.unitPrice),
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

  useEffect(() => {
    confirmedRef.current = false;

    if (!state.message || state.message === lastMessageRef.current) {
      return;
    }

    lastMessageRef.current = state.message;

    if (state.receiptId && state.receiptNumber) {
      notify?.("success", `Success - Receipt ${state.receiptNumber} recorded.`);
      onRecorded?.();
      router.refresh();
      return;
    }

    notify?.("error", `Error - ${state.message}`);
  }, [notify, onRecorded, router, state.message, state.receiptId, state.receiptNumber]);

  function updateLineItem(key: string, patch: Partial<LineItem>) {
    setLineItems((current) =>
      current.map((item) => {
        if (item.key !== key) {
          return item;
        }

        const next = { ...item, ...patch };

        if (patch.inventoryId) {
          const selectedItem = itemById.get(patch.inventoryId);
          next.unitPrice = String(selectedItem?.sellingPrice ?? 0);
        }

        return next;
      }),
    );
  }

  function addLineItem() {
    setLineItems((current) => [...current, newLineItem(items)]);
  }

  function removeLineItem(key: string) {
    setLineItems((current) =>
      current.length === 1 ? current : current.filter((item) => item.key !== key),
    );
  }

  function validateTransaction() {
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

    if (amountPaid.trim() && paid < total) {
      return "Amount paid cannot be lower than the total.";
    }

    if (paymentMethod === "Other" && !otherPaymentMethod.trim()) {
      return "Enter the other payment method used.";
    }

    if (paymentMethod !== "Cash" && !transactionReference.trim()) {
      return "Enter the transaction ID for non-cash payment.";
    }

    if (normalizedDiscountCode && !selectedDiscount) {
      return "Enter a valid released discount code.";
    }

    return "";
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    if (confirmedRef.current) {
      confirmedRef.current = false;
      return;
    }

    event.preventDefault();
    const error = validateTransaction();

    if (error) {
      notify?.("error", `Error - ${error}`);
      return;
    }

    setShowConfirm(true);
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
      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <div>
            <p>Receipt items</p>
            <h2>Multi-item transaction</h2>
          </div>
          <button className={`${styles.actionButton} ${styles.addItemButton}`} type="button" onClick={addLineItem}>
            <span className={styles.actionButtonText}>Add item</span>
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
                  onChange={(inventoryId) =>
                    updateLineItem(lineItem.key, {
                      inventoryId,
                    })
                  }
                />

                <label>
                  Quantity
                  <input
                    min="0.01"
                    name="quantity"
                    step="0.01"
                    type="number"
                    value={lineItem.quantity}
                    onChange={(event) =>
                      updateLineItem(lineItem.key, { quantity: event.target.value })
                    }
                  />
                </label>

                <label>
                  Unit price
                  <input
                    min="0"
                    name="unit_price"
                    step="0.01"
                    type="number"
                    value={lineItem.unitPrice}
                    onChange={(event) =>
                      updateLineItem(lineItem.key, { unitPrice: event.target.value })
                    }
                  />
                </label>

                <div className={styles.lineMeta}>
                  <span>
                    Available:{" "}
                    {selectedItem
                      ? formatQuantity(selectedItem.quantity, selectedItem.unit)
                      : "0"}
                  </span>
                  <strong>{formatCurrency(toNumber(lineItem.quantity) * toNumber(lineItem.unitPrice))}</strong>
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
            </div>
          </div>

          <div className={styles.fields}>
            <label>
              Customer name
              <input name="customer_name" placeholder="Walk-in customer" type="text" />
            </label>
            <label>
              Customer contact
              <input name="customer_contact" placeholder="Optional" type="text" />
            </label>
            <ThemedSelect
              label="Payment method"
              name="payment_method"
              options={["Cash", "GCash", "Bank Transfer", "Card", "Other"]}
              value={paymentMethod}
              onChange={(value) => {
                setPaymentMethod(value);
                if (value === "Cash") {
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
              <label>
                Transaction ID
                <input
                  name="transaction_reference"
                  placeholder="Enter transaction/reference number"
                  required
                  type="text"
                  value={transactionReference}
                  onChange={(event) => setTransactionReference(event.target.value)}
                />
              </label>
            ) : null}
            <label>
              Remarks
              <textarea name="remarks" placeholder="Optional note" rows={4} />
            </label>
          </div>
        </div>

        <div className={styles.panel}>
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
                placeholder="Enter released code"
                type="text"
                value={discountCode}
                onChange={(event) => setDiscountCode(event.target.value.toUpperCase())}
              />
            </label>
            {normalizedDiscountCode ? (
              <p className={selectedDiscount ? styles.discountCodeHint : styles.discountCodeError}>
                {selectedDiscount
                  ? `${selectedDiscount.discountType}: ${selectedDiscount.discountValue}${selectedDiscount.discountType === "Percent" ? "%" : " PHP"} for ${selectedDiscount.customerName}`
                  : "Code not found or already used."}
              </p>
            ) : null}
            <label>
              Amount paid
              <input
                min="0"
                name="amount_paid"
                step="0.01"
                type="number"
                value={amountPaid}
                onChange={(event) => setAmountPaid(event.target.value)}
              />
            </label>
          </div>

          <div className={styles.totals}>
            <div>
              <span>Subtotal</span>
              <strong>{formatCurrency(subtotal)}</strong>
            </div>
            <div>
              <span>Discount</span>
              <strong>{formatCurrency(discountAmount)}</strong>
            </div>
            <div className={styles.grandTotal}>
              <span>Total</span>
              <strong>{formatCurrency(total)}</strong>
            </div>
            <div>
              <span>Change</span>
              <strong>{formatCurrency(change)}</strong>
            </div>
          </div>

          <button className={styles.submitButton} disabled={pending} type="submit">
            <span>{pending ? "Recording sale..." : "Record sale"}</span>
            <span aria-hidden="true">
              <Receipt size={18} />
            </span>
          </button>
        </div>
      </section>

      {showConfirm ? (
        <div className={styles.confirmBackdrop} role="presentation">
          <div className={styles.confirmModal} role="dialog" aria-modal="true">
            <button
              aria-label="Close confirmation"
              className={styles.confirmClose}
              type="button"
              onClick={() => setShowConfirm(false)}
            >
              <X size={20} />
            </button>
            <div className={styles.confirmIcon}>
              <ReceiptIcon />
            </div>
            <h2>Record this sale?</h2>
            <p>
              This will create the receipt and deduct the sold quantities from inventory.
            </p>
            <div className={styles.confirmTotals}>
              <span>Total amount</span>
              <strong>{formatCurrency(total)}</strong>
            </div>
            <div className={styles.confirmActions}>
              <button type="button" onClick={() => setShowConfirm(false)}>
                <span>Review</span>
              </button>
              <button
                type="button"
                onClick={() => {
                  confirmedRef.current = true;
                  setShowConfirm(false);
                  formRef.current?.requestSubmit();
                }}
              >
                <span>Confirm sale</span>
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </form>
  );
}

function ReceiptIcon() {
  return (
    <svg aria-hidden="true" fill="none" height="24" viewBox="0 0 24 24" width="24">
      <path
        d="M6 3h12v18l-2.4-1.3L13.2 21 12 19.7 10.8 21l-2.4-1.3L6 21V3Z"
        stroke="currentColor"
        strokeLinejoin="round"
        strokeWidth="2"
      />
      <path d="M9 8h6M9 12h6M9 16h4" stroke="currentColor" strokeLinecap="round" strokeWidth="2" />
    </svg>
  );
}
