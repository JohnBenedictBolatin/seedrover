"use client";

import { useEffect, useMemo, useRef, useState, useTransition, type FormEvent, type InputHTMLAttributes, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import {
  Archive,
  CalendarDays,
  Check,
  CheckCircle2,
  CircleSlash2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  CloudRain,
  CloudSun,
  Droplets,
  Edit3,
  Filter,
  History,
  ImageIcon,
  Leaf,
  Plus,
  Search,
  SlidersHorizontal,
  Sprout,
  Thermometer,
  Trash2,
  X,
} from "lucide-react";
import type { CropItem, CropWeatherStatus, HarvestInventoryOption } from "@/lib/crops";
import type { CropOutcome } from "@/lib/crop-outcomes";
import { formatDate, formatDateTime } from "@/lib/format";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import {
  createCropAction,
  cropMaintenanceAction,
  deleteCropAction,
  harvestCropToInventoryAction,
  markCropNotHarvestedAction,
  refreshCropWeatherAction,
  updateCropAction,
} from "@/app/(portal)/crops/actions";
import styles from "@/app/(portal)/crops/page.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";

const stages = ["All", "Seeded", "Germinating", "Vegetative", "Flowering", "Harvest Ready", "Completed"];
const stageInputOptions = stages.slice(1);
const statuses = ["All", "Active", "Needs Attention", "Harvest Ready", "Completed", "Not Harvested"];
const statusInputOptions = statuses.slice(1);
const sortOptions = ["Newest", "Oldest", "Name", "Harvest Soon"];

function displayCropStatus(status: string) {
  return status === "Cancelled" ? "Not Harvested" : status;
}

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
  | { type: "not-harvested"; crop: CropItem }
  | { type: "outcomes" }
  | null;

export function CropsWorkspace({
  crops,
  weather,
  canAddManualCrop,
  harvestInventoryOptions,
  outcomes,
  outcomesError,
}: {
  crops: CropItem[];
  weather: CropWeatherStatus | null;
  canAddManualCrop: boolean;
  harvestInventoryOptions: HarvestInventoryOption[];
  outcomes: CropOutcome[];
  outcomesError: string | null;
}) {
  const [query, setQuery] = useState("");
  const [stage, setStage] = useState("All");
  const [status, setStatus] = useState("All");
  const [plantingDate, setPlantingDate] = useState("");
  const [sort, setSort] = useState("Newest");
  const [modal, setModal] = useState<ModalState>(null);
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);
  const [, startWeatherRefresh] = useTransition();
  const attemptedWeatherRefresh = useRef(false);
  const router = useRouter();

  function notify(tone: AlertTone, text: string) {
    const id = Date.now();
    setAlerts((current) => [...current.slice(-2), { id, tone, text }]);
    window.setTimeout(() => {
      setAlerts((current) => current.filter((alert) => alert.id !== id));
    }, 4200);
  }

  useEffect(() => {
    const fetchedAt = weather?.fetchedAt ? new Date(weather.fetchedAt).getTime() : 0;
    const weatherIsStale = weather?.needsRefresh || !fetchedAt || Date.now() - fetchedAt >= 60 * 60 * 1000;
    if (attemptedWeatherRefresh.current || !weatherIsStale) {
      return;
    }
    attemptedWeatherRefresh.current = true;
    startWeatherRefresh(async () => {
      try {
        await refreshCropWeatherAction();
        router.refresh();
        notify("success", "Weather and crop tasks updated.");
      } catch (error) {
        notify("error", `Weather update failed - ${error instanceof Error ? error.message : "Try again later."}`);
      }
    });
  }, [router, weather?.fetchedAt, weather?.needsRefresh]);

  const filteredCrops = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...crops]
      .filter((crop) => {
        const haystack = `${crop.cropName} ${crop.variety} ${crop.location} ${crop.managerName} ${crop.id}`.toLowerCase();

        return (
          (normalizedQuery.length === 0 || haystack.includes(normalizedQuery)) &&
          (stage === "All" || crop.growthStage === stage) &&
          (status === "All" || displayCropStatus(crop.cropStatus) === status) &&
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
      <section className={styles.weatherStrip} aria-label="Weather and field status">
        <div><CloudSun size={20} /><span>Current weather</span><strong>{weather?.currentCondition ?? "Loading weather"}</strong></div>
        <div><Thermometer size={20} /><span>Temperature</span><strong>{weather?.temperatureC == null ? "--" : `${weather.temperatureC.toFixed(1)}°C`}</strong></div>
        <div><Droplets size={20} /><span>Rain chance</span><strong>{weather?.rainChancePercent == null ? "--" : `${Math.round(weather.rainChancePercent)}% in the next 24 hours`}</strong></div>
        <div><CloudRain size={20} /><span>Next rain</span><strong>{weather?.nextRainWindow ? formatDateTime(weather.nextRainWindow) : "No rain expected in 24 hours"}</strong></div>
      </section>
      <section className={quickActionStyles.quickActions}>
        <div>
          <p className={quickActionStyles.eyebrow}>Quick action</p>
          <h2>Manage crop records</h2>
          <span>Add a documented manual crop when needed or review past crop outcomes.</span>
        </div>
        <div className={styles.cropQuickActions}>
          {canAddManualCrop ? <button className={`${quickActionStyles.recordSaleButton} ${styles.manualCropButton}`} type="button" onClick={() => setModal({ type: "add" })}>
            <span className={`${quickActionStyles.recordSaleText} ${styles.pastCropsButtonText}`}>ADD MANUAL CROP</span>
            <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><Plus size={20} /></span>
          </button> : null}
          <button className={`${quickActionStyles.recordSaleButton} ${styles.pastCropsButton}`} type="button" onClick={() => setModal({ type: "outcomes" })}>
            <span className={`${quickActionStyles.recordSaleText} ${styles.pastCropsButtonText}`}>VIEW PAST CROPS</span>
            <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><History size={20} /></span>
          </button>
        </div>
      </section>

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
        outcomes={outcomes}
        outcomesError={outcomesError}
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
          {displayCropStatus(crop.cropStatus)}
        </span>
      </div>
      <div className={styles.progress}>
        <i style={{ width: `${Math.round(crop.progress * 100)}%` }} />
      </div>
      <dl className={styles.cardFacts}>
        <div>
          <dt>Source / Field</dt>
          <dd>{crop.plantingSource} · {crop.fieldLabel}</dd>
        </div>
        <div>
          <dt>Row coverage</dt>
          <dd>{crop.fieldAreaM2 ? `${crop.fieldAreaM2.toFixed(2)} m²` : "Not measured"} · {crop.completedDrops} drops</dd>
        </div>
        <div>
          <dt>Estimated seeds</dt>
          <dd>{crop.estimatedSeedMin !== null ? `${crop.estimatedSeedMin}-${crop.estimatedSeedMax ?? crop.estimatedSeedMin}` : "Not available"}</dd>
        </div>
        <div>
          <dt>Latest soil</dt>
          <dd>{crop.latestSoilPercent !== null ? `${crop.latestSoilPercent.toFixed(0)}% · ${crop.latestSoilAt ? formatDateTime(crop.latestSoilAt) : "time unavailable"}` : "No linked reading"}</dd>
        </div>
        <div>
          <dt>Next care</dt>
          <dd>{crop.careStatus}</dd>
        </div>
        <div>
          <dt>{crop.cropName.toLowerCase() === "calamansi" && !crop.harvestWindowStart ? "Nursery milestone" : "Harvest window"}</dt>
          <dd>{crop.harvestWindowStart ? `${formatDate(crop.harvestWindowStart)}-${crop.harvestWindowEnd ? formatDate(crop.harvestWindowEnd) : "open"}` : crop.expectedStage}</dd>
        </div>
      </dl>
      <div className={styles.cardActions}>
        <IconAction label="Water" tone="water" onClick={() => onOpen({ type: "details", crop })}>
          <Droplets size={16} />
        </IconAction>
        <IconAction label="Edit" tone="edit" onClick={() => onOpen({ type: "edit", crop })}>
          <Edit3 size={16} />
        </IconAction>
        {crop.cropStatus !== "Completed" && crop.cropStatus !== "Cancelled" ? (
          <IconAction label="Mark not harvested" tone="not-harvested" onClick={() => onOpen({ type: "not-harvested", crop })}>
            <CircleSlash2 size={16} />
          </IconAction>
        ) : null}
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
  outcomes,
  outcomesError,
  onClose,
}: {
  dialog: ModalState;
  harvestInventoryOptions: HarvestInventoryOption[];
  notify: (tone: AlertTone, text: string) => void;
  outcomes: CropOutcome[];
  outcomesError: string | null;
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
    "not-harvested": { title: "Mark Not Harvested", icon: <CircleSlash2 size={18} /> },
    outcomes: { title: "Past Crops", icon: <History size={18} /> },
  }[dialog.type];

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true" role="presentation">
      <section className={`${styles.modal} ${dialog.type === "outcomes" ? styles.outcomesModal : ""}`} role="dialog" aria-modal="true" aria-label={modalMeta.title}>
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
        {dialog.type === "not-harvested" ? <NotHarvestedForm crop={dialog.crop} notify={notify} onSuccess={onClose} /> : null}
        {dialog.type === "outcomes" ? <CropOutcomesPanel outcomes={outcomes} error={outcomesError} /> : null}
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
            {displayCropStatus(crop.cropStatus)}
          </span>
        </div>
      </div>
      <section className={styles.detailSection}>
        <h5>Overview</h5>
        <div className={styles.detailMetrics}>
        <ReadOnly label="Manager" value={crop.managerName} />
        <ReadOnly label="Source" value={crop.plantingSource} />
        <ReadOnly label="Field" value={crop.fieldLabel} />
        <ReadOnly label="Propagation" value={crop.propagationMethod} />
        <ReadOnly label="Planting date" value={formatDate(crop.plantingDate)} />
        <ReadOnly label="Measured area" value={crop.fieldAreaM2 ? `${crop.fieldAreaM2.toFixed(2)} m²` : "Not measured"} />
        <ReadOnly label="Completed drops" value={`${crop.completedDrops}`} />
        <ReadOnly label="Estimated seeds" value={crop.estimatedSeedMin !== null ? `${crop.estimatedSeedMin}-${crop.estimatedSeedMax ?? crop.estimatedSeedMin}` : "Not available"} />
        </div>
      </section>
      <section className={styles.detailSection}>
        <h5>Care Plan</h5>
        <p className={styles.careAdvisory}>{crop.careStatus}. Calculated quantities are planning guidance; verify field conditions before applying water or fertilizer.</p>
        <MaintenanceForm crop={crop} notify={notify} onSuccess={onSuccess} />
      </section>
      <section className={styles.detailSection}>
        <h5>Sensor &amp; Weather</h5>
        <div className={styles.detailMetrics}>
          <ReadOnly label="Latest soil" value={crop.latestSoilPercent !== null ? `${crop.latestSoilPercent.toFixed(1)}%` : "No linked reading"} />
          <ReadOnly label="Reading time" value={crop.latestSoilAt ? formatDateTime(crop.latestSoilAt) : "Not available"} />
          <ReadOnly label="Forecast confidence" value={crop.forecastConfidence} />
          <ReadOnly label="Expected stage" value={crop.expectedStage} />
        </div>
      </section>
      <section className={styles.detailSection}>
        <h5>Activity History</h5>
        <div className={styles.notesPanel}><span>Legacy notes</span><p>{crop.maintenanceNotes}</p></div>
      </section>
      <section className={styles.detailSection}>
        <h5>Harvest</h5>
        <div className={styles.detailMetrics}>
          <ReadOnly label="Window start" value={crop.harvestWindowStart ? formatDate(crop.harvestWindowStart) : crop.cropName.toLowerCase() === "calamansi" ? "Set after transplant" : "Not set"} />
          <ReadOnly label="Window end" value={crop.harvestWindowEnd ? formatDate(crop.harvestWindowEnd) : "Not set"} />
          <ReadOnly label="Confidence" value={crop.forecastConfidence} />
        </div>
      <HarvestInventoryForm
        crop={crop}
        harvestInventoryOptions={harvestInventoryOptions}
        notify={notify}
        onSuccess={onSuccess}
      />
      </section>
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
    const submitter = (event.nativeEvent as SubmitEvent).submitter;
    if (submitter instanceof HTMLButtonElement && submitter.name) {
      formData.set(submitter.name, submitter.value);
    }
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
      <div className={styles.twoColumn}>
        <Field label="Quantity" min="0" name="quantity" placeholder="e.g. 12" step="0.01" type="number" />
        <Field label="Unit" name="unit" placeholder="e.g. liters, grams, trees" />
      </div>
      <div className={styles.twoColumn}>
        <Field label="Material" name="material" placeholder="e.g. irrigation water or 14-14-14" />
        <ThemedSelect label="Observed stage" name="observed_stage" options={["", ...stageInputOptions]} defaultValue="" />
      </div>
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
        <button className={styles.primaryAction} disabled={pending} name="activity" type="submit" value="Inspected">
          <Search size={17} /><span>INSPECT</span>
        </button>
        {crop.cropName.toLowerCase() === "calamansi" ? <button className={styles.primaryAction} disabled={pending} name="activity" type="submit" value="Transplanted">
          <Sprout size={17} /><span>TRANSPLANT</span>
        </button> : null}
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
      <Field label="Crop name" name="crop_name" placeholder="e.g. Romaine lettuce" required defaultValue={crop?.cropName} />
      {!crop ? <>
        <div className={styles.twoColumn}>
          <ThemedSelect label="Crop profile" name="crop_profile_key" options={["calamansi", "sitaw", "peanut"]} defaultValue="sitaw" />
          <Field label="Field or bed" name="field_label" placeholder="e.g. North Field - Row 3" required />
        </div>
        <div className={styles.twoColumn}>
          <Field label="Field area (m²)" min="0" name="field_area_m2" placeholder="e.g. 25" step="0.01" type="number" />
          <ThemedSelect label="Propagation" name="propagation_method" options={["Direct seed", "Seedbed", "Transplant"]} defaultValue="Direct seed" />
        </div>
        <label>
          <span>Manual creation reason</span>
          <textarea name="manual_creation_reason" placeholder="e.g. Rover unavailable during nursery sowing" required />
        </label>
      </> : null}
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
        {crop ? <ThemedSelect label="Status" name="crop_status" options={statusInputOptions} defaultValue={displayCropStatus(crop.cropStatus)} /> : null}
      </div>
      <label>
        <span>Maintenance notes</span>
        <textarea name="maintenance_notes" placeholder="e.g. Watered every morning; monitor leaf growth" defaultValue={crop?.maintenanceNotes ?? ""} />
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

function NotHarvestedForm({ crop, notify, onSuccess }: { crop: CropItem; notify: (tone: AlertTone, text: string) => void; onSuccess: () => void }) {
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const approved = await confirm({
      title: "Mark crop as not harvested?",
      message: `${crop.cropName} will move to Past Crops and will no longer be treated as an active crop.`,
      confirmLabel: "Mark Not Harvested",
      tone: "danger",
    });
    if (!approved) return;

    const formData = new FormData(form);
    startTransition(async () => {
      try {
        await markCropNotHarvestedAction(formData);
        onSuccess();
        router.refresh();
        notify("success", "Success - Crop moved to Past Crops as not harvested.");
      } catch (error) {
        notify("error", `Error - ${error instanceof Error ? error.message : "Unable to mark crop as not harvested."}`);
      }
    });
  }

  return (
    <>
      <form className={styles.formGrid} onSubmit={handleSubmit}>
        <input name="id" type="hidden" value={crop.id} />
        <p className={styles.warningText}>Explain why {crop.cropName} was not harvested. This reason will appear in Past Crops.</p>
        <label><span>Reason</span><textarea name="reason" placeholder="e.g. Pest damage, drought, or crop loss" required /></label>
        <button className={styles.dangerAction} disabled={pending} type="submit"><CircleSlash2 size={17} /><span>{pending ? "UPDATING..." : "MARK NOT HARVESTED"}</span></button>
      </form>
      {confirmationDialog}
    </>
  );
}

function CropOutcomesPanel({
  error,
  outcomes,
}: {
  error: string | null;
  outcomes: CropOutcome[];
}) {
  const [currentPage, setCurrentPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(outcomes.length / 6));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const visibleOutcomes = outcomes.slice((safeCurrentPage - 1) * 6, safeCurrentPage * 6);
  const pageStart = Math.min(Math.max(safeCurrentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);

  return (
    <div className={styles.outcomesWorkspace}>
      {error ? <div className={styles.outcomesNotice}><strong>Past crops are unavailable.</strong><span>{error}</span></div> : null}

      <section className={styles.outcomeSection}>
        <div className={styles.outcomeSectionHeader}><div><span>History</span><h4>Past crop outcomes</h4></div><p>Automatically recorded from crop cards · {outcomes.length} record{outcomes.length === 1 ? "" : "s"}</p></div>
        {outcomes.length === 0 ? (
          <div className={styles.outcomesEmpty}>No crop outcomes have been recorded yet.</div>
        ) : (
          <div className={styles.outcomeTable}>
            <div className={styles.outcomeTableHeader}><span>Crop</span><span>Outcome</span><span>Reason</span><span>Quantity</span><span>Recorded</span></div>
            {visibleOutcomes.map((outcome) => (
              <div className={styles.outcomeRow} key={outcome.id}>
                <strong>{outcome.cropName}</strong>
                <span className={styles.outcomeStatus} data-outcome={outcome.outcome.toLowerCase()}>{outcome.outcome === "Failed" ? "Not Harvested" : outcome.outcome}</span>
                <span>{outcome.reason ?? "No reason recorded"}</span>
                <span>{outcome.quantity === null ? "Not recorded" : `${outcome.quantity} kg`}</span>
                <span>{formatDateTime(outcome.recordedAt)}</span>
              </div>
            ))}
            <div className={styles.outcomePagination} aria-label="Past crops pagination">
              <button aria-label="Previous past crops page" disabled={safeCurrentPage === 1} type="button" onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}><ChevronLeft size={17} /></button>
              <div>{pageNumbers.map((page) => <button aria-current={page === safeCurrentPage ? "page" : undefined} data-active={page === safeCurrentPage ? "true" : "false"} key={page} type="button" onClick={() => setCurrentPage(page)}>{page}</button>)}</div>
              <button aria-label="Next past crops page" disabled={safeCurrentPage === totalPages} type="button" onClick={() => setCurrentPage((page) => Math.min(totalPages, page + 1))}><ChevronRight size={17} /></button>
            </div>
          </div>
        )}
      </section>
    </div>
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
  tone: "water" | "edit" | "delete" | "not-harvested";
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
