"use client";

import { useMemo, useState, useTransition, type FormEvent, type InputHTMLAttributes, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import {
  Archive,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronDown,
  ClipboardList,
  Droplets,
  Edit3,
  Filter,
  ImageIcon,
  Leaf,
  Plus,
  Search,
  SlidersHorizontal,
  Sprout,
  Trash2,
  X,
} from "lucide-react";
import type { CropItem, HarvestInventoryOption } from "@/lib/crops";
import { formatDate, formatDateTime } from "@/lib/format";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import {
  createCropAction,
  cropMaintenanceAction,
  deleteCropAction,
  harvestCropToInventoryAction,
  updateCropAction,
} from "@/app/(portal)/crops/actions";
import styles from "@/app/(portal)/crops/page.module.css";

const stages = ["All", "Seeded", "Germinating", "Vegetative", "Flowering", "Harvest Ready", "Completed"];
const stageInputOptions = stages.slice(1);
const statuses = ["All", "Active", "Needs Attention", "Harvest Ready", "Completed", "Cancelled"];
const statusInputOptions = statuses.slice(1);
const sortOptions = ["Newest", "Oldest", "Name", "Harvest Soon"];

function localDateInputValue() {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

type ModalState =
  | { type: "add" }
  | { type: "details"; crop: CropItem }
  | { type: "edit"; crop: CropItem }
  | { type: "delete"; crop: CropItem }
  | null;

export function CropsWorkspace({
  crops,
  harvestInventoryOptions,
}: {
  crops: CropItem[];
  harvestInventoryOptions: HarvestInventoryOption[];
}) {
  const [query, setQuery] = useState("");
  const [stage, setStage] = useState("All");
  const [status, setStatus] = useState("All");
  const [plantingDate, setPlantingDate] = useState("");
  const [sort, setSort] = useState("Newest");
  const [modal, setModal] = useState<ModalState>(null);
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);

  function notify(tone: AlertTone, text: string) {
    const id = Date.now();
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => {
      setAlerts((current) => current.filter((alert) => alert.id !== id));
    }, 4200);
  }

  const filteredCrops = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...crops]
      .filter((crop) => {
        const haystack = `${crop.cropName} ${crop.variety} ${crop.location} ${crop.managerName} ${crop.id}`.toLowerCase();

        return (
          (normalizedQuery.length === 0 || haystack.includes(normalizedQuery)) &&
          (stage === "All" || crop.growthStage === stage) &&
          (status === "All" || crop.cropStatus === status) &&
          (!plantingDate || crop.plantingDate === plantingDate)
        );
      })
      .sort((left, right) => {
        if (sort === "Name") {
          return left.cropName.localeCompare(right.cropName);
        }

        if (sort === "Harvest Soon") {
          return (left.estimatedHarvest ?? "9999-12-31").localeCompare(right.estimatedHarvest ?? "9999-12-31");
        }

        if (sort === "Oldest") {
          return left.plantingDate.localeCompare(right.plantingDate);
        }

        return right.plantingDate.localeCompare(left.plantingDate);
      });
  }, [crops, plantingDate, query, sort, stage, status]);

  const groupedCrops = useMemo(() => {
    return filteredCrops.reduce<Record<string, CropItem[]>>((groups, crop) => {
      groups[crop.cropName] = [...(groups[crop.cropName] ?? []), crop];
      return groups;
    }, {});
  }, [filteredCrops]);

  return (
    <>
      <section className={styles.inventoryToolbar}>
        <label className={styles.searchField}>
          <Search size={18} />
          <input
            placeholder="Search crops"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
        <ThemedSelect
          icon={<Filter size={17} />}
          label="Stage"
          options={stages}
          value={stage}
          variant="toolbar"
          onChange={setStage}
        />
        <ThemedSelect
          icon={<ClipboardList size={17} />}
          label="Status"
          options={statuses}
          value={status}
          variant="toolbar"
          onChange={setStatus}
        />
        <label className={styles.dateFilter}>
          <CalendarDays size={17} />
          <span>Planted</span>
          <input
            type="date"
            value={plantingDate}
            onChange={(event) => setPlantingDate(event.target.value)}
          />
        </label>
        <ThemedSelect
          icon={<SlidersHorizontal size={17} />}
          label="Sort"
          options={sortOptions}
          value={sort}
          variant="toolbar"
          onChange={setSort}
        />
        <button className={styles.addItemButton} type="button" onClick={() => setModal({ type: "add" })}>
          <span className={styles.addItemText}>Add Crop</span>
          <span className={styles.addItemIcon} aria-hidden="true">
            <Plus size={20} />
          </span>
        </button>
      </section>

      {filteredCrops.length === 0 ? (
        <div className={styles.emptyState}>
          <strong>No crop records match the current view.</strong>
          <span>Try changing the search, stage, status, or planting date filter.</span>
        </div>
      ) : (
        <section className={styles.stockGroups}>
          {Object.entries(groupedCrops).map(([groupName, groupCrops]) => (
            <div className={styles.stockGroup} key={groupName}>
              <h3>
                <span className={styles.categoryIcon} aria-hidden="true">
                  <Leaf size={24} />
                </span>
                <span>{groupName}</span> <span>({groupCrops.length})</span>
              </h3>
              <div className={styles.cardRow}>
                {groupCrops.map((crop) => (
                  <CropCard crop={crop} key={crop.id} onOpen={setModal} />
                ))}
              </div>
            </div>
          ))}
        </section>
      )}

      <CropDialog
        dialog={modal}
        harvestInventoryOptions={harvestInventoryOptions}
        notify={notify}
        onClose={() => setModal(null)}
      />
      <ActionAlertStack
        alerts={alerts}
        onDismiss={(id) => setAlerts((current) => current.filter((alert) => alert.id !== id))}
      />
    </>
  );
}

