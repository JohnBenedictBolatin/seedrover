"use client";

import type { FormEvent, InputHTMLAttributes, KeyboardEvent, ReactNode } from "react";
import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Apple,
  ArrowDownCircle,
  ArrowUpCircle,
  Boxes,
  Carrot,
  Check,
  ChevronLeft,
  ClipboardList,
  Clock3,
  History,
  X,
  ChevronRight,
  Edit3,
  Filter,
  Leaf,
  ChevronDown,
  ImageIcon,
  Package,
  PackagePlus,
  Search,
  SlidersHorizontal,
  Sprout,
  Trash2,
} from "lucide-react";
import {
  adjustStockAction,
  createInventoryItemAction,
  deleteInventoryItemAction,
  stockInAction,
  stockOutAction,
  updateInventoryItemAction,
} from "@/app/(portal)/inventory/actions";
import type { AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { useActionFeedback } from "@/components/action-feedback";
import { FileUploadField } from "@/components/file-upload-field";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import { sharedWorkflowChoices, sharedWorkflowTerms } from "@/lib/shared-workflow-terms";
import type { InventoryItem } from "@/lib/inventory";
import styles from "@/app/(portal)/inventory/page.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";

const categoryInputOptions = [
  "Leafy Vegetables",
  "Fruit Vegetables",
  "Legumes",
  "Root Crops",
  "Fruits",
  "Herbs",
  "Prepared Produce",
  "Others",
];
const categories = ["All", ...categoryInputOptions];
const units = ["kg"];
const wholeNumberUnits = new Set<string>();
const statusOptions = ["All", "In Stock", "Low Stock", "Critical Stock", "Out of Stock"];
const sortOptions = ["Name", "Quantity", "Updated", "Value"];
const stockInLocations = [...sharedWorkflowChoices.receiptSources];
const stockOutReasons = [...sharedWorkflowChoices.issueReasons];

type DialogState =
  | { type: "add" }
  | { type: "details"; item: InventoryItem }
  | { type: "edit"; item: InventoryItem }
  | { type: "stock-in"; item: InventoryItem }
  | { type: "stock-out"; item: InventoryItem }
  | { type: "delete"; item: InventoryItem }
  | { type: "history" }
  | null;

function getStockStatus(item: InventoryItem) {
  if (item.quantity <= 0) {
    return "Out of Stock";
  }

  if (item.quantity <= item.minimumQuantity * 0.5) {
    return "Critical Stock";
  }

  if (item.quantity <= item.minimumQuantity) {
    return "Low Stock";
  }

  return "In Stock";
}

function displayCategory(item: InventoryItem) {
  if (categoryInputOptions.includes(item.category)) {
    return item.category;
  }

  if (item.category === "Seeds") {
    return "Legumes";
  }

  if (item.category === "Fertilizer") {
    return "Herbs";
  }

  if (item.category === "Consumables") {
    return "Fruit Vegetables";
  }

  if (item.category === "Hardware" || item.category === "Tools") {
    return "Others";
  }

  const name = item.itemName.toLowerCase();

  if (/(pechay|lettuce|kangkong|spinach|mustard|cabbage|leafy)/.test(name)) {
    return "Leafy Vegetables";
  }

  if (/(tomato|eggplant|okra|squash|pepper|cucumber|upo|patola|ampalaya)/.test(name)) {
    return "Fruit Vegetables";
  }

  if (/(peanut|bean|sitaw|mongo|monggo|legume)/.test(name)) {
    return "Legumes";
  }

  if (/(carrot|radish|kamote|sweet potato|potato|gabi|root)/.test(name)) {
    return "Root Crops";
  }

  if (/(calamansi|banana|papaya|mango|fruit)/.test(name)) {
    return "Fruits";
  }

  if (/(basil|mint|oregano|parsley|herb)/.test(name)) {
    return "Herbs";
  }

  if (/(packed|prepared|bundle|tray|washed|sorted)/.test(name)) {
    return "Prepared Produce";
  }

  return "Others";
}

function categoryMeta(category: string) {
  if (category === "Leafy Vegetables") {
    return { icon: <Leaf size={22} />, color: "#7dff72" };
  }

  if (category === "Fruit Vegetables") {
    return { icon: <Apple size={22} />, color: "#ffb85c" };
  }

  if (category === "Legumes") {
    return { icon: <Sprout size={22} />, color: "#6ee7b7" };
  }

  if (category === "Root Crops") {
    return { icon: <Carrot size={22} />, color: "#ff9855" };
  }

  if (category === "Fruits") {
    return { icon: <Apple size={22} />, color: "#ff6f91" };
  }

  if (category === "Herbs") {
    return { icon: <Leaf size={22} />, color: "#8dff2a" };
  }

  if (category === "Prepared Produce") {
    return { icon: <Package size={22} />, color: "#60a5fa" };
  }

  return { icon: <Boxes size={22} />, color: "#b4b4b4" };
}

export function InventoryWorkspace({
  items,
  initialItemId,
}: {
  items: InventoryItem[];
  initialItemId?: string;
}) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All");
  const [status, setStatus] = useState("All");
  const [sort, setSort] = useState("Name");
  const [dialog, setDialog] = useState<DialogState>(() => {
    const initialItem = items.find((item) => item.id === initialItemId);
    return initialItem ? { type: "details", item: initialItem } : null;
  });
  const { notify: sendFeedback } = useActionFeedback();
  const notify = (tone: AlertTone, text: string) => sendFeedback({ tone, text });

  const filteredItems = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...items]
      .filter((item) => {
        const itemStatus = getStockStatus(item);
        const matchesQuery =
          normalizedQuery.length === 0 ||
          item.itemName.toLowerCase().includes(normalizedQuery) ||
          item.stockCode.toLowerCase().includes(normalizedQuery) ||
          item.storageLocation.toLowerCase().includes(normalizedQuery);

        return (
          matchesQuery &&
          (category === "All" || displayCategory(item) === category) &&
          (status === "All" || itemStatus === status)
        );
      })
      .sort((left, right) => {
        if (sort === "Quantity") {
          return left.quantity - right.quantity;
        }

        if (sort === "Updated") {
          return new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime();
        }

        if (sort === "Value") {
          return (
            right.quantity * (right.sellingPrice ?? 0) -
            left.quantity * (left.sellingPrice ?? 0)
          );
        }

        return left.itemName.localeCompare(right.itemName);
      });
  }, [category, items, query, sort, status]);

  const groupedItems = useMemo(() => {
    return filteredItems.reduce<Record<string, InventoryItem[]>>((groups, item) => {
      const groupName = displayCategory(item);
      groups[groupName] = [...(groups[groupName] ?? []), item];
      return groups;
    }, {});
  }, [filteredItems]);

  return (
    <>
      <section className={quickActionStyles.quickActions} aria-label="Inventory quick actions">
        <div>
          <p className={quickActionStyles.eyebrow}>Quick action</p>
          <h2>Inventory control</h2>
          <span>Add an inventory item or review every stock movement.</span>
        </div>
        <div className={styles.inventoryQuickActions}>
          <button className={quickActionStyles.recordSaleButton} type="button" onClick={() => setDialog({ type: "add" })}>
            <span className={quickActionStyles.recordSaleText}>ADD ITEM</span>
            <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><PackagePlus size={20} /></span>
          </button>
          <button className={quickActionStyles.recordSaleButton} type="button" onClick={() => setDialog({ type: "history" })}>
            <span className={quickActionStyles.recordSaleText}>VIEW INVENTORY HISTORY</span>
            <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><History size={20} /></span>
          </button>
        </div>
      </section>
      <section className={styles.inventoryToolbar}>
        <label className={styles.searchField}>
          <Search size={18} />
          <input
            placeholder="Search inventory"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
        <SelectControl
          icon={<Filter size={17} />}
          label="Category"
          value={category}
          values={categories}
          onChange={setCategory}
        />
        <SelectControl
          icon={<ClipboardList size={17} />}
          label="Status"
          value={status}
          values={statusOptions}
          onChange={setStatus}
        />
        <SelectControl
          icon={<SlidersHorizontal size={17} />}
          label="Sort"
          value={sort}
          values={sortOptions}
          onChange={setSort}
        />
      </section>

      {filteredItems.length === 0 ? (
        <div className={styles.emptyState}>
          <strong>No inventory items match the current view.</strong>
          <span>Try changing the search, category, or status filter.</span>
        </div>
      ) : (
        <section className={styles.stockGroups}>
          {Object.entries(groupedItems).map(([groupName, groupItems]) => (
            <StockGroup
              groupItems={groupItems}
              groupName={groupName}
              key={groupName}
              onOpen={setDialog}
            />
          ))}
        </section>
      )}

      <InventoryDialog
        dialog={dialog}
        items={items}
        notify={notify}
        onAction={setDialog}
        onClose={() => setDialog(null)}
      />
    </>
  );
}

