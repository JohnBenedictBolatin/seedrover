"use client";

import type { FormEvent, InputHTMLAttributes, ReactNode } from "react";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  Apple,
  ArrowDownCircle,
  ArrowUpCircle,
  Boxes,
  CalendarDays,
  Carrot,
  Check,
  ChevronLeft,
  ClipboardList,
  X,
  ChevronRight,
  Edit3,
  Filter,
  Leaf,
  ChevronDown,
  ImageIcon,
  Package,
  PackagePlus,
  Plus,
  Search,
  SlidersHorizontal,
  Sprout,
  Trash2,
  WalletCards,
} from "lucide-react";
import { DayPicker } from "react-day-picker";
import {
  adjustStockAction,
  createInventoryItemAction,
  deleteInventoryItemAction,
  recordInventorySaleAction,
  stockInAction,
  stockOutAction,
  updateInventoryItemAction,
} from "@/app/(portal)/inventory/actions";
import {
  ActionAlertStack,
  type ActionAlert,
  type AlertTone,
} from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { formatCurrency, formatDateTime, formatQuantity } from "@/lib/format";
import type { InventoryItem } from "@/lib/inventory";
import styles from "@/app/(portal)/inventory/page.module.css";

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
const units = ["kg", "g", "pcs", "bundle", "crate", "tray", "sack"];
const statusOptions = ["All", "In Stock", "Low Stock", "Critical Stock", "Out of Stock"];
const sortOptions = ["Name", "Quantity", "Updated", "Value"];
const stockInLocations = [
  "Harvest Bay",
  "Greenhouse Sorting",
  "Field Crate",
  "Market Return",
  "Farm-table Prep",
];
const stockOutReasons = [
  "Market Distribution",
  "Farm-table Dining",
  "Kitchen Preparation",
  "Spoilage Removal",
  "Staff Allocation",
];
const paymentMethods = ["Cash", "GCash", "Bank Transfer", "Card", "Other"];

type DialogState =
  | { type: "add" }
  | { type: "details"; item: InventoryItem }
  | { type: "edit"; item: InventoryItem }
  | { type: "stock-in"; item: InventoryItem }
  | { type: "stock-out"; item: InventoryItem }
  | { type: "delete"; item: InventoryItem }
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