function CropCard({
  crop,
  onOpen,
}: {
  crop: CropItem;
  onOpen: (modal: ModalState) => void;
}) {
  return (
    <article
      className={styles.stockCard}
      role="button"
      tabIndex={0}
      onClick={() => onOpen({ type: "details", crop })}
      onKeyDown={(event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          onOpen({ type: "details", crop });
        }
      }}
    >
      <div className={styles.cropHero}>
        {crop.imageUrl ? (
          <img alt={`${crop.cropName} crop`} src={crop.imageUrl} />
        ) : (
          <Sprout size={40} />
        )}
        <span>{Math.round(crop.progress * 100)}%</span>
      </div>
      <div className={styles.cardTitleRow}>
        <div>
          <span className={styles.itemCode}>{crop.growthStage}</span>
          <h4>{crop.cropName}</h4>
        </div>
        <span className={styles.status} data-status={crop.cropStatus}>
          {crop.cropStatus}
        </span>
      </div>
      <div className={styles.progress}>
        <i style={{ width: `${Math.round(crop.progress * 100)}%` }} />
      </div>
      <dl className={styles.cardFacts}>
        <div>
          <dt>Planted</dt>
          <dd>{formatDate(crop.plantingDate)}</dd>
        </div>
        <div>
          <dt>Harvest</dt>
          <dd>{crop.estimatedHarvest ? formatDate(crop.estimatedHarvest) : "Not set"}</dd>
        </div>
        <div>
          <dt>Manager</dt>
          <dd>{crop.managerName}</dd>
        </div>
        <div>
          <dt>Updated</dt>
          <dd>{formatDateTime(crop.updatedAt)}</dd>
        </div>
      </dl>
      <div className={styles.cardActions}>
        <IconAction label="Water" tone="water" onClick={() => onOpen({ type: "details", crop })}>
          <Droplets size={16} />
        </IconAction>
        <IconAction label="Edit" tone="edit" onClick={() => onOpen({ type: "edit", crop })}>
          <Edit3 size={16} />
        </IconAction>
        <IconAction label="Delete" tone="delete" onClick={() => onOpen({ type: "delete", crop })}>
          <Trash2 size={16} />
        </IconAction>
      </div>
    </article>
  );
}