function SelectControl({
  icon,
  label,
  onChange,
  value,
  values,
}: {
  icon: ReactNode;
  label: string;
  onChange: (value: string) => void;
  value: string;
  values: string[];
}) {
  return (
    <ThemedSelect
      icon={icon}
      label={label}
      options={values}
      value={value}
      variant="toolbar"
      onChange={onChange}
    />
  );
}

function ThemedSelect({
  defaultValue,
  icon,
  label,
  name,
  onChange,
  options,
  placeholder,
  required = false,
  value,
  variant = "form",
}: {
  defaultValue?: string;
  icon?: ReactNode;
  label: string;
  name?: string;
  onChange?: (value: string) => void;
  options: string[];
  placeholder?: string;
  required?: boolean;
  value?: string;
  variant?: "toolbar" | "form";
}) {
  const [open, setOpen] = useState(false);
  const [internalValue, setInternalValue] = useState(defaultValue ?? options[0] ?? "");
  const selectedValue = value ?? internalValue;

  function handleSelect(nextValue: string) {
    setInternalValue(nextValue);
    onChange?.(nextValue);
    setOpen(false);
  }

  return (
    <div
      className={`${styles.themedSelect} ${
        variant === "toolbar" ? styles.themedSelectToolbar : styles.themedSelectForm
      }`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      {name ? <input name={name} type="hidden" value={selectedValue} /> : null}
      {variant === "form" ? <span className={styles.themedSelectLabel}>{label}{required ? <span aria-hidden="true" className={styles.requiredMarker}>*</span> : null}</span> : null}
      <button
        aria-expanded={open}
        className={styles.themedSelectButton}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        {variant === "toolbar" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
        <span className={styles.themedSelectValue}>{selectedValue || placeholder || "No stage change"}</span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? (
        <div className={styles.themedSelectMenu}>
          {options.map((option) => {
            const selected = option === selectedValue;

            return (
              <button
                className={styles.themedSelectOption}
                data-selected={selected ? "true" : "false"}
                key={option}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => handleSelect(option)}
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

function StockGroup({
  groupItems,
  groupName,
  onOpen,
}: {
  groupItems: InventoryItem[];
  groupName: string;
  onOpen: (dialog: DialogState) => void;
}) {
  const rowRef = useRef<HTMLDivElement>(null);

  function scrollCards(direction: "left" | "right") {
    const row = rowRef.current;

    if (!row) {
      return;
    }

    const cardWidth = row.querySelector<HTMLElement>("[data-stock-card]")?.offsetWidth ?? 300;
    row.scrollBy({
      behavior: "smooth",
      left: direction === "right" ? cardWidth + 14 : -(cardWidth + 14),
    });
  }

  return (
    <div className={styles.stockGroup}>
      <div className={styles.stockGroupHeader}>
        <h3>
          <span
            className={styles.categoryIcon}
            style={{ color: categoryMeta(groupName).color }}
            aria-hidden="true"
          >
            {categoryMeta(groupName).icon}
          </span>
          <span>{groupName}</span> <span>({groupItems.length})</span>
        </h3>
        <div className={styles.stockScrollActions} aria-label={`${groupName} stock scroll controls`}>
          <button
            aria-label={`Scroll ${groupName} stocks left`}
            type="button"
            onClick={() => scrollCards("left")}
          >
            <ChevronLeft size={18} />
          </button>
          <button
            aria-label={`Scroll ${groupName} stocks right`}
            type="button"
            onClick={() => scrollCards("right")}
          >
            <ChevronRight size={18} />
          </button>
        </div>
      </div>
      <div className={styles.cardRow} ref={rowRef}>
        {groupItems.map((item) => (
          <InventoryCard item={item} key={item.id} onOpen={onOpen} />
        ))}
      </div>
    </div>
  );
}

function InventoryCard({
  item,
  onOpen,
}: {
  item: InventoryItem;
  onOpen: (dialog: DialogState) => void;
}) {
  const status = getStockStatus(item);

  return (
    <article
      className={styles.stockCard}
      data-stock-card
      role="button"
      tabIndex={0}
      onClick={() => onOpen({ type: "details", item })}
      onKeyDown={(event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          onOpen({ type: "details", item });
        }
      }}
    >
      <div className={styles.imageButton}>
        {item.imageUrl ? (
          <span
            className={styles.stockImage}
            style={{ backgroundImage: `url("${item.imageUrl}")` }}
          />
        ) : (
          <ImageIcon size={34} />
        )}
      </div>
      <div className={styles.cardTitleRow}>
        <div>
          <span className={styles.itemCode}>{item.stockCode}</span>
          <h4>{item.itemName}</h4>
        </div>
        <span className={styles.status} data-status={status}>
          {status}
        </span>
      </div>
      <dl className={styles.cardFacts}>
        <div>
          <dt>Quantity</dt>
          <dd>{formatQuantity(item.quantity, item.unit)}</dd>
        </div>
        <div>
          <dt>Updated</dt>
          <dd>{formatDateTime(item.updatedAt)}</dd>
        </div>
        <div>
          <dt>Sell price</dt>
          <dd>{item.sellingPrice === null ? "Not set" : formatCurrency(item.sellingPrice)}</dd>
        </div>
        <div>
          <dt>Location</dt>
          <dd>{item.storageLocation}</dd>
        </div>
      </dl>
      <div className={styles.cardActions}>
        <IconAction
          label={sharedWorkflowTerms.receiveStock}
          tone="stock-in"
          onClick={() => onOpen({ type: "stock-in", item })}
        >
          <ArrowUpCircle size={16} />
        </IconAction>
        <IconAction
          label={sharedWorkflowTerms.issueStock}
          tone="stock-out"
          onClick={() => onOpen({ type: "stock-out", item })}
        >
          <ArrowDownCircle size={16} />
        </IconAction>
        <IconAction label="Edit" tone="edit" onClick={() => onOpen({ type: "edit", item })}>
          <Edit3 size={16} />
        </IconAction>
      </div>
    </article>
  );
}

function IconAction({
  children,
  label,
  onClick,
  tone,
}: {
  children: ReactNode;
  label: string;
  onClick: () => void;
  tone: "stock-in" | "stock-out" | "edit";
}) {
  return (
    <button
      aria-label={label}
      className={styles.iconAction}
      data-align={tone === "edit" ? "end" : "start"}
      data-tone={tone}
      title={label}
      type="button"
      onClick={(event) => {
        event.stopPropagation();
        onClick();
      }}
    >
      {children}
    </button>
  );
}

function InventoryDialog({
  dialog,
  items,
  notify,
  onAction,
  onClose,
}: {
  dialog: DialogState;
  items: InventoryItem[];
  notify: (tone: AlertTone, text: string) => void;
  onAction: (dialog: DialogState) => void;
  onClose: () => void;
}) {
  const dialogRef = useRef<HTMLElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  const itemId = dialog && "item" in dialog ? dialog.item.id : null;
  const dialogType = dialog?.type ?? null;
  const [historyPage, setHistoryPage] = useState(1);
  const historyPageSize = 5;
  const historyRecords = useMemo(
    () =>
      items
        .flatMap((item) =>
          item.transactions.map((transaction) => ({ item, transaction })),
        )
        .sort(
          (a, b) =>
            new Date(b.transaction.createdAt).getTime() -
            new Date(a.transaction.createdAt).getTime(),
        ),
    [items],
  );
  const historyPageCount = Math.max(
    1,
    Math.ceil(historyRecords.length / historyPageSize),
  );
  const currentHistoryPage = Math.min(historyPage, historyPageCount);
  const visibleHistoryRecords = historyRecords.slice(
    (currentHistoryPage - 1) * historyPageSize,
    currentHistoryPage * historyPageSize,
  );

  useEffect(() => {
    if (!dialogType) {
      if (previousFocus.current?.isConnected) previousFocus.current.focus();
      previousFocus.current = null;
      return;
    }
    if (!previousFocus.current) {
      previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    }
    dialogRef.current?.focus();
  }, [dialogType, itemId]);

  if (!dialog) {
    return null;
  }

  const modalMeta = {
    add: { title: "Add Item", icon: <PackagePlus size={18} /> },
    edit: { title: "Edit item", icon: <Edit3 size={18} /> },
    "stock-in": { title: sharedWorkflowTerms.receiveStock, icon: <ArrowUpCircle size={18} /> },
    "stock-out": { title: sharedWorkflowTerms.issueStock, icon: <ArrowDownCircle size={18} /> },
    delete: { title: "Delete item", icon: <Trash2 size={18} /> },
    history: { title: "Inventory History", icon: <Clock3 size={18} /> },
  } as const;
  const isDetails = dialog.type === "details";
  const title = isDetails ? "Item Details" : modalMeta[dialog.type].title;
  const modalIcon = isDetails ? categoryMeta(dialog.item.category).icon : modalMeta[dialog.type].icon;

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section ref={dialogRef} tabIndex={-1} onKeyDown={(event) => {
        if (event.key === "Escape") { event.stopPropagation(); onClose(); return; }
        if (event.key !== "Tab" || !dialogRef.current) return;
        const focusable = Array.from(dialogRef.current.querySelectorAll<HTMLElement>('button:not(:disabled), [href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])')).filter((element) => element.tabIndex >= 0 && !element.closest("[hidden]"));
        if (!focusable.length) { event.preventDefault(); return; }
        const first = focusable[0]; const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }} className={`${styles.modal} ${isDetails ? styles.inventoryDetailsModal : ""} ${dialog.type === "history" ? `${styles.transactionHistoryModal} ${styles.inventoryHistoryModal}` : ""}`} role="dialog" aria-modal="true" aria-label={title}>
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {modalIcon}
            </span>
            <span className={styles.modalTitleText}>
              {title}
            </span>
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
        {dialog.type === "add" ? (
          <InventoryForm
            action={createInventoryItemAction}
            notify={notify}
            onSuccess={onClose}
            successMessage="Inventory item added."
          />
        ) : null}
        {isDetails ? <DetailsPanel item={dialog.item} /> : null}
        {dialog.type === "edit" ? (
          <InventoryForm
            action={updateInventoryItemAction}
            item={dialog.item}
            notify={notify}
            onSuccess={onClose}
            successMessage="Inventory item updated."
          />
        ) : null}
        {dialog.type === "stock-in" ? (
          <MovementForm
            item={dialog.item}
            mode="in"
            notify={notify}
            onSuccess={onClose}
          />
        ) : null}
        {dialog.type === "stock-out" ? (
          <MovementForm
            item={dialog.item}
            mode="out"
            notify={notify}
            onSuccess={onClose}
          />
        ) : null}
        {dialog.type === "delete" ? (
          <DeleteForm item={dialog.item} notify={notify} onSuccess={onClose} />
        ) : null}
        {dialog.type === "history" ? (
          <div className={styles.inventoryHistoryLedger}>
            <div className={styles.historyPanel}>
              <div className={styles.historyHeader}><div><h4 className={styles.historyHeading}>Stock movements</h4><p>Receipts, issues, and adjustments</p></div><strong>{historyRecords.length} records</strong></div>
              <div className={styles.historyTableHeader} aria-hidden="true">
                <span>Type</span>
                <span>Item and quantity</span>
                <span>Date</span>
                <span>Notes</span>
              </div>
              <div className={styles.inventoryHistoryRecords}>
              {visibleHistoryRecords.map(({ item, transaction }) => (
                <div className={styles.historyItem} key={transaction.id}>
                  <div><strong>{transaction.type === "IN" ? sharedWorkflowTerms.receiveStock : transaction.type === "OUT" ? sharedWorkflowTerms.issueStock : sharedWorkflowTerms.adjustQuantity}</strong><span>{item.itemName} · {transaction.quantity} {item.unit}</span></div>
                  <div><small>{formatDateTime(transaction.createdAt)}</small></div>
                  <p>{transaction.remarks || "—"}</p>
                </div>
              ))}
              {items.every((item) => item.transactions.length === 0) ? <p className={styles.historyEmpty}>No inventory movements recorded yet.</p> : null}
              </div>
              {historyRecords.length > 0 ? <div className={styles.historyPagination}><button aria-label="Previous history page" disabled={currentHistoryPage === 1} type="button" onClick={() => setHistoryPage((value) => Math.max(1, value - 1))}><ChevronLeft size={16} /></button><span>Page {currentHistoryPage} of {historyPageCount}</span><button aria-label="Next history page" disabled={currentHistoryPage >= historyPageCount} type="button" onClick={() => setHistoryPage((value) => Math.min(historyPageCount, value + 1))}><ChevronRight size={16} /></button></div> : null}
            </div>
          </div>
        ) : null}
        {isDetails ? (
          <footer className={styles.inventoryDetailsFooter}>
            <button className={`${styles.primaryAction} ${styles.receiveStockAction}`} type="button" onClick={() => onAction({ type: "stock-in", item: dialog.item })}>
              <ArrowUpCircle size={18} aria-hidden="true" />
              <span>{sharedWorkflowTerms.receiveStock}</span>
            </button>
            <button className={`${styles.primaryAction} ${styles.issueStockAction}`} type="button" onClick={() => onAction({ type: "stock-out", item: dialog.item })}>
              <ArrowDownCircle size={18} aria-hidden="true" />
              <span>{sharedWorkflowTerms.issueStock}</span>
            </button>
          </footer>
        ) : null}
      </section>
    </div>
  );
}

function useActionSubmit({
  action,
  confirmMessage,
  confirmTitle,
  confirmLabel,
  notify,
  onSuccess,
  successMessage,
}: {
  action: (formData: FormData) => void | Promise<void>;
  confirmMessage?: string;
  confirmTitle?: string;
  confirmLabel?: string;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
  successMessage: string;
}) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    if (confirmMessage) {
      const confirmed = await confirm({
        title: confirmTitle,
        message: confirmMessage,
        confirmLabel: confirmLabel ?? "Confirm",
        tone: "danger",
      });

      if (!confirmed) {
        return;
      }
    }

    const formData = new FormData(form);

    startTransition(async () => {
      try {
        await action(formData);
        onSuccess();
        router.refresh();
        notify("success", successMessage);
      } catch (error) {
        notify(
          "error",
          error instanceof Error ? error.message : "Something went wrong.",
        );
      }
    });
  }

  return { confirmationDialog, handleSubmit, pending };
}

function InventoryForm({
  action,
  item,
  notify,
  onSuccess,
  successMessage,
}: {
  action: (formData: FormData) => void | Promise<void>;
  item?: InventoryItem;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
  successMessage: string;
}) {
  const [pending, startTransition] = useTransition();
  const [deletePending, startDeleteTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const formData = new FormData(form);
    const nextQuantity = Number(formData.get("quantity") ?? item?.quantity);
    const consequential = !item || nextQuantity !== item.quantity ||
      String(formData.get("unit") ?? item.unit) !== item.unit ||
      Number(formData.get("unit_cost") ?? item.unitCost) !== item.unitCost ||
      Number(formData.get("selling_price") ?? item.sellingPrice) !== item.sellingPrice;
    if (consequential) {
      const confirmed = await confirm({
        title: item ? "Update inventory item?" : "Create inventory item?",
        message: item
          ? `This will update ${item.itemName}${nextQuantity !== item.quantity ? ` and change its quantity to ${nextQuantity} ${String(formData.get("unit") ?? item.unit)}` : ""}.`
          : `This will create ${String(formData.get("item_name") ?? "this item")} with an opening stock of ${nextQuantity} ${String(formData.get("unit") ?? "kg")}.`,
        confirmLabel: item ? "Save item" : "Create item",
      });
      if (!confirmed) return;
    }

    startTransition(async () => {
      let itemDetailsSaved = false;
      try {
        await action(formData);
        itemDetailsSaved = true;

        if (item) {
          const nextQuantity = Number(formData.get("quantity") ?? item.quantity);
          if (Number.isFinite(nextQuantity) && nextQuantity !== item.quantity) {
            const adjustFormData = new FormData();
            adjustFormData.set("id", item.id);
            adjustFormData.set("new_quantity", String(nextQuantity));
            adjustFormData.set("reason", "Edit Item");
            adjustFormData.set("remarks", "Quantity updated from edit item.");
            await adjustStockAction(adjustFormData);
          }
        }

        onSuccess();
        router.refresh();
        notify("success", successMessage);
      } catch (error) {
        notify(
          "error",
          itemDetailsSaved
            ? `Inventory item details were saved, but the stock adjustment could not be recorded: ${error instanceof Error ? error.message : "Please review the item and retry the quantity adjustment."}`
            : error instanceof Error ? error.message : "Something went wrong.",
        );
      }
    });
  }

  async function handleDelete() {
    if (!item) {
      return;
    }

    const confirmed = await confirm({
      title: "Delete item?",
      message: `Permanently delete ${item.itemName}? This cannot be undone.`,
      confirmLabel: "Delete item",
      tone: "danger",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData();
    formData.set("id", item.id);

    startDeleteTransition(async () => {
      try {
        await deleteInventoryItemAction(formData);
        onSuccess();
        router.refresh();
        notify("success", "Inventory item deleted.");
      } catch (error) {
        notify(
          "error",
          error instanceof Error ? error.message : "Something went wrong.",
        );
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      {item ? <input name="id" type="hidden" value={item.id} /> : null}
      <Field label={sharedWorkflowTerms.itemName} name="item_name" placeholder="e.g. Tomato seeds" required={!item} defaultValue={item?.itemName} />
      <ThemedSelect
        label="Category"
        name="category"
        options={categoryInputOptions}
        defaultValue={item ? displayCategory(item) : "Leafy Vegetables"}
      />
      <div className={styles.twoColumn}>
        <Field
          label={item ? `Current quantity (${item.unit})` : "Quantity"}
          name="quantity"
          type="number"
          step="0.01"
          min="0"
          required={!item}
          defaultValue={item?.quantity ?? ""}
        />
        <ThemedSelect
          label="Unit"
          name="unit"
          options={units}
          defaultValue={item?.unit ?? "kg"}
        />
      </div>
      <Field label="Minimum stock level" name="minimum_quantity" placeholder="e.g. 25" type="number" step="0.01" min="0" required={!item} defaultValue={item?.minimumQuantity ?? ""} />
      <div className={styles.twoColumn}>
        <Field label="Unit cost (PHP)" name="unit_cost" placeholder="e.g. 120.00" type="number" step="0.01" min="0" required={!item} defaultValue={item?.unitCost ?? ""} />
        <Field label="Selling price (PHP)" name="selling_price" placeholder="e.g. 180.00" type="number" step="0.01" min="0" required={!item} defaultValue={item?.sellingPrice ?? ""} />
      </div>
      <Field label="Storage location" name="storage_location" placeholder="e.g. Greenhouse storage" required={!item} defaultValue={item?.storageLocation ?? ""} />
      <Field label={`${sharedWorkflowTerms.itemNotes} (optional)`} name="notes" defaultValue={item?.notes ?? ""} />
      <FileUploadField
        accept="image/jpeg,image/png,image/webp"
        helperText="JPG, PNG or WEBP"
        label="Stock image"
        name="image"
        prompt={item?.imagePath ? "Choose replacement image" : "Choose stock image"}
        required={!item}
      />
      <button className={styles.primaryAction} disabled={pending} type="submit">
        <PackagePlus size={17} />
        <span>{pending ? "Saving..." : "Save Item"}</span>
      </button>
      {item ? (
        <button
          className={styles.dangerAction}
          disabled={pending || deletePending}
          type="button"
          onClick={handleDelete}
        >
          <Trash2 size={17} />
          <span>{deletePending ? "Deleting..." : "Delete Item"}</span>
        </button>
      ) : null}
    </form>
    {confirmationDialog}
    </>
  );
}

function MovementForm({
  item,
  mode,
  notify,
  onSuccess,
}: {
  item: InventoryItem;
  mode: "in" | "out";
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  const options = mode === "in" ? stockInLocations : stockOutReasons;
  const [reason, setReason] = useState("");
  const [quantity, setQuantity] = useState("");
  const [formError, setFormError] = useState("");
  const [pending, startTransition] = useTransition();

  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const formData = new FormData(form);
    if (!reason) { setFormError(mode === "in" ? "Choose a source." : "Choose a reason."); return; }
    const quantityValue = String(formData.get("quantity") ?? "");
    const confirmed = await confirm({
      title: mode === "in" ? "Receive stock?" : "Issue stock?",
      message: mode === "in"
        ? `Add ${quantityValue} ${item.unit} to ${item.itemName}?`
        : `Deduct ${quantityValue} ${item.unit} from ${item.itemName} for ${reason}?`,
      confirmLabel: mode === "in" ? "Receive stock" : "Issue stock",
    });

    if (!confirmed) {
      return;
    }

    startTransition(async () => {
      try {
        if (mode === "in") {
          await stockInAction(formData);
          notify("success", "Stock quantity added.");
        } else {
          await stockOutAction(formData);
          notify("success", "Stock quantity deducted.");
        }

        onSuccess();
        router.refresh();
      } catch (error) {
        notify(
          "error",
          error instanceof Error ? error.message : "Something went wrong.",
        );
      }
    });
  }

  return (
    <>
      <form className={styles.formGrid} onSubmit={handleSubmit}>
        <input name="id" type="hidden" value={item.id} />
        <ReadOnly label="Item" value={item.itemName} />
        <ReadOnly label="Available" value={formatQuantity(item.quantity, item.unit)} />
        <Field
          label={`Quantity (${item.unit})`}
          name="quantity"
          value={quantity}
          onChange={(event) => setQuantity(event.currentTarget.value)}
          required
          type="number"
          step={wholeNumberUnits.has(item.unit) ? "1" : "0.01"}
          min="0.01"
        />
        <ThemedSelect
          label={mode === "in" ? "Source" : "Reason"}
          name="reason"
          options={["", ...options]}
          value={reason}
          onChange={setReason}
          placeholder={mode === "in" ? "Choose a source" : "Choose a reason"}
          required
        />
        <ReadOnly label="Resulting balance" value={formatQuantity(item.quantity + (mode === "in" ? 1 : -1) * (Number(quantity) || 0), item.unit)} />
        {formError ? <p role="alert">{formError}</p> : null}
        <Field
          label="Remarks"
          name="remarks"
          defaultValue=""
        />
        <button className={styles.primaryAction} disabled={pending} type="submit">
          {mode === "in" ? (
            <ArrowUpCircle size={17} />
          ) : (
            <ArrowDownCircle size={17} />
          )}
          <span>{pending ? "Saving..." : mode === "in" ? sharedWorkflowTerms.receiveStock : sharedWorkflowTerms.issueStock}</span>
        </button>
      </form>
      {confirmationDialog}
    </>
  );
}

function DeleteForm({
  item,
  notify,
  onSuccess,
}: {
  item: InventoryItem;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  const { confirmationDialog, handleSubmit, pending } = useActionSubmit({
    action: deleteInventoryItemAction,
    confirmTitle: "Delete inventory item?",
    confirmMessage: `Permanently delete ${item.itemName}? This cannot be undone.`,
    confirmLabel: "Delete item",
    notify,
    onSuccess,
    successMessage: "Inventory item deleted.",
  });

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={item.id} />
      <p className={styles.warningText}>Delete {item.itemName}? This cannot be undone.</p>
      <button className={styles.dangerAction} disabled={pending} type="submit">
        <Trash2 size={17} />
        <span>{pending ? "Deleting..." : "Delete item"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
  );
}

function DetailsPanel({ item }: { item: InventoryItem }) {
  const [tab, setTab] = useState<"overview" | "movements" | "sales">("overview");

  function handleTabKeyDown(event: KeyboardEvent<HTMLElement>) {
    const tabs = ["overview", "movements", "sales"] as const;
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const current = tabs.indexOf(tab);
    const next = event.key === "Home"
      ? 0
      : event.key === "End"
        ? tabs.length - 1
        : (current + (event.key === "ArrowRight" ? 1 : tabs.length - 1)) % tabs.length;
    setTab(tabs[next]);
    requestAnimationFrame(() => document.getElementById(`inventory-tab-${tabs[next]}`)?.focus());
  }

  return (
    <>
      <nav className={styles.inventoryDetailTabs} role="tablist" aria-label="Inventory item information" onKeyDown={handleTabKeyDown}>
        <button id="inventory-tab-overview" role="tab" aria-selected={tab === "overview"} aria-controls="inventory-tabpanel-overview" tabIndex={tab === "overview" ? 0 : -1} type="button" onClick={() => setTab("overview")}>OVERVIEW</button>
        <button id="inventory-tab-movements" role="tab" aria-selected={tab === "movements"} aria-controls="inventory-tabpanel-movements" tabIndex={tab === "movements" ? 0 : -1} type="button" onClick={() => setTab("movements")}>STOCK MOVEMENTS</button>
        <button id="inventory-tab-sales" role="tab" aria-selected={tab === "sales"} aria-controls="inventory-tabpanel-sales" tabIndex={tab === "sales" ? 0 : -1} type="button" onClick={() => setTab("sales")}>SALES HISTORY</button>
      </nav>
      <div className={styles.inventoryDetailsBody}>
        <div id="inventory-tabpanel-overview" role="tabpanel" aria-labelledby="inventory-tab-overview" hidden={tab !== "overview"}>
          <div className={styles.inventoryItemIdentity}>
            <div>
              <span className={styles.itemCode}>{item.stockCode}</span>
              <h4>{item.itemName}</h4>
              <small>{displayCategory(item)}</small>
            </div>
            <span className={styles.status} data-status={getStockStatus(item)}>{getStockStatus(item)}</span>
          </div>
          <div className={styles.detailsTop}>
            <div className={styles.detailHero}>
              {item.imageUrl ? (
                <span className={styles.detailImage} style={{ backgroundImage: `url("${item.imageUrl}")` }} />
              ) : (
                <ImageIcon size={52} />
              )}
            </div>
            <div className={styles.detailSummary}>
              <div className={styles.detailMetrics}>
                <ReadOnly label="Quantity" value={formatQuantity(item.quantity, item.unit)} />
                <ReadOnly label="Minimum" value={formatQuantity(item.minimumQuantity, item.unit)} />
                <ReadOnly label="Location" value={item.storageLocation} />
                <ReadOnly label="Updated" value={formatDateTime(item.updatedAt)} />
                <ReadOnly label="Unit cost (PHP)" value={item.unitCost === null ? "Not set" : formatCurrency(item.unitCost)} />
                <ReadOnly label="Sell price (PHP)" value={item.sellingPrice === null ? "Not set" : formatCurrency(item.sellingPrice)} />
                <ReadOnly label="Stock value (PHP)" value={formatCurrency(item.quantity * (item.unitCost ?? 0))} />
                <ReadOnly label="Est. sales (PHP)" value={formatCurrency(item.quantity * (item.sellingPrice ?? 0))} />
              </div>
            </div>
          </div>
        </div>
        <div id="inventory-tabpanel-movements" role="tabpanel" aria-labelledby="inventory-tab-movements" hidden={tab !== "movements"}>
          <InventoryMovementTable key={item.id} item={item} />
        </div>
        <div id="inventory-tabpanel-sales" role="tabpanel" aria-labelledby="inventory-tab-sales" hidden={tab !== "sales"}>
          <InventorySalesTable key={item.id} item={item} />
        </div>
      </div>
    </>
  );
}

function InventoryMovementTable({ item }: { item: InventoryItem }) {
  const [page, setPage] = useState(1);
  const pageSize = 5;
  const totalPages = Math.max(1, Math.ceil(item.transactions.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pageStart = Math.min(Math.max(currentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);
  const visibleTransactions = item.transactions.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <section className={styles.itemHistorySection} aria-label="Stock movement history">
      <div className={styles.itemHistoryHeading}><h4>Stock Movements</h4><span>{item.transactions.length} records</span></div>
      {item.transactions.length === 0 ? (
        <div className={styles.itemHistoryEmpty}>No stock movements recorded yet.</div>
      ) : (
        <div className={styles.itemHistoryTable} data-kind="movements" role="table" aria-label="Stock movement records">
          <div className={styles.itemHistoryTableHead} role="row">
            <span role="columnheader">Movement</span>
            <span role="columnheader">Quantity</span>
            <span role="columnheader">Date / time</span>
            <span role="columnheader">Notes</span>
          </div>
          {visibleTransactions.map((transaction) => (
            <div className={styles.itemHistoryTableRow} role="row" key={transaction.id}>
              <strong data-label="Movement">{transaction.type === "IN" ? sharedWorkflowTerms.receiveStock : transaction.type === "OUT" ? sharedWorkflowTerms.issueStock : sharedWorkflowTerms.adjustQuantity}</strong>
              <span data-label="Quantity">{formatQuantity(transaction.quantity, item.unit)}</span>
              <span data-label="Date / time">{formatDateTime(transaction.createdAt)}</span>
              <span data-label="Notes">{transaction.remarks || "—"}</span>
            </div>
          ))}
        </div>
      )}
      <HistoryTablePagination page={currentPage} totalPages={totalPages} pageNumbers={pageNumbers} label="Stock movements pagination" onPageChange={setPage} />
    </section>
  );
}

function InventorySalesTable({ item }: { item: InventoryItem }) {
  const [page, setPage] = useState(1);
  const pageSize = 5;
  const totalPages = Math.max(1, Math.ceil(item.sales.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pageStart = Math.min(Math.max(currentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);
  const visibleSales = item.sales.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <section className={styles.itemHistorySection} aria-label="Sales history">
      <div className={styles.itemHistoryHeading}><h4>Sales History</h4><span>{item.sales.length} records</span></div>
      {item.sales.length === 0 ? (
        <div className={styles.itemHistoryEmpty}>No sales recorded for this item yet.</div>
      ) : (
        <div className={styles.itemHistoryTable} data-kind="sales" role="table" aria-label="Sales records">
          <div className={styles.itemHistoryTableHead} role="row">
            <span role="columnheader">Date / time</span>
            <span role="columnheader">Customer</span>
            <span role="columnheader">Quantity</span>
            <span role="columnheader">Payment</span>
            <span role="columnheader">Sale total</span>
            <span role="columnheader">Status</span>
          </div>
          {visibleSales.map((sale) => (
            <div className={styles.itemHistoryTableRow} role="row" key={sale.id}>
              <span data-label="Date / time">{formatDateTime(sale.saleDate)}</span>
              <strong data-label="Customer">{sale.customerName ?? "Walk-in customer"}</strong>
              <span data-label="Quantity">{formatQuantity(sale.quantitySold, item.unit)}</span>
              <span data-label="Payment">{sale.paymentMethod}</span>
              <strong data-label="Sale total">{formatCurrency(sale.totalAmount)}</strong>
              <span data-label="Status"><span className={styles.itemSaleStatus} data-status={sale.status.toLowerCase()}>{sale.status}</span></span>
            </div>
          ))}
        </div>
      )}
      <HistoryTablePagination page={currentPage} totalPages={totalPages} pageNumbers={pageNumbers} label="Sales history pagination" onPageChange={setPage} />
    </section>
  );
}

function HistoryTablePagination({
  page,
  totalPages,
  pageNumbers,
  label,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  pageNumbers: number[];
  label: string;
  onPageChange: (page: number) => void;
}) {
  if (totalPages <= 1) return null;

  return (
    <nav className={styles.itemHistoryPagination} aria-label={label}>
      <button aria-label="Previous page" disabled={page === 1} type="button" onClick={() => onPageChange(Math.max(1, page - 1))}><ChevronLeft size={16} /></button>
      <div className={styles.itemHistoryPageNumbers}>
        {pageNumbers.map((number) => (
          <button key={number} type="button" data-active={number === page} aria-current={number === page ? "page" : undefined} aria-label={`Page ${number}`} onClick={() => onPageChange(number)}>{number}</button>
        ))}
      </div>
      <button aria-label="Next page" disabled={page >= totalPages} type="button" onClick={() => onPageChange(Math.min(totalPages, page + 1))}><ChevronRight size={16} /></button>
    </nav>
  );
}
function Field({
  label,
  name,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  name: string;
}) {
  return (
    <label>
      <span>{label}</span>
      <input name={name} {...props} />
    </label>
  );
}

function ReadOnly({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.readOnly}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