export function InventoryWorkspace({ items }: { items: InventoryItem[] }) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All");
  const [status, setStatus] = useState("All");
  const [sort, setSort] = useState("Name");
  const [dialog, setDialog] = useState<DialogState>(null);
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);

  function notify(tone: AlertTone, text: string) {
    const id = Date.now();
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => {
      setAlerts((current) => current.filter((alert) => alert.id !== id));
    }, 4200);
  }

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
        <button
          className={styles.addItemButton}
          type="button"
          onClick={() => setDialog({ type: "add" })}
        >
          <span className={styles.addItemText}>Add Item</span>
          <span className={styles.addItemIcon} aria-hidden="true">
            <Plus size={20} />
          </span>
        </button>
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
        notify={notify}
        onClose={() => setDialog(null)}
      />
      <ActionAlertStack
        alerts={alerts}
        onDismiss={(id) =>
          setAlerts((current) => current.filter((alert) => alert.id !== id))
        }
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
  value,
  variant = "form",
}: {
  defaultValue?: string;
  icon?: ReactNode;
  label: string;
  name?: string;
  onChange?: (value: string) => void;
  options: string[];
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
      {variant === "form" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
      <button
        aria-expanded={open}
        className={styles.themedSelectButton}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        {variant === "toolbar" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
        <span className={styles.themedSelectValue}>{selectedValue}</span>
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
          label="Stock In"
          tone="stock-in"
          onClick={() => onOpen({ type: "stock-in", item })}
        >
          <ArrowUpCircle size={16} />
        </IconAction>
        <IconAction
          label="Stock Out"
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
  notify,
  onClose,
}: {
  dialog: DialogState;
  notify: (tone: AlertTone, text: string) => void;
  onClose: () => void;
}) {
  if (!dialog) {
    return null;
  }

  const modalMeta = {
    add: { title: "Add Item", icon: <PackagePlus size={18} /> },
    details: { title: "Stock Details", icon: <ClipboardList size={18} /> },
    edit: { title: "Edit Item", icon: <Edit3 size={18} /> },
    "stock-in": { title: "Stock In", icon: <ArrowUpCircle size={18} /> },
    "stock-out": { title: "Stock Out", icon: <ArrowDownCircle size={18} /> },
    delete: { title: "Delete Item", icon: <Trash2 size={18} /> },
  }[dialog.type];
  const title = modalMeta.title;

  return (
    <div className={styles.modalBackdrop} role="presentation">
      <section className={styles.modal} role="dialog" aria-modal="true" aria-label={title}>
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {modalMeta.icon}
            </span>
            <span>{title}</span>
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
            successMessage="Success - Inventory item added."
          />
        ) : null}
        {dialog.type === "details" ? <DetailsPanel item={dialog.item} /> : null}
        {dialog.type === "edit" ? (
          <InventoryForm
            action={updateInventoryItemAction}
            item={dialog.item}
            notify={notify}
            onSuccess={onClose}
            successMessage="Success - Inventory item updated."
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
      </section>
    </div>
  );
}

function useActionSubmit({
  action,
  confirmMessage,
  notify,
  onSuccess,
  successMessage,
}: {
  action: (formData: FormData) => void | Promise<void>;
  confirmMessage?: string;
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
        message: confirmMessage,
        confirmLabel: "Confirm",
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
          `Error - ${error instanceof Error ? error.message : "Something went wrong."}`,
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

    const confirmed = await confirm({
      message: item
        ? "Are you sure you want to save these inventory item changes?"
        : "Are you sure you want to create this inventory item?",
      confirmLabel: item ? "Save Item" : "Create Item",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(form);

    startTransition(async () => {
      try {
        await action(formData);

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
          `Error - ${error instanceof Error ? error.message : "Something went wrong."}`,
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
      message: `Are you sure you want to permanently delete ${item.itemName}?`,
      confirmLabel: "Delete Item",
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
        notify("success", "Success - Inventory item deleted.");
      } catch (error) {
        notify(
          "error",
          `Error - ${error instanceof Error ? error.message : "Something went wrong."}`,
        );
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      {item ? <input name="id" type="hidden" value={item.id} /> : null}
      <Field label="Item name" name="item_name" required defaultValue={item?.itemName} />
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
          defaultValue={item?.quantity ?? 0}
        />
        <ThemedSelect
          label="Unit"
          name="unit"
          options={units}
          defaultValue={item?.unit ?? "kg"}
        />
      </div>
      <Field label="Minimum stock level" name="minimum_quantity" type="number" step="0.01" min="0" defaultValue={item?.minimumQuantity ?? 0} />
      <div className={styles.twoColumn}>
        <Field label="Unit cost" name="unit_cost" type="number" step="0.01" min="0" defaultValue={item?.unitCost ?? ""} />
        <Field label="Selling price" name="selling_price" type="number" step="0.01" min="0" defaultValue={item?.sellingPrice ?? ""} />
      </div>
      <Field label="Storage location" name="storage_location" defaultValue={item?.storageLocation ?? "Harvest Bay"} />
      <label>
        <span>Stock image</span>
        <input accept="image/jpeg,image/png,image/webp" name="image" type="file" />
      </label>
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
    const [reason, setReason] = useState(mode === "in" ? stockInLocations[0] : stockOutReasons[0]);
    const [pending, startTransition] = useTransition();
    const [paymentMethod, setPaymentMethod] = useState(paymentMethods[0]);
    const [otherPaymentMethod, setOtherPaymentMethod] = useState("");
    const localDate = new Date();
    localDate.setMinutes(localDate.getMinutes() - localDate.getTimezoneOffset());
    const [saleDate, setSaleDate] = useState(localDate.toISOString().slice(0, 16));
    const isSale = mode === "out" && reason === "Market Distribution";

  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const confirmed = await confirm({
      message: isSale
        ? `Are you sure you want to record this market distribution sale for ${item.itemName}?`
        : mode === "in"
          ? `Are you sure you want to record stock in for ${item.itemName}?`
          : `Are you sure you want to record stock out for ${item.itemName}?`,
      confirmLabel: isSale ? "Record Sale" : "Confirm",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(form);

    startTransition(async () => {
      try {
        if (isSale) {
          await recordInventorySaleAction(formData);
          notify("success", "Success - Sale recorded and inventory deducted.");
        } else if (mode === "in") {
          await stockInAction(formData);
          notify("success", "Success - Stock quantity added.");
        } else {
          await stockOutAction(formData);
          notify("success", "Success - Stock quantity deducted.");
        }

        onSuccess();
        router.refresh();
      } catch (error) {
        notify(
          "error",
          `Error - ${error instanceof Error ? error.message : "Something went wrong."}`,
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
        label={isSale ? `Quantity sold (${item.unit})` : `Quantity (${item.unit})`}
        name="quantity"
        required
        type="number"
        step="0.01"
        min="0.01"
      />
      <ThemedSelect
        label={mode === "in" ? "Stock in location" : "Reason"}
        name="reason"
        options={options}
        value={reason}
        onChange={setReason}
      />
      {isSale ? (
        <>
          <div className={styles.twoColumn}>
            <Field
              label="Unit price"
              name="unit_price"
              required
              type="number"
              step="0.01"
              min="0"
              defaultValue={item.sellingPrice ?? 0}
            />
            <SaleDateField value={saleDate} onChange={setSaleDate} />
          </div>
          <ThemedSelect
            label="Payment method"
            name="payment_method"
            options={paymentMethods}
            value={paymentMethod}
            onChange={(value) => {
              setPaymentMethod(value);
              if (value !== "Other") {
                setOtherPaymentMethod("");
              }
            }}
          />
          {paymentMethod === "Other" ? (
            <Field
              label="Other payment method"
              name="other_payment_method"
              required
              placeholder="e.g. Maya, cheque, farm credit"
              value={otherPaymentMethod}
              onChange={(event) => setOtherPaymentMethod(event.target.value)}
            />
          ) : null}
          {paymentMethod !== "Cash" ? (
            <Field
              label={`${paymentMethod} transaction ID`}
              name="transaction_reference"
              required
              placeholder="Enter transaction/reference number"
            />
          ) : null}
          <Field label="Customer name" name="customer_name" />
          <Field label="Sale remarks" name="remarks" defaultValue="Market distribution." />
        </>
      ) : (
        <Field
          label="Remarks"
          name="remarks"
          defaultValue={mode === "in" ? "Harvest received." : "Stock deducted."}
        />
      )}
      <button className={styles.primaryAction} disabled={pending} type="submit">
        {mode === "in" ? (
          <ArrowUpCircle size={17} />
        ) : isSale ? (
          <WalletCards size={17} />
        ) : (
          <ArrowDownCircle size={17} />
        )}
        <span>{pending ? "Saving..." : isSale ? "Record Sale" : "Confirm"}</span>
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
    confirmMessage: `Are you sure you want to permanently delete ${item.itemName}?`,
    notify,
    onSuccess,
    successMessage: "Success - Inventory item deleted.",
  });

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={item.id} />
      <p className={styles.warningText}>Delete {item.itemName}? This cannot be undone.</p>
      <button className={styles.dangerAction} disabled={pending} type="submit">
        <Trash2 size={17} />
        <span>{pending ? "Deleting..." : "Delete Item"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
  );
}

function DetailsPanel({ item }: { item: InventoryItem }) {
  return (
    <div className={styles.detailsGrid}>
      <div className={styles.detailsTop}>
        <div className={styles.detailHero}>
          {item.imageUrl ? (
            <span
              className={styles.detailImage}
              style={{ backgroundImage: `url("${item.imageUrl}")` }}
            />
          ) : (
            <ImageIcon size={52} />
          )}
        </div>
        <div className={styles.detailSummary}>
          <div className={styles.detailTitleBlock}>
            <span className={styles.itemCode}>{item.stockCode}</span>
            <div className={styles.detailTitleRow}>
              <h4>{item.itemName}</h4>
              <span className={styles.status} data-status={getStockStatus(item)}>
                {getStockStatus(item)}
              </span>
            </div>
          </div>
          <div className={styles.detailMetrics}>
            <ReadOnly label="Quantity" value={formatQuantity(item.quantity, item.unit)} />
            <ReadOnly label="Minimum" value={formatQuantity(item.minimumQuantity, item.unit)} />
            <ReadOnly label="Location" value={item.storageLocation} />
            <ReadOnly label="Updated" value={formatDateTime(item.updatedAt)} />
            <ReadOnly label="Unit cost" value={item.unitCost === null ? "Not set" : formatCurrency(item.unitCost)} />
            <ReadOnly label="Sell price" value={item.sellingPrice === null ? "Not set" : formatCurrency(item.sellingPrice)} />
            <ReadOnly label="Stock value" value={formatCurrency(item.quantity * (item.unitCost ?? 0))} />
            <ReadOnly label="Est. sales" value={formatCurrency(item.quantity * (item.sellingPrice ?? 0))} />
          </div>
        </div>
      </div>
      <HistoryList item={item} />
    </div>
  );
}

function HistoryList({ item }: { item: InventoryItem }) {
  const [historyModal, setHistoryModal] = useState<"transactions" | "sales" | null>(null);

  return (
    <>
      <div className={styles.historyGrid}>
        <div className={styles.historyPanel}>
          <div className={styles.historyHeader}>
            <h4 className={styles.historyHeading}>Transaction History</h4>
            {item.transactions.length > 0 ? (
              <button
                aria-label="View full transaction history"
                className={styles.historyAction}
                type="button"
                onClick={() => setHistoryModal("transactions")}
              >
                <ChevronRight size={16} />
              </button>
            ) : null}
          </div>
          {item.transactions.length === 0 ? (
            <p>No stock movements yet.</p>
          ) : (
            item.transactions.slice(0, 2).map((transaction) => (
              <div className={styles.historyItem} key={transaction.id}>
                <strong>{transaction.type}</strong>
                <span>{formatQuantity(transaction.quantity, item.unit)}</span>
                <small>{transaction.remarks}</small>
                <time>{formatDateTime(transaction.createdAt)}</time>
              </div>
            ))
          )}
        </div>
        <div className={styles.historyPanel}>
          <div className={styles.historyHeader}>
            <h4 className={styles.historyHeading}>Sales History</h4>
            {item.sales.length > 0 ? (
              <button
                aria-label="View full sales history"
                className={styles.historyAction}
                type="button"
                onClick={() => setHistoryModal("sales")}
              >
                <ChevronRight size={16} />
              </button>
            ) : null}
          </div>
          {item.sales.length === 0 ? (
            <p>No sale records yet.</p>
          ) : (
            item.sales.slice(0, 2).map((sale) => (
              <div className={styles.historyItem} key={sale.id}>
                <strong>{formatCurrency(sale.totalAmount)}</strong>
                <span>{formatQuantity(sale.quantitySold, item.unit)}</span>
                <small>
                  {sale.customerName ?? "Walk-in customer"} - {sale.paymentMethod}
                </small>
                <time>{formatDateTime(sale.saleDate)}</time>
              </div>
            ))
          )}
        </div>
      </div>
      {historyModal ? (
        <HistoryModal
          sales={item.sales}
          transactions={item.transactions}
          kind={historyModal}
          unit={item.unit}
          onClose={() => setHistoryModal(null)}
        />
      ) : null}
    </>
  );
}

function HistoryModal({
  kind,
  onClose,
  sales,
  transactions,
  unit,
}: {
  kind: "transactions" | "sales";
  onClose: () => void;
  sales: InventoryItem["sales"];
  transactions: InventoryItem["transactions"];
  unit: string;
}) {
  const isTransactions = kind === "transactions";

  return (
    <div className={styles.modalBackdrop} role="presentation">
      <section
        className={`${styles.modal} ${styles.historyModal} ${isTransactions ? styles.transactionHistoryModal : styles.salesHistoryModal}`}
        role="dialog"
        aria-modal="true"
        aria-label={isTransactions ? "Full transaction history" : "Full sales history"}
      >
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {isTransactions ? <ClipboardList size={18} /> : <WalletCards size={18} />}
            </span>
            <span>{isTransactions ? "Full Transaction History" : "Full Sales History"}</span>
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
        <div
          className={`${styles.historyModalList} ${isTransactions ? styles.transactionHistoryList : styles.salesHistoryList}`}
        >
          {isTransactions
            ? transactions.map((entry) => (
                <div className={`${styles.historyItem} ${styles.transactionHistoryItem}`} key={entry.id}>
                  <strong>{entry.type}</strong>
                  <span>{formatQuantity(entry.quantity, unit)}</span>
                  <small>{entry.remarks}</small>
                  <time>{formatDateTime(entry.createdAt)}</time>
                </div>
              ))
            : sales.map((entry) => (
                <div className={`${styles.historyItem} ${styles.salesHistoryItem}`} key={entry.id}>
                  <strong>{formatCurrency(entry.totalAmount)}</strong>
                  <span>{formatQuantity(entry.quantitySold, unit)}</span>
                  <small>
                    {entry.customerName ?? "Walk-in customer"} - {entry.paymentMethod}
                  </small>
                  <time>{formatDateTime(entry.saleDate)}</time>
                </div>
              ))}
        </div>
      </section>
    </div>
  );
}

function SaleDateField({
  value,
  onChange,
}: {
  value: string;
  onChange: (value: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const parsedDate = new Date(value);
  const selectedDate = Number.isNaN(parsedDate.getTime()) ? new Date() : parsedDate;
  const timeValue = `${String(selectedDate.getHours()).padStart(2, "0")}:${String(
    selectedDate.getMinutes(),
  ).padStart(2, "0")}`;

  function handleDateSelect(nextDate: Date | undefined) {
    if (!nextDate) {
      return;
    }

    const updated = new Date(selectedDate);
    updated.setFullYear(nextDate.getFullYear(), nextDate.getMonth(), nextDate.getDate());
    onChange(toLocalDateTimeValue(updated));
  }

  function handleTimeChange(nextTime: string) {
    const [hours, minutes] = nextTime.split(":").map(Number);
    const updated = new Date(selectedDate);
    updated.setHours(hours || 0, minutes || 0, 0, 0);
    onChange(toLocalDateTimeValue(updated));
  }

  const displayLabel = new Intl.DateTimeFormat("en-PH", {
    month: "long",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(selectedDate);

  return (
    <label className={styles.calendarField}>
      <span>Sale date</span>
      <input name="sale_date" type="hidden" value={value} />
      <button
        className={styles.calendarTrigger}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
        <CalendarDays size={17} />
        <span>{displayLabel}</span>
      </button>
      {open ? (
        <div className={styles.calendarPopover}>
          <div className={styles.calendarShell}>
            <DayPicker
              mode="single"
              selected={selectedDate}
              onSelect={handleDateSelect}
              showOutsideDays
              className={styles.calendarRoot}
              classNames={{
                months: styles.calendarMonths,
                month: styles.calendarMonth,
                nav: styles.calendarNav,
                button_previous: styles.calendarNavButton,
                button_next: styles.calendarNavButton,
                month_caption: styles.calendarCaption,
                caption_label: styles.calendarCaptionLabel,
                weekdays: styles.calendarWeekdays,
                weekday: styles.calendarWeekday,
                week: styles.calendarWeek,
                day: styles.calendarDay,
                today: styles.calendarToday,
                selected: styles.calendarSelected,
                outside: styles.calendarOutside,
                chevron: styles.calendarChevron,
              }}
              components={{
                Chevron: ({ orientation, className, ...props }) =>
                  orientation === "left" ? (
                    <ChevronLeft className={className} size={16} {...props} />
                  ) : (
                    <ChevronRight className={className} size={16} {...props} />
                  ),
              }}
            />
            <div className={styles.calendarTimeRow}>
              <span>Time</span>
              <input
                className={styles.calendarTimeInput}
                type="time"
                value={timeValue}
                onChange={(event) => handleTimeChange(event.target.value)}
              />
            </div>
            <div className={styles.calendarActions}>
              <button
                className={styles.calendarActionButton}
                type="button"
                onClick={() => setOpen(false)}
              >
                Done
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </label>
  );
}

function toLocalDateTimeValue(date: Date) {
  const local = new Date(date);
  local.setMinutes(local.getMinutes() - local.getTimezoneOffset());
  return local.toISOString().slice(0, 16);
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