function CropDialog({
  dialog,
  harvestInventoryOptions,
  notify,
  onClose,
}: {
  dialog: ModalState;
  harvestInventoryOptions: HarvestInventoryOption[];
  notify: (tone: AlertTone, text: string) => void;
  onClose: () => void;
}) {
  if (!dialog) {
    return null;
  }

  const modalMeta = {
    add: { title: "Add Crop", icon: <Sprout size={18} /> },
    details: { title: "Crop Details", icon: <Leaf size={18} /> },
    edit: { title: "Edit Crop", icon: <Edit3 size={18} /> },
    delete: { title: "Delete Crop", icon: <Trash2 size={18} /> },
  }[dialog.type];

  return (
    <div className={styles.modalBackdrop} role="presentation">
      <section className={styles.modal} role="dialog" aria-modal="true" aria-label={modalMeta.title}>
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {modalMeta.icon}
            </span>
            <span>{modalMeta.title}</span>
          </h3>
          <button aria-label="Close modal" className={styles.modalCloseButton} type="button" onClick={onClose}>
            <X size={18} />
          </button>
        </header>

        {dialog.type === "details" ? (
          <CropDetails
            crop={dialog.crop}
            harvestInventoryOptions={harvestInventoryOptions}
            notify={notify}
            onSuccess={onClose}
          />
        ) : null}
        {dialog.type === "add" ? (
          <CropForm action={createCropAction} notify={notify} onSuccess={onClose} successMessage="Success - Crop record added." />
        ) : null}
        {dialog.type === "edit" ? (
          <CropForm
            action={updateCropAction}
            crop={dialog.crop}
            notify={notify}
            onSuccess={onClose}
            successMessage="Success - Crop record updated."
          />
        ) : null}
        {dialog.type === "delete" ? <DeleteCropForm crop={dialog.crop} notify={notify} onSuccess={onClose} /> : null}
      </section>
    </div>
  );
}

