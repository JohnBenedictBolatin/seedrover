"use client";

import { useActionState, useMemo, useState } from "react";
import Link from "next/link";
import { recordSalesOrderAction, type SalesFormState } from "@/app/(portal)/sales/actions";
import { formatCurrency, formatQuantity } from "@/lib/format";
import type { SellableItem } from "@/lib/sales";
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

export function SalesOrderForm({ items }: { items: SellableItem[] }) {
  const [state, formAction, pending] = useActionState(
    recordSalesOrderAction,
    initialState,
  );
  const [lineItems, setLineItems] = useState<LineItem[]>(() => [newLineItem(items)]);
  const [discountType, setDiscountType] = useState("None");
  const [discountValue, setDiscountValue] = useState("");
  const [amountPaid, setAmountPaid] = useState("");

  const itemById = useMemo(
    () => new Map(items.map((item) => [item.id, item])),
    [items],
  );

  const subtotal = lineItems.reduce(
    (total, item) => total + toNumber(item.quantity) * toNumber(item.unitPrice),
    0,
  );
  const discountNumber = toNumber(discountValue);
  const discountAmount =
    discountType === "Amount"
      ? Math.min(discountNumber, subtotal)
      : discountType === "Percent"
        ? subtotal * Math.min(discountNumber, 100) / 100
        : 0;
  const total = Math.max(subtotal - discountAmount, 0);
  const paid = toNumber(amountPaid);
  const change = amountPaid.trim() ? Math.max(paid - total, 0) : 0;

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

  if (items.length === 0) {
    return (
      <div className={styles.emptyState}>
        <strong>No sellable inventory available.</strong>
        <span>Add stock and selling prices before recording a sale.</span>
      </div>
    );
  }

  return (
    <form className={styles.form} action={formAction}>
      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <div>
            <p>Receipt items</p>
            <h2>Multi-item transaction</h2>
          </div>
          <button type="button" onClick={addLineItem}>
            Add item
          </button>
        </div>

        <div className={styles.lines}>
          {lineItems.map((lineItem, index) => {
            const selectedItem = itemById.get(lineItem.inventoryId);

            return (
              <div className={styles.lineItem} key={lineItem.key}>
                <label>
                  Item
                  <select
                    name="inventory_id"
                    value={lineItem.inventoryId}
                    onChange={(event) =>
                      updateLineItem(lineItem.key, {
                        inventoryId: event.target.value,
                      })
                    }
                  >
                    {items.map((item) => (
                      <option value={item.id} key={item.id}>
                        {item.label} ({item.stockCode})
                      </option>
                    ))}
                  </select>
                </label>

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
                  Remove
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
            <label>
              Payment method
              <select name="payment_method" defaultValue="Cash">
                <option>Cash</option>
                <option>GCash</option>
                <option>Bank Transfer</option>
                <option>Card</option>
                <option>Other</option>
              </select>
            </label>
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
              Discount type
              <select
                name="discount_type"
                value={discountType}
                onChange={(event) => setDiscountType(event.target.value)}
              >
                <option>None</option>
                <option>Amount</option>
                <option>Percent</option>
              </select>
            </label>
            <label>
              Discount value
              <input
                min="0"
                name="discount_value"
                step="0.01"
                type="number"
                value={discountValue}
                onChange={(event) => setDiscountValue(event.target.value)}
              />
            </label>
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

          {state.message ? (
            <p className={styles.message} role="status">
              {state.message}
              {state.receiptId ? (
                <Link href={`/sales/${state.receiptId}`}>View receipt</Link>
              ) : null}
            </p>
          ) : null}

          <button className={styles.submitButton} disabled={pending} type="submit">
            {pending ? "Recording sale..." : "Record sale"}
          </button>
        </div>
      </section>
    </form>
  );
}