function CropDetails({
  crop,
  harvestInventoryOptions,
  notify,
  onSuccess,
}: {
  crop: CropItem;
  harvestInventoryOptions: HarvestInventoryOption[];
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  return (
    <div className={styles.detailsGrid}>
      <div className={styles.detailImagePanel}>
        {crop.imageUrl ? (
          <img alt={`${crop.cropName} crop`} src={crop.imageUrl} />
        ) : (
          <div>
            <Sprout size={42} />
            <span>No crop image uploaded yet.</span>
          </div>
        )}
      </div>
      <div className={styles.detailTitleBlock}>
        <span className={styles.itemCode}>{crop.growthStage}</span>
        <div className={styles.detailTitleRow}>
          <h4>{crop.cropName}</h4>
          <span className={styles.status} data-status={crop.cropStatus}>
            {crop.cropStatus}
          </span>
        </div>
      </div>
      <div className={styles.detailMetrics}>
        <ReadOnly label="Manager" value={crop.managerName} />
        <ReadOnly label="Location" value={crop.location} />
        <ReadOnly label="Planting date" value={formatDate(crop.plantingDate)} />
        <ReadOnly label="Estimated harvest" value={crop.estimatedHarvest ? formatDate(crop.estimatedHarvest) : "Not set"} />
      </div>
      <div className={styles.notesPanel}>
        <span>Maintenance notes</span>
        <p>{crop.maintenanceNotes}</p>
      </div>
      <MaintenanceForm crop={crop} notify={notify} onSuccess={onSuccess} />
      <HarvestInventoryForm
        crop={crop}
        harvestInventoryOptions={harvestInventoryOptions}
        notify={notify}
        onSuccess={onSuccess}
      />
    </div>
  );
}

function HarvestInventoryForm({
  crop,
  harvestInventoryOptions,
  notify,
  onSuccess,
}: {
  crop: CropItem;
  harvestInventoryOptions: HarvestInventoryOption[];
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const confirmed = await confirm({
      message: `Are you sure you want to record this harvest for ${crop.cropName}?`,
      confirmLabel: "Record Harvest",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      try {
        await harvestCropToInventoryAction(formData);
        onSuccess();
        router.refresh();
        notify("success", "Success - Harvest added to inventory.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Something went wrong."}`);
      }
    });
  }

  return (
    <>
    <form className={styles.harvestPanel} onSubmit={handleSubmit}>
      <div className={styles.harvestHeader}>
        <span className={styles.modalTitleIcon} aria-hidden="true">
          <Archive size={17} />
        </span>
        <div>
          <strong>Harvest to inventory</strong>
          <p>Move harvested produce into the stock list with one recorded movement.</p>
        </div>
      </div>
      <input name="crop_id" type="hidden" value={crop.id} />
      <div className={styles.twoColumn}>
        <InventoryOptionSelect
          label="Inventory item"
          name="inventory_id"
          options={harvestInventoryOptions}
        />
        <Field label="Harvested quantity" min="0.01" name="quantity" required step="0.01" type="number" />
      </div>
      <div className={styles.twoColumn}>
        <Field
          label="Harvest date"
          max={localDateInputValue()}
          name="harvest_date"
          required
          type="date"
          defaultValue={localDateInputValue()}
        />
        <Field label="Remarks" name="remarks" placeholder="Example: first harvest batch" />
      </div>
      {harvestInventoryOptions.length === 0 ? (
        <p className={styles.warningText}>Add an inventory item first before recording harvest output.</p>
      ) : null}
      <button className={styles.primaryAction} disabled={pending || harvestInventoryOptions.length === 0} type="submit">
        <CheckCircle2 size={17} />
        <span>{pending ? "Recording..." : "Record Harvest"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
  );
}

function MaintenanceForm({
  crop,
  notify,
  onSuccess,
}: {
  crop: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const activity = String(formData.get("activity") ?? "this crop activity");

    const confirmed = await confirm({
      message: `Are you sure you want to record ${activity} for ${crop.cropName}?`,
      confirmLabel: "Record Activity",
    });

    if (!confirmed) {
      return;
    }

    startTransition(async () => {
      try {
        await cropMaintenanceAction(formData);
        onSuccess();
        router.refresh();
        notify("success", "Success - Crop activity recorded.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Something went wrong."}`);
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={crop.id} />
      <label>
        <span>Activity notes</span>
        <textarea name="notes" placeholder="Add a note for this activity..." />
      </label>
      <div className={styles.actionGrid}>
        <button className={styles.waterAction} disabled={pending} name="activity" type="submit" value="Watered">
          <Droplets size={17} />
          <span>Water</span>
        </button>
        <button className={styles.primaryAction} disabled={pending} name="activity" type="submit" value="Fertilized">
          <Sprout size={17} />
          <span>Fertilize</span>
        </button>
      </div>
    </form>
    {confirmationDialog}
    </>
  );
}

function InventoryOptionSelect({
  label,
  name,
  options,
}: {
  label: string;
  name: string;
  options: HarvestInventoryOption[];
}) {
  const [open, setOpen] = useState(false);
  const [selectedId, setSelectedId] = useState(options[0]?.id ?? "");
  const selected = options.find((option) => option.id === selectedId);

  function handleSelect(nextId: string) {
    setSelectedId(nextId);
    setOpen(false);
  }

  return (
    <div
      className={`${styles.themedSelect} ${styles.themedSelectForm}`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      <input name={name} type="hidden" value={selectedId} />
      <span className={styles.themedSelectLabel}>{label}</span>
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
        <span className={styles.themedSelectValue}>
          {selected ? `${selected.itemName} · ${selected.unit}` : "No inventory items yet"}
        </span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? (
        <div className={styles.themedSelectMenu}>
          {options.map((option) => {
            const selectedOption = option.id === selectedId;

            return (
              <button
                className={styles.themedSelectOption}
                data-selected={selectedOption ? "true" : "false"}
                key={option.id}
                type="button"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => handleSelect(option.id)}
              >
                <span>{option.itemName} · {option.category} · {option.unit}</span>
                {selectedOption ? <Check size={15} /> : null}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

function CropForm({
  action,
  crop,
  notify,
  onSuccess,
  successMessage,
}: {
  action: (formData: FormData) => void | Promise<void>;
  crop?: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
  successMessage: string;
}) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const confirmed = await confirm({
      message: crop
        ? "Are you sure you want to save these crop record changes?"
        : "Are you sure you want to create this crop record?",
      confirmLabel: crop ? "Save Changes" : "Save Crop",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      try {
        await action(formData);
        onSuccess();
        router.refresh();
        notify("success", successMessage);
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Something went wrong."}`);
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      {crop ? <input name="id" type="hidden" value={crop.id} /> : null}
      <Field label="Crop name" name="crop_name" required defaultValue={crop?.cropName} />
      <div className={styles.twoColumn}>
        <Field
          label="Planting date"
          name="planting_date"
          required
          type="date"
          defaultValue={crop?.plantingDate ?? localDateInputValue()}
        />
        <Field label="Estimated harvest" name="estimated_harvest" type="date" defaultValue={crop?.estimatedHarvest ?? ""} />
      </div>
      <div className={styles.twoColumn}>
        <ThemedSelect label="Growth stage" name="growth_stage" options={stageInputOptions} defaultValue={crop?.growthStage ?? "Seeded"} />
        {crop ? <ThemedSelect label="Status" name="crop_status" options={statusInputOptions} defaultValue={crop.cropStatus} /> : null}
      </div>
      <label>
        <span>Maintenance notes</span>
        <textarea name="maintenance_notes" defaultValue={crop?.maintenanceNotes ?? ""} />
      </label>
      <label className={styles.filePicker}>
        <span>Crop image</span>
        <input accept="image/jpeg,image/png,image/webp" name="image" type="file" />
        <i>
          <ImageIcon size={17} />
          <span>{crop?.imagePath ? "Upload replacement image" : "Choose crop image"}</span>
        </i>
      </label>
      <button className={styles.primaryAction} disabled={pending} type="submit">
        <Sprout size={17} />
        <span>{pending ? "Saving..." : crop ? "Save Changes" : "Save Crop"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
  );
}

function DeleteCropForm({
  crop,
  notify,
  onSuccess,
}: {
  crop: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const confirmed = await confirm({
      title: "Delete crop?",
      message: `Are you sure you want to delete ${crop.cropName}?`,
      confirmLabel: "Delete Crop",
      tone: "danger",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(event.currentTarget);

    startTransition(async () => {
      try {
        await deleteCropAction(formData);
        onSuccess();
        router.refresh();
        notify("success", "Success - Crop record deleted.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Something went wrong."}`);
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={crop.id} />
      <p className={styles.warningText}>Delete {crop.cropName}? This removes the crop from farm monitoring.</p>
      <button className={styles.dangerAction} disabled={pending} type="submit">
        <Trash2 size={17} />
        <span>{pending ? "Deleting..." : "Delete Crop"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
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
      className={`${styles.themedSelect} ${variant === "toolbar" ? styles.themedSelectToolbar : styles.themedSelectForm}`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      {name ? <input name={name} type="hidden" value={selectedValue} /> : null}
      {variant === "form" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
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

function IconAction({
  children,
  label,
  onClick,
  tone,
}: {
  children: ReactNode;
  label: string;
  onClick: () => void;
  tone: "water" | "edit" | "delete";
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
