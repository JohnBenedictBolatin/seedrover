"use client";

import { useEffect, useMemo, useRef, useState, useTransition, type FormEvent, type InputHTMLAttributes, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import {
  Check,
  ClipboardCheck,
  Apple,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Database,
  Droplets,
  Edit3,
  Eye,
  Filter,
  History,
  BookOpenCheck,
  Leaf,
  Search,
  SlidersHorizontal,
  Sprout,
  Sun,
  Thermometer,
  X,
  CircleSlash2,
} from "lucide-react";
import type { CropActivityRecord, CropItem, CropSensorReading } from "@/lib/crops";
import type { CropOutcome } from "@/lib/crop-outcomes";
import type { PlantingRunHistoryRow } from "@/app/(portal)/crops/actions";
import { formatDate, formatDateTime } from "@/lib/format";
import { sharedWorkflowTerms } from "@/lib/shared-workflow-terms";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { CalendarField } from "@/components/calendar-field";
import { FileUploadField } from "@/components/file-upload-field";
import { ThemedSelect } from "@/components/themed-select";
import {
  getPlantingRunsAction,
  getCropActivityHistoryAction,
  getCropSensorHistoryAction,
  updateCropAction,
} from "@/app/(portal)/crops/actions";
import styles from "@/app/(portal)/crops/page.module.css";
import historyStyles from "@/components/crop-history.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";
import { CropCareForm, TodaysCare, taskActivity } from "@/components/crop-care";

const statuses = ["All", "Active", "Needs Attention", "Harvest Ready"];
const statusInputOptions = ["Active", "Needs Attention", "Harvest Ready"];
const sortOptions = ["Newest", "Name", "Harvest Soon"];

function displayCropStatus(status: string) {
  return status === "Cancelled" ? sharedWorkflowTerms.closedWithoutHarvest : status;
}

type ModalState =
  | { type: "details"; crop: CropItem }
  | { type: "activity"; crop: CropItem; task?: CropItem["tasks"][number]; activity?: "Not Harvested" }
  | { type: "edit"; crop: CropItem }
  | { type: "not-harvested"; crop: CropItem }
  | { type: "outcomes" }
  | { type: "planting-guide" }
  | null;

export function CropsWorkspace({
  children,
  crops,
  outcomes,
  outcomesError,
  initialPlantingRuns,
  plantingRunsTotal,
  plantingRunsError,
}: {
  children: ReactNode;
  crops: CropItem[];
  outcomes: CropOutcome[];
  outcomesError: string | null;
  initialPlantingRuns: PlantingRunHistoryRow[];
  plantingRunsTotal: number;
  plantingRunsError: string | null;
}) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("All");
  const [sort, setSort] = useState("Newest");
  const [managerFilter, setManagerFilter] = useState("All managers");
  const [modal, setModal] = useState<ModalState>(null);
  const [cropTab, setCropTab] = useState<"overview" | "sensors" | "growth" | "activity">("overview");
  const { notify: sendFeedback } = useActionFeedback();
  const lastCropLink = useRef("");
  useEffect(() => {
    const url = new URL(window.location.href);
    const cropId = url.searchParams.get("crop");
    const taskId = url.searchParams.get("task");
    const linkKey = `${cropId ?? ""}:${taskId ?? ""}`;
    if (!cropId || lastCropLink.current === linkKey) return;
    const crop = crops.find((item) => item.id === cropId);
    if (!crop) return;
    lastCropLink.current = linkKey;
    const task = taskId ? crop.tasks.find((item) => item.id === taskId) : undefined;
    queueMicrotask(() => { setCropTab("overview"); setModal(task ? { type: "activity", crop, task } : { type: "details", crop }); });
    url.searchParams.delete("crop");
    url.searchParams.delete("task");
    window.history.replaceState(window.history.state, "", `${url.pathname}${url.search}${url.hash}`);
  }, [crops]);

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  const filteredCrops = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...crops]
      .filter((crop) => {
        const haystack = `${crop.batchCode} ${crop.cropName} ${crop.fieldLabel} ${crop.managerName}`.toLowerCase();

        return (
          (managerFilter === "All managers" || crop.managerName === managerFilter) &&
          (normalizedQuery.length === 0 || haystack.includes(normalizedQuery)) &&
          (status === "All"
            ? !["Completed", "Not Harvested"].includes(displayCropStatus(crop.cropStatus))
            : displayCropStatus(crop.cropStatus) === status)
        );
      })
      .sort((left, right) => {
        if (sort === "Name") {
          return left.cropName.localeCompare(right.cropName);
        }

        if (sort === "Harvest Soon") {
          return (left.harvestWindowStart ?? left.estimatedHarvest ?? "9999-12-31").localeCompare(
            right.harvestWindowStart ?? right.estimatedHarvest ?? "9999-12-31",
          );
        }

        return right.plantingDate.localeCompare(left.plantingDate);
      });
  }, [crops, managerFilter, query, sort, status]);

  const groupedCrops = useMemo(() => {
    return filteredCrops.reduce<Record<string, CropItem[]>>((groups, crop) => {
      const name = crop.cropName.toLowerCase();
      const key = /sitaw|string bean/.test(name)
        ? "Sitaw"
        : /calamansi/.test(name)
          ? "Calamansi"
          : /peanut/.test(name)
            ? "Peanut"
            : "Other / legacy crops";
      groups[key] = [...(groups[key] ?? []), crop];
      return groups;
    }, {});
  }, [filteredCrops]);

  return (
    <>
      <div className={styles.cropDashboardLayout}>
        <div className={styles.cropSummaryArea}>{children}</div>

        <section className={`${quickActionStyles.quickActions} ${styles.cropQuickActionArea}`}>
          <div>
            <p className={quickActionStyles.eyebrow}>Quick action</p>
            <h2>Crop records</h2>
            <span>Review rover-created crop records, including completed and failed crops.</span>
          </div>
          <div className={styles.cropQuickActions}>
            <button className={`${quickActionStyles.recordSaleButton} ${styles.pastCropsButton}`} type="button" onClick={() => setModal({ type: "planting-guide" })}>
              <span className={`${quickActionStyles.recordSaleText} ${styles.pastCropsButtonText}`}>HOW PLANTING WORKS</span>
              <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><BookOpenCheck size={20} /></span>
            </button>
            <button className={`${quickActionStyles.recordSaleButton} ${styles.pastCropsButton}`} type="button" onClick={() => setModal({ type: "outcomes" })}>
              <span className={`${quickActionStyles.recordSaleText} ${styles.pastCropsButtonText}`}>VIEW CROP HISTORY</span>
              <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><History size={20} /></span>
            </button>
          </div>
        </section>

        <aside className={styles.cropCareSidebar} aria-label="Today's crop care">
          <TodaysCare crops={crops} onOpen={(crop, task) => setModal({ type: "activity", crop, task })} />
        </aside>

        <section className={styles.inventoryToolbar}>
          <label className={styles.searchField}>
            <Search size={18} />
            <input
              placeholder="Search crop, batch ID, field..."
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          <ThemedSelect
            icon={<Filter size={17} />}
            label="Status"
            options={statuses}
            value={status}
            variant="toolbar"
            onChange={setStatus}
          />
          <ThemedSelect
            icon={<SlidersHorizontal size={17} />}
            label="Sort"
            options={sortOptions}
            value={sort}
            variant="toolbar"
            onChange={setSort}
          />
          <ThemedSelect icon={<Filter size={17} />} label="Manager" options={["All managers", ...new Set(crops.map((crop) => crop.managerName))]} value={managerFilter} variant="toolbar" onChange={setManagerFilter} />
        </section>

        <div className={styles.cropCollection}>
          {filteredCrops.length === 0 ? (
            <div className={styles.emptyState}>
              <strong>No crop records match the current view.</strong>
              <span>Try changing the search, status, or sort option.</span>
            </div>
          ) : (
            <section className={styles.stockGroups}>
              {Object.entries(groupedCrops).map(([groupKey, groupCrops]) => (
                <CropGroup
                  crops={groupCrops}
                  key={groupKey}
                  name={groupKey}
                  onOpen={(next) => { setCropTab("overview"); setModal(next); }}
                />
              ))}
            </section>
          )}
        </div>
      </div>

      <CropDialog
        dialog={modal}
        cropTab={cropTab}
        onCropTabChange={setCropTab}
        notify={notify}
        onOpen={setModal}
        outcomes={outcomes}
        outcomesError={outcomesError}
        initialPlantingRuns={initialPlantingRuns}
        plantingRunsTotal={plantingRunsTotal}
        plantingRunsError={plantingRunsError}
        onClose={() => setModal(null)}
      />
    </>
  );
}

function CropGroup({
  crops,
  name,
  onOpen,
}: {
  crops: CropItem[];
  name: string;
  onOpen: (modal: ModalState) => void;
}) {
  const rowRef = useRef<HTMLDivElement>(null);
  const icon = name === "Calamansi" ? <Apple size={22} /> : <Sprout size={22} />;

  function scrollCards(direction: "left" | "right") {
    const row = rowRef.current;
    if (!row) return;
    const cardWidth = row.querySelector<HTMLElement>("[data-crop-card]")?.offsetWidth ?? 292;
    row.scrollBy({ behavior: "smooth", left: direction === "right" ? cardWidth + 14 : -(cardWidth + 14) });
  }

  return (
    <div className={styles.stockGroup}>
      <div className={styles.stockGroupHeader}>
        <h3>
          <span className={styles.categoryIcon} aria-hidden="true">{icon}</span>
          <span>{name}</span><span>({crops.length})</span>
        </h3>
        <div className={styles.stockScrollActions} aria-label={`${name} crop scroll controls`}>
          <button aria-label={`Scroll ${name} crops left`} type="button" onClick={() => scrollCards("left")}><ChevronLeft size={18} /></button>
          <button aria-label={`Scroll ${name} crops right`} type="button" onClick={() => scrollCards("right")}><ChevronRight size={18} /></button>
        </div>
      </div>
      <div className={styles.cardRow} ref={rowRef}>
        {crops.map((crop) => <CropCard crop={crop} key={crop.id} onOpen={onOpen} />)}
      </div>
    </div>
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
    <article className={styles.stockCard} data-crop-card>
      <div className={styles.cropHero}>
        {crop.imageUrl ? (
          <Image unoptimized width={720} height={480} alt={`${crop.cropName} crop`} src={crop.imageUrl} />
        ) : (
          <Sprout size={40} />
        )}
      </div>
      <div className={styles.cardTitleRow}>
        <div>
          <span className={styles.itemCode}>{crop.batchCode}</span>
          <h4>{crop.cropName}</h4>
        </div>
        <span className={styles.status} data-status={crop.cropStatus}>
          {displayCropStatus(crop.cropStatus)}
        </span>
      </div>
      <dl className={styles.cardFacts}>
        <div>
          <dt>Stage</dt>
          <dd>{crop.growthStage}</dd>
        </div>
        <div>
          <dt>Field</dt>
          <dd>{crop.fieldLabel}</dd>
        </div>
        <div>
          <dt>Planted</dt>
          <dd>{formatDate(crop.plantingDate)}</dd>
        </div>
      </dl>
      <div className={styles.cropNextCare}>
        <span>NEXT CARE</span>
        <strong>{crop.nextCareTask ?? crop.careStatus}</strong>
        {crop.nextCareDueAt ? <small>Due {formatDate(crop.nextCareDueAt)}</small> : null}
      </div>
      <div className={styles.cardActions}>
        <button
          aria-label={`View details for ${crop.cropName}, ${crop.batchCode}`}
          className={styles.cropDetailsAction}
          type="button"
          onClick={() => onOpen({ type: "details", crop })}
        >
          <Eye size={17} aria-hidden="true" />
          <span>VIEW DETAILS</span>
          <ChevronRight size={16} aria-hidden="true" />
        </button>
      </div>
    </article>
  );
}

function CropDialog({
  dialog,
  cropTab,
  onCropTabChange,
  notify,
  onOpen,
  outcomes,
  outcomesError,
  initialPlantingRuns,
  plantingRunsTotal,
  plantingRunsError,
  onClose,
}: {
  dialog: ModalState;
  cropTab: "overview" | "sensors" | "growth" | "activity";
  onCropTabChange: (tab: "overview" | "sensors" | "growth" | "activity") => void;
  notify: (tone: AlertTone, text: string) => void;
  onOpen: (modal: ModalState) => void;
  outcomes: CropOutcome[];
  outcomesError: string | null;
  initialPlantingRuns: PlantingRunHistoryRow[];
  plantingRunsTotal: number;
  plantingRunsError: string | null;
  onClose: () => void;
}) {
  const dialogRef = useRef<HTMLElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  const cropId = dialog && "crop" in dialog ? dialog.crop.id : null;
  const dialogType = dialog?.type ?? null;
  const [visitedCropTabs, setVisitedCropTabs] = useState<Set<"overview" | "sensors" | "growth" | "activity">>(new Set(["overview"]));
  const [cropDataVersion, setCropDataVersion] = useState(0);
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
  }, [dialogType, cropId]);

  useEffect(() => {
    queueMicrotask(() => { setVisitedCropTabs(new Set(["overview"])); setCropDataVersion((version) => version + 1); });
  }, [cropId]);

  if (!dialog) {
    return null;
  }

  function selectCropTab(tab: "overview" | "sensors" | "growth" | "activity") {
    setVisitedCropTabs((current) => new Set(current).add(tab));
    onCropTabChange(tab);
  }

  const modalMeta = {
    details: { title: dialog.type === "details" ? dialog.crop.cropName : "Crop Details", icon: <Leaf size={18} /> },
    activity: { title: dialog.type === "activity" && dialog.activity === "Not Harvested" ? sharedWorkflowTerms.closeWithoutHarvest : "Record care", icon: <ClipboardCheck size={18} /> },
    edit: { title: "Edit Crop", icon: <Edit3 size={18} /> },
    "not-harvested": { title: sharedWorkflowTerms.closeWithoutHarvest, icon: <CircleSlash2 size={18} /> },
    outcomes: { title: "Crop History", icon: <History size={18} /> },
    "planting-guide": { title: "How Planting Works", icon: <BookOpenCheck size={18} /> },
  }[dialog.type];

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
      }} className={`${styles.modal} ${dialog.type === "details" ? styles.cropWorkspaceModal : ""} ${dialog.type === "outcomes" ? historyStyles.dialog : ""} ${dialog.type === "planting-guide" ? styles.plantingGuideModal : ""}`} role="dialog" aria-modal="true" aria-label={modalMeta.title}>
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {modalMeta.icon}
            </span>
            <span className={styles.cropModalTitleText}>{modalMeta.title}{dialog.type === "details" ? <small className={styles.cropModalIdentity}>{dialog.crop.fieldLabel} · {dialog.crop.batchCode}</small> : null}</span>
            {dialog.type === "details" ? <span className={styles.status} data-status={dialog.crop.cropStatus}>{displayCropStatus(dialog.crop.cropStatus)}</span> : null}
          </h3>
          <button aria-label="Close modal" className={styles.modalCloseButton} type="button" onClick={onClose}>
            <X size={18} />
          </button>
        </header>

        {dialog.type === "details" ? <nav className={styles.cropDetailTabs} role="tablist" aria-label="Crop information" onKeyDown={(event) => {
          if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
          event.preventDefault();
          const tabs = ["overview", "sensors", "growth", "activity"] as const;
          const current = tabs.indexOf(cropTab);
          const next = event.key === "Home" ? 0 : event.key === "End" ? tabs.length - 1 : (current + (event.key === "ArrowRight" ? 1 : tabs.length - 1)) % tabs.length;
          selectCropTab(tabs[next]);
          requestAnimationFrame(() => document.getElementById(`crop-tab-${tabs[next]}`)?.focus());
        }}>
          {([ ["overview", "OVERVIEW"], ["sensors", "SENSORS"], ["growth", "GROWTH JOURNEY"], ["activity", "ACTIVITY"] ] as const).map(([tab, label]) => <button key={tab} id={`crop-tab-${tab}`} role="tab" aria-selected={cropTab === tab} aria-controls={tab === "overview" ? "crop-tabpanel" : `crop-tabpanel-${tab}`} tabIndex={cropTab === tab ? 0 : -1} type="button" onClick={() => selectCropTab(tab)}>{label}</button>)}
        </nav> : null}

        {dialog.type === "details" ? <div className={styles.modalBody}>
          {visitedCropTabs.has("overview") ? <div hidden={cropTab !== "overview"} id="crop-tabpanel" role="tabpanel" aria-labelledby="crop-tab-overview"><CropDetails crop={dialog.crop} /></div> : null}
          {visitedCropTabs.has("sensors") ? <div hidden={cropTab !== "sensors"} id="crop-tabpanel-sensors" role="tabpanel" aria-labelledby="crop-tab-sensors"><CropSensorHistoryPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} /></div> : null}
          {visitedCropTabs.has("growth") ? <div hidden={cropTab !== "growth"} id="crop-tabpanel-growth" role="tabpanel" aria-labelledby="crop-tab-growth"><CropGrowthJourneyPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} /></div> : null}
          {visitedCropTabs.has("activity") ? <div hidden={cropTab !== "activity"} id="crop-tabpanel-activity" role="tabpanel" aria-labelledby="crop-tab-activity"><CropActivityHistoryPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} /></div> : null}
        </div> : null}
        {dialog.type === "details" ? <div className={`${styles.cropWorkspaceFooter} ${styles.modalFooterActions}`}>
          {dialog.crop.cropStatus !== "Completed" && dialog.crop.cropStatus !== "Cancelled" ? <>
            <button className={`${styles.dangerAction} ${styles.cancelCropButton}`} type="button" onClick={() => onOpen({ type: "activity", crop: dialog.crop, activity: "Not Harvested" })}><CircleSlash2 size={17} aria-hidden="true" /><span>{sharedWorkflowTerms.closeWithoutHarvest}</span></button>
            <div className={styles.cropFooterActions}>
            <button className={styles.primaryAction} type="button" onClick={() => onOpen({ type: "activity", crop: dialog.crop })}><ClipboardCheck size={17} aria-hidden="true" /><span>RECORD ACTIVITY</span></button>
            </div>
          </> : null}
        </div> : null}
        {dialog.type === "activity" ? (
          <CropCareForm
            crop={dialog.crop}
            task={dialog.task}
            initialActivity={dialog.activity ?? (dialog.task ? taskActivity(dialog.task) : undefined)}
            notify={notify}
            onCancel={() => onOpen({ type: "details", crop: dialog.crop })}
            onSuccess={() => {
              setCropDataVersion((version) => version + 1);
              onCropTabChange("overview");
              onOpen({ type: "details", crop: dialog.crop });
            }}
          />
        ) : null}
        {dialog.type === "edit" ? (
          <CropForm
            action={updateCropAction}
            crop={dialog.crop}
            notify={notify}
            onCancel={() => onOpen({ type: "details", crop: dialog.crop })}
            onSuccess={() => onOpen({ type: "details", crop: dialog.crop })}
            successMessage="Crop record updated."
          />
        ) : null}
        {dialog.type === "outcomes" ? <CropOutcomesPanel
          outcomes={outcomes}
          error={outcomesError}
          initialPlantingRuns={initialPlantingRuns}
          plantingRunsTotal={plantingRunsTotal}
          plantingRunsError={plantingRunsError}
        /> : null}
        {dialog.type === "planting-guide" ? <PlantingGuidePanel /> : null}
      </section>
    </div>
  );
}

function CropDetails({ crop }: { crop: CropItem }) {
  const growthStages = crop.stages;
  const farmNotes = crop.maintenanceNotes?.trim() && crop.maintenanceNotes !== "No notes recorded."
    ? crop.maintenanceNotes.trim()
    : null;
  const stagePosition = stageIndex(crop.growthStage, growthStages);
  const progress = stagePosition >= 0
    ? Math.round(((stagePosition + 1) / Math.max(1, growthStages.length)) * 100)
    : 0;

  return (
    <div className={styles.detailsGrid}>
      <div className={styles.detailsTop}>
        <div className={styles.detailImagePanel}>
          {crop.imageUrl ? (
            <Image unoptimized width={900} height={600} alt={`${crop.cropName} crop`} src={crop.imageUrl} />
          ) : (
            <div>
              <Sprout size={42} />
              <span>No crop image uploaded yet.</span>
            </div>
          )}
        </div>
        <div className={styles.detailSummary}>
          <section className={`${styles.detailSection} ${styles.nextCareSection}`}>
            <span className={styles.detailEyebrow}>NEXT CARE</span>
            <h4>{crop.nextCareTask ?? crop.careStatus ?? "No scheduled care"}</h4>
            <p>{crop.careStatus}{crop.nextCareDueAt ? ` · Due ${formatDate(crop.nextCareDueAt)}` : ""}</p>
          </section>
          <div className={styles.detailMetrics}>
            <ReadOnly icon={<CalendarDays size={18} />} label="Planted" value={formatDate(crop.plantingDate)} />
            <ReadOnly icon={<Sprout size={18} />} label="Observed stage" value={crop.growthStage} />
            <ReadOnly
              icon={<Droplets size={18} />}
              label="Latest soil check"
              value={crop.latestSoilPercent !== null ? `${crop.latestSoilPercent.toFixed(0)}%` : "Unavailable"}
              detail={crop.latestSoilAt == null
                ? "No fresh verified hardware reading"
                : `${crop.latestSoilSource ?? "Source unavailable"} · ${formatDateTime(crop.latestSoilAt)} · Fresh · ${crop.latestSoilCalibrated === true ? `calibration ${crop.latestSoilCalibrationVersion ?? "version unavailable"}` : crop.latestSoilCalibrated === false ? "probe not calibrated" : "calibration status unavailable"}`}
            />
          </div>
        </div>
      </div>
      <div className={styles.detailsLowerGrid} data-has-notes={farmNotes ? "true" : "false"}>
        <section className={styles.cropProgressPanel} aria-label="Crop growth progress">
          <div className={styles.cropProgressHeader}>
            <div>
              <span>GROWTH PROGRESS</span>
              <strong>{crop.growthStage}</strong>
            </div>
            <b>{progress}%</b>
          </div>
          <div
            className={styles.cropProgressTrack}
            role="progressbar"
            aria-label="Recorded growth stage progress"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={progress}
          >
            <i style={{ width: `${progress}%` }} />
          </div>
          <small>{stagePosition >= 0 ? `Stage ${stagePosition + 1} of ${growthStages.length} · based on the recorded stage` : "Progress is unavailable because the recorded stage is not recognized."}</small>
        </section>
        {farmNotes ? (
          <section className={styles.detailSection}>
            <h5>FARM NOTES</h5>
            <p className={styles.cropFarmNotes}>{farmNotes}</p>
          </section>
        ) : null}
      </div>
    </div>
  );
}

function CropGrowthJourneyPanel({ crop }: { crop: CropItem }) {
  const [activities, setActivities] = useState<CropActivityRecord[]>([]);
  const [expandedPhotoStages, setExpandedPhotoStages] = useState<Set<string>>(() => new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const currentStageIndex = crop.cropStatus === "Cancelled"
    ? -1
    : stageIndex(crop.growthStage, crop.stages);
  const stages = crop.stages;
  const activityByStage = useMemo(() => {
    const byStage = new Map<string, CropActivityRecord>();

    for (const activity of activities) {
      if (!activity.observedStage) continue;
      const key = normalizeStage(activity.observedStage);
      if (!byStage.has(key)) byStage.set(key, activity);
    }

    return byStage;
  }, [activities]);

  const photosByStage = useMemo(() => {
    const byStage = new Map<string, { photo: CropActivityRecord["photos"][number]; activity: CropActivityRecord }[]>();

    for (const activity of activities) {
      if (!activity.observedStage || !activity.photos.length) continue;
      const key = normalizeStage(activity.observedStage);
      const stagePhotos = byStage.get(key) ?? [];
      byStage.set(key, [...stagePhotos, ...activity.photos.map((photo) => ({ photo, activity }))]);
    }

    return byStage;
  }, [activities]);

  useEffect(() => {
    let active = true;

    getCropActivityHistoryAction(crop.id)
      .then((result) => {
        if (active) setActivities(result);
      })
      .catch((caught: unknown) => {
        if (active) setError(caught instanceof Error ? caught.message : "Crop growth history could not be loaded.");
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [crop.id]);

  return (
    <div className={styles.growthJourneyPanel}>
      <div className={styles.growthJourneyIntro}>
        <span className={styles.growthJourneyCurrent}><small>CURRENT STAGE</small><strong>{crop.growthStage}</strong></span>
      </div>

      {loading ? <div className={styles.growthJourneyMessage}>Loading growth history...</div> : null}
      {error ? <div className={styles.growthJourneyMessage}>{error}</div> : null}

      {!loading && !error ? (
        <div className={styles.growthTimeline}>
          {stages.map((stage, index) => {
            const activity = activityByStage.get(normalizeStage(stage));
            const stagePhotos = photosByStage.get(normalizeStage(stage)) ?? [];
            const photosExpanded = expandedPhotoStages.has(normalizeStage(stage));
            const observed = Boolean(activity);
            const current = index === currentStageIndex;

            return (
              <div className={`${styles.growthTimelineItem} ${observed ? styles.growthTimelineItemCompleted : ""} ${current ? styles.growthTimelineItemCurrent : ""}`} key={stage}>
                <div className={styles.growthTimelineTrack} aria-hidden="true">
                  <span className={styles.growthTimelinePoint}>{observed ? <Check size={20} strokeWidth={4} /> : index + 1}</span>
                </div>
                <div className={styles.growthStageRow}>
                  <div>
                    <strong>{stage}</strong>
                    <small>{activity ? formatDateTime(activity.performedAt) : current ? "Current stage in crop record" : "No observation recorded"}</small>
                  </div>
                  <span className={styles.growthStageStatus}>{observed ? "Observed" : current ? "Current stage" : "Not recorded"}</span>
                  {activity ? <p>{activity.activityType}{activity.notes ? ` · ${activity.notes}` : ""}</p> : null}
                  {observed && stagePhotos.length ? (
                    <button
                      aria-expanded={photosExpanded}
                      aria-controls={`growth-photos-${crop.id}-${index}`}
                      className={`${styles.secondaryAction} ${styles.growthImageButton}`}
                      type="button"
                      onClick={() => setExpandedPhotoStages((currentPhotos) => {
                        const next = new Set(currentPhotos);
                        const key = normalizeStage(stage);
                        if (next.has(key)) next.delete(key);
                        else next.add(key);
                        return next;
                      })}
                    >
                      <Eye size={15} aria-hidden="true" />
                      <span>{photosExpanded ? "Hide Growth Image" : "See Growth Image"}</span>
                    </button>
                  ) : null}
                  {stagePhotos.length ? (
                    <div className={styles.growthStagePhotos} hidden={!photosExpanded} id={`growth-photos-${crop.id}-${index}`} aria-label={`${stage} observation photos`}>
                      {stagePhotos.map(({ activity: photoActivity, photo }, photoIndex) => (
                        <a href={photo.url} key={photo.path} target="_blank" rel="noreferrer" aria-label={`Open ${stage} growth photo ${photoIndex + 1}, recorded ${formatDateTime(photoActivity.performedAt)}`}>
                          <Image unoptimized width={168} height={126} src={photo.url} alt={`${stage} growth observation photo, recorded ${formatDateTime(photoActivity.performedAt)}`} />
                        </a>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>
            );
          })}
        </div>
      ) : null}

      {crop.cropStatus === "Cancelled" ? <div className={styles.growthJourneyNotice}>This crop is closed. Only stages with recorded observations are marked above.</div> : null}
    </div>
  );
}

function normalizeStage(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

function stageIndex(value: string, stages: string[]) {
  const normalized = normalizeStage(value);
  const exactIndex = stages.findIndex((stage) => normalizeStage(stage) === normalized);
  if (exactIndex >= 0) return exactIndex;

  return stages.findIndex((stage) => normalized.includes(normalizeStage(stage)) || normalizeStage(stage).includes(normalized));
}

function cropActivityDetails(activity: CropActivityRecord) {
  const note = (activity.notes ?? "")
    .replace(/seed count is estimated\.?/gi, "")
    .replace(/\s+/g, " ")
    .trim();
  const plantingCycleMatch = activity.source === "Rover" && activity.activityType === "Planted"
    ? note.match(/(\d+)\s+of\s+(\d+)\s+planned\s+(?:planting\s+)?(?:gate cycles|gate pulses)\s+completed\.?/i)
    : null;
  const cleanNote = note
    .replace(/\d+\s+of\s+\d+\s+planned\s+(?:planting\s+)?(?:gate cycles|gate pulses)\s+completed\.?/i, "")
    .replace(/[.\s]+$/, "")
    .trim();

  const details = activity.source === "Rover" && activity.activityType === "Planted"
    ? [
        plantingCycleMatch
          ? `${plantingCycleMatch[1]} of ${plantingCycleMatch[2]} planting cycles completed`
          : activity.quantity !== null
            ? `${activity.quantity} planting cycles recorded`
            : "Planting run recorded",
        activity.observedStage ? `Stage: ${activity.observedStage}` : null,
      ]
    : [
        activity.quantity !== null ? `${activity.quantity}${activity.unit ? ` ${activity.unit}` : ""}` : null,
        activity.material,
        activity.observedStage ? `Stage: ${activity.observedStage}` : null,
      ];

  return {
    summary: details.filter(Boolean).join(" · ") || "—",
    note: cleanNote || null,
  };
}

function CropActivityHistoryPanel({ crop }: { crop: CropItem }) {
  const [activities, setActivities] = useState<CropActivityRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const pageSize = 5;
  const totalPages = Math.max(1, Math.ceil(activities.length / pageSize));
  const visibleActivities = activities.slice((page - 1) * pageSize, page * pageSize);

  useEffect(() => {
    let active = true;

    getCropActivityHistoryAction(crop.id)
      .then((result) => {
        if (active) setActivities(result);
      })
      .catch((caught: unknown) => {
        if (active) {
          setError(caught instanceof Error ? caught.message : "Activity history could not be loaded.");
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [crop.id]);

  return (
    <div className={styles.activityHistoryPanel}>
      <div className={styles.historyViewHeading}><span>ACTIVITY HISTORY</span><strong>{activities.length} record{activities.length === 1 ? "" : "s"}</strong></div>

      {loading ? <div className={styles.sensorEmptyState}>Loading crop activity history...</div> : null}
      {error ? <div className={styles.sensorErrorState}>{error}</div> : null}
      {!loading && !error && activities.length === 0 ? (
        <div className={styles.sensorEmptyState}>
          <History size={28} />
          <strong>No activities have been recorded for this crop.</strong>
        </div>
      ) : null}

      {!loading && !error && activities.length > 0 ? (
        <div className={styles.cropActivityTable} role="table" aria-label="Crop activity history">
          <div className={styles.cropActivityHeader} role="row" aria-hidden="true">
            <span>Activity</span><span>Details</span><span>Recorded</span><span>By</span>
          </div>
          {visibleActivities.map((activity) => {
            const details = cropActivityDetails(activity);
            return (
              <div className={styles.cropActivityRow} role="row" key={activity.id}>
                <div role="cell" data-label="Activity">
                  <strong>{activity.activityType}</strong>
                </div>
                <div role="cell" data-label="Details">
                  <span className={styles.activityDetailSummary}>{details.summary}</span>
                  {details.note ? <small>{details.note}</small> : null}
                </div>
                <time role="cell" data-label="Recorded">{formatDateTime(activity.performedAt)}</time>
                <span role="cell" data-label="By">{activity.performedBy}</span>
              </div>
            );
          })}
        </div>
      ) : null}

      {!loading && !error && activities.length > pageSize ? <SimplePagination page={page} totalPages={totalPages} onPageChange={setPage} label="Activity history" /> : null}
    </div>
  );
}

function CropSensorHistoryPanel({ crop }: { crop: CropItem }) {
  const [readings, setReadings] = useState<CropSensorReading[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const pageSize = 6;

  useEffect(() => {
    let active = true;

    getCropSensorHistoryAction(crop.id)
      .then((result) => {
        if (active) setReadings(result);
      })
      .catch((caught: unknown) => {
        if (active) {
          setError(caught instanceof Error ? caught.message : "Sensor history could not be loaded.");
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [crop.id]);

  const latest = readings.find((reading) => reading.provenanceStatus === "verified_hardware" && reading.fresh);
  const visibleReadings = readings.slice((page - 1) * pageSize, page * pageSize);
  const totalPages = Math.max(1, Math.ceil(readings.length / pageSize));

  return (
    <div className={styles.sensorHistoryPanel}>
      <div className={styles.historyViewHeading}><span>SENSOR READINGS</span><strong>{readings.length >= 100 ? "LATEST 100 READINGS" : `${readings.length} READING${readings.length === 1 ? "" : "S"}`}</strong></div>

      {loading ? <div className={styles.sensorEmptyState}>Loading crop sensor data...</div> : null}
      {error ? <div className={styles.sensorErrorState}>{error}</div> : null}
      {!loading && !error && readings.length === 0 ? (
        <div className={styles.sensorEmptyState}>
          <Database size={28} />
          <strong>No sensor readings are linked to this crop.</strong>
          <span>Legacy and manually added crops may not have rover sensor data.</span>
        </div>
      ) : null}

      {latest ? (
        <>
          <section className={styles.sensorSummarySection}>
            <div className={styles.sensorSectionHeading}>
              <div>
                <h5>Latest sensor check</h5>
              </div>
              <time>{latest.source} · {formatDateTime(latest.recordedAt)} · Fresh · {latest.soilMoistureCalibrated === true ? `Moisture calibration ${latest.calibrationVersion ?? "version unavailable"}` : latest.soilMoistureCalibrated === false ? "Moisture % unavailable: probe not calibrated" : "Moisture calibration status unavailable"}</time>
            </div>
            <div className={styles.sensorSummaryGrid}>
              <SensorValue icon={<Droplets size={19} />} label="Soil moisture" unit="%" value={latest.soilMoisture} />
              <SensorValue icon={<Thermometer size={19} />} label="Soil temperature" unit="°C" value={latest.soilTemperature} />
              <SensorValue icon={<Sun size={19} />} label="Air temperature" unit="°C" value={latest.environmentalTemperature} />
              <SensorValue icon={<Droplets size={19} />} label="Humidity" unit="%" value={latest.humidity} />
            </div>
          </section>
          <section className={styles.sensorHistorySection}>
            <div className={styles.sensorSectionHeading}>
              <div>
                <h5>Reading history</h5>
              </div>
            </div>
            <div className={styles.sensorHistoryTable}>
              <div className={styles.sensorHistoryHeader} aria-hidden="true">
                <span>Recorded</span><span>Soil</span><span>Soil temp</span><span>Air temp</span><span>Humidity</span><span>Source / trust</span>
              </div>
              {visibleReadings.map((reading) => (
                <div className={styles.sensorHistoryRow} key={reading.id}>
                  <time>{formatDateTime(reading.recordedAt)}</time>
                  <span data-label="Soil moisture / raw ADC">{formatSensorValue(reading.soilMoisture, "%")}{reading.soilRaw == null ? "" : ` · raw ADC ${reading.soilRaw}`}</span>
                  <span data-label="Soil temp">{formatSensorValue(reading.soilTemperature, "°C")}</span>
                  <span data-label="Air temp">{formatSensorValue(reading.environmentalTemperature, "°C")}</span>
                  <span data-label="Humidity">{formatSensorValue(reading.humidity, "%")}</span>
                  <span data-label="Source / trust">{reading.source} · {reading.provenanceStatus === "verified_hardware" ? "Verified hardware" : reading.provenanceStatus === "demo" ? "Demo" : reading.provenanceStatus === "simulated" ? "Simulated" : "Unverified"} · {reading.fresh ? "Fresh" : "Stale"}{reading.soilMoistureCalibrated === true ? ` · calibrated ${reading.calibrationVersion ?? "version unavailable"}` : reading.soilMoistureCalibrated === false ? " · moisture % unavailable, uncalibrated" : " · calibration status unavailable"}</span>
                </div>
              ))}
            </div>
            {readings.length > pageSize ? <SimplePagination page={page} totalPages={totalPages} onPageChange={setPage} label="Sensor history" /> : null}
          </section>
        </>
      ) : null}

    </div>
  );
}

function SensorValue({ icon, label, unit, value }: { icon: ReactNode; label: string; unit: string; value: number | null }) {
  return (
    <div className={styles.sensorValueCard}>
      <span>{icon}</span>
      <div>
        <small>{label}</small>
        <strong>{formatSensorValue(value, unit)}</strong>
      </div>
    </div>
  );
}

function formatSensorNumber(value: number | null) {
  return value !== null && Number.isFinite(value) ? value.toFixed(1) : "Not available";
}

function formatSensorValue(value: number | null, unit: string) {
  return value !== null && Number.isFinite(value) ? `${formatSensorNumber(value)}${unit}` : "Unavailable";
}

function SimplePagination({ page, totalPages, onPageChange, label }: { page: number; totalPages: number; onPageChange: (page: number) => void; label: string }) {
  return <nav className={styles.outcomePagination} aria-label={label}>
    <button aria-label="Previous page" disabled={page <= 1} type="button" onClick={() => onPageChange(Math.max(1, page - 1))}><ChevronLeft size={17} /></button>
    <span>PAGE {page} OF {totalPages}</span>
    <button aria-label="Next page" disabled={page >= totalPages} type="button" onClick={() => onPageChange(Math.min(totalPages, page + 1))}><ChevronRight size={17} /></button>
  </nav>;
}

function CropForm({
  action,
  crop,
  notify,
  onCancel,
  onSuccess,
  successMessage,
}: {
  action: (formData: FormData) => void | Promise<void>;
  crop: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onCancel: () => void;
  onSuccess: () => void;
  successMessage: string;
}) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const formData = new FormData(form);

    startTransition(async () => {
      try {
        await action(formData);
        onSuccess();
        router.refresh();
        notify("success", successMessage);
      } catch (error) {
        notify("error", error instanceof Error ? error.message : "Something went wrong.");
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={crop.id} />
      <Field label="Crop name" name="crop_name" placeholder="e.g. Romaine lettuce" required defaultValue={crop?.cropName} />
      <div className={styles.twoColumn}>
        <CalendarField
          label="Planting date"
          name="planting_date"
          required
          defaultValue={crop.plantingDate}
        />
        <CalendarField label="Estimated harvest" name="estimated_harvest" defaultValue={crop?.estimatedHarvest ?? ""} />
      </div>
      <div className={styles.twoColumn}>
        <ThemedSelect label="Growth stage" name="growth_stage" options={crop?.stages ?? []} defaultValue={crop?.growthStage ?? "Seeded"} />
        <ThemedSelect label="Status" name="crop_status" options={statusInputOptions} defaultValue={displayCropStatus(crop.cropStatus)} />
      </div>
      <label>
        <span>Maintenance notes</span>
        <textarea name="maintenance_notes" placeholder="e.g. Watered every morning; monitor leaf growth" defaultValue={crop?.maintenanceNotes ?? ""} />
      </label>
      <FileUploadField
        accept="image/jpeg,image/png,image/webp"
        helperText="JPG, PNG or WEBP"
        label="Crop image"
        name="image"
        prompt={crop?.imagePath ? "Choose replacement image" : "Choose crop image"}
      />
      <div className={styles.modalFooterActions}>
        <button className={styles.secondaryAction} disabled={pending} type="button" onClick={onCancel}>CANCEL</button>
        <button className={styles.primaryAction} disabled={pending} type="submit">
          <Sprout size={17} />
          <span>{pending ? "SAVING..." : "SAVE CHANGES"}</span>
        </button>
      </div>
    </form>
    </>
  );
}

function CropOutcomesPanel({
  error,
  outcomes,
  initialPlantingRuns,
  plantingRunsTotal,
  plantingRunsError,
}: {
  error: string | null;
  outcomes: CropOutcome[];
  initialPlantingRuns: PlantingRunHistoryRow[];
  plantingRunsTotal: number;
  plantingRunsError: string | null;
}) {
  const [tab, setTab] = useState<"crops" | "runs">("crops");
  const [currentPage, setCurrentPage] = useState(1);
  const [runPage, setRunPage] = useState(1);
  const [runRows, setRunRows] = useState(initialPlantingRuns);
  const [runTotal, setRunTotal] = useState(plantingRunsTotal);
  const [runError, setRunError] = useState(plantingRunsError);
  const [selectedRun, setSelectedRun] = useState<PlantingRunHistoryRow | null>(null);
  const [isLoadingRuns, startTransition] = useTransition();
  const bodyRef = useRef<HTMLDivElement>(null);
  const historyPageSize = 5;
  const totalPages = Math.max(1, Math.ceil(outcomes.length / historyPageSize));
  const safeCurrentPage = Math.min(currentPage, totalPages);
  const visibleOutcomes = outcomes.slice((safeCurrentPage - 1) * historyPageSize, safeCurrentPage * historyPageSize);

  useEffect(() => {
    bodyRef.current?.scrollTo({ top: 0 });
  }, [tab, currentPage, runPage, selectedRun]);

  function loadRunPage(page: number) {
    if (isLoadingRuns) return;
    startTransition(async () => {
      try {
        let result = await getPlantingRunsAction(page);
        if (result.error) throw new Error(result.error);
        const availablePage = Math.min(page, Math.max(1, Math.ceil(result.total / historyPageSize)));
        if (availablePage !== page) {
          result = await getPlantingRunsAction(availablePage);
          if (result.error) throw new Error(result.error);
        }
        setRunRows(result.rows);
        setRunTotal(result.total);
        setRunError(null);
        setRunPage(availablePage);
      } catch (requestError) {
        setRunError(requestError instanceof Error ? requestError.message : "Could not load planting runs.");
      }
    });
  }

  return (
    <div className={historyStyles.workspace}>
      <nav className={historyStyles.tabs} role="tablist" aria-label="Crop history sections" onKeyDown={(event) => {
        if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
        event.preventDefault();
        const nextTab = event.key === "Home" ? "crops" : event.key === "End" ? "runs" : tab === "crops" ? "runs" : "crops";
        setTab(nextTab);
        requestAnimationFrame(() => document.getElementById(`crop-history-tab-${nextTab}`)?.focus());
      }}>
        <button id="crop-history-tab-crops" aria-controls="crop-history-panel" aria-selected={tab === "crops"} role="tab" tabIndex={tab === "crops" ? 0 : -1} type="button" onClick={() => setTab("crops")}>CROP OUTCOMES</button>
        <button id="crop-history-tab-runs" aria-controls="crop-history-panel" aria-selected={tab === "runs"} role="tab" tabIndex={tab === "runs" ? 0 : -1} type="button" onClick={() => setTab("runs")}>PLANTING RUNS</button>
      </nav>

      <section className={historyStyles.panel} id="crop-history-panel" role="tabpanel" aria-labelledby={`crop-history-tab-${tab}`}>
        <div className={historyStyles.body} ref={bodyRef} tabIndex={0} aria-label={tab === "crops" ? "Crop outcomes" : "Planting runs"} aria-busy={tab === "runs" && isLoadingRuns}>
          {tab === "crops" ? <>
            {error ? <div className={historyStyles.notice} role="alert">Crop history is unavailable. {error}</div> : null}
            {!error && outcomes.length === 0 ? <div className={historyStyles.empty}>No crop outcomes have been recorded yet.</div> : null}
            {visibleOutcomes.length > 0 ? <table className={`${historyStyles.table} ${historyStyles.outcomesTable}`} aria-label="Crop outcomes">
              <colgroup><col /><col /><col /><col /><col /></colgroup>
              <thead><tr><th scope="col">Crop</th><th scope="col">Outcome</th><th scope="col">Reason / notes</th><th scope="col" className={historyStyles.numeric}>Quantity</th><th scope="col">Recorded</th></tr></thead>
              <tbody>{visibleOutcomes.map((outcome) => <tr key={outcome.id}>
                <td data-label="Crop"><strong>{outcome.cropName}</strong></td>
                <td data-label="Outcome"><HistoryBadge label={outcome.outcome === "Failed" ? sharedWorkflowTerms.closedWithoutHarvest : outcome.outcome} /></td>
                <td data-label="Reason / notes">{outcome.reason === "Harvest recorded from the crop card." ? "—" : outcome.reason || "—"}</td>
                <td data-label="Quantity" className={historyStyles.numeric}>{outcome.quantity === null ? "—" : `${outcome.quantity} kg`}</td>
                <td data-label="Recorded"><time dateTime={outcome.recordedAt}>{formatDateTime(outcome.recordedAt)}</time><small>By {outcome.recordedByName}</small></td>
              </tr>)}</tbody>
            </table> : null}
          </> : selectedRun ? <div className={historyStyles.details}>
            <button className={historyStyles.backButton} type="button" onClick={() => setSelectedRun(null)}><ChevronLeft size={16} /> BACK TO PLANTING RUNS</button>
            <div className={historyStyles.detailIdentity}><strong>{selectedRun.seedName}</strong><small>{selectedRun.fieldLabel || "Field not labeled"} · RUN {selectedRun.runId?.slice(0, 8).toUpperCase() ?? selectedRun.id.slice(0, 8).toUpperCase()}</small></div>
            <SavedRunTimeline run={selectedRun} />
          </div> : <>
            {runError ? <div className={historyStyles.notice} role="alert">Planting run history is unavailable. {runError}</div> : null}
            {!runError && runRows.length === 0 ? <div className={historyStyles.empty}>No rover planting runs have been recorded yet.</div> : null}
            {runRows.length > 0 ? <table className={`${historyStyles.table} ${historyStyles.runsTable}`} aria-label="Planting runs">
              <colgroup><col /><col /><col /><col /><col /><col /></colgroup>
              <thead><tr><th scope="col">Seed / field</th><th scope="col">Result</th><th scope="col" className={historyStyles.numeric}>Cycles</th><th scope="col">Recorded by</th><th scope="col">Started</th><th scope="col" className={historyStyles.actions}>Actions</th></tr></thead>
              <tbody>{runRows.map((run) => <tr key={run.id}>
                <td data-label="Seed / field"><strong>{run.seedName}</strong><small>{run.fieldLabel || "Field not labeled"}</small></td>
                <td data-label="Result"><HistoryBadge label={run.confirmationOutcome === "Pending" ? "Needs Review" : run.confirmationOutcome} />{run.confirmationOutcome === "Legacy" ? <small>{run.plantingStatus}</small> : null}</td>
                <td data-label="Cycles" className={historyStyles.numeric}>{run.completedCycles}/{run.targetCycles ?? "—"}</td>
                <td data-label="Recorded by">{run.operatorName}</td>
                <td data-label="Started">{run.startedAt ? <time dateTime={run.startedAt}>{formatDateTime(run.startedAt)}</time> : "—"}</td>
                <td data-label="Actions" className={historyStyles.actions}><button className={historyStyles.viewButton} type="button" disabled={isLoadingRuns} title="View planting run" aria-label={`View ${run.seedName} planting run ${run.runId?.slice(0, 8) ?? run.id.slice(0, 8)}`} onClick={() => setSelectedRun(run)}><Eye size={17} aria-hidden="true" /></button></td>
              </tr>)}</tbody>
            </table> : null}
          </>}
        </div>

        {tab === "runs" && selectedRun ? <footer className={historyStyles.footer}>
          {selectedRun.cropId ? <a className={historyStyles.relatedCrop} href={`/crops?crop=${encodeURIComponent(selectedRun.cropId)}`}>OPEN RELATED CROP <ChevronRight size={16} /></a> : null}
        </footer> : <HistoryPagination
          label={tab === "crops" ? "Crop outcomes" : "Planting runs"}
          page={tab === "crops" ? safeCurrentPage : runPage}
          total={tab === "crops" ? outcomes.length : runTotal}
          pageSize={historyPageSize}
          loading={tab === "runs" && isLoadingRuns}
          onPageChange={tab === "crops" ? setCurrentPage : loadRunPage}
        />}
      </section>
    </div>
  );
}

function HistoryBadge({ label }: { label: string }) {
  const key = label.toLowerCase();
  const tone = ["harvested", "finished", "row planted"].includes(key) ? "success"
    : ["not harvested", "failed", "lost"].includes(key) ? "danger"
    : ["pending", "needs review", "some planted"].includes(key) ? "warning"
    : "neutral";
  return <span className={historyStyles.badge} data-tone={tone}>{label}</span>;
}

function HistoryPagination({ label, page, total, pageSize, loading, onPageChange }: {
  label: string;
  page: number;
  total: number;
  pageSize: number;
  loading: boolean;
  onPageChange: (page: number) => void;
}) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const current = Math.min(page, pageCount);
  const start = Math.min(Math.max(current - 1, 1), Math.max(pageCount - 2, 1));
  const pages = Array.from({ length: Math.min(3, pageCount) }, (_, index) => start + index);
  return <footer className={historyStyles.footer}>
    <p className={historyStyles.range} role="status">{loading ? "Loading records..." : total ? `${(current - 1) * pageSize + 1}–${Math.min(current * pageSize, total)} of ${total} records` : "No records"}</p>
    <nav className={historyStyles.pagination} aria-label={`${label} pagination`}>
      <button aria-label={`Previous ${label.toLowerCase()} page`} disabled={current === 1 || loading} type="button" onClick={() => onPageChange(current - 1)}><ChevronLeft size={17} /></button>
      {pages.map((value) => <button key={value} aria-label={`Page ${value}`} aria-current={value === current ? "page" : undefined} disabled={loading || total === 0} type="button" onClick={() => onPageChange(value)}>{value}</button>)}
      <button aria-label={`Next ${label.toLowerCase()} page`} disabled={current === pageCount || loading} type="button" onClick={() => onPageChange(current + 1)}><ChevronRight size={17} /></button>
    </nav>
  </footer>;
}

function PlantingGuidePanel() {
  const plantingPoints = [300, 420, 540, 660, 780];
  const plantingPointClasses = [styles.plantingPointOne, styles.plantingPointTwo, styles.plantingPointThree, styles.plantingPointFour, styles.plantingPointFive];
  const steps = [
    ["PREPARE", "Connect to rover Wi-Fi, choose the seed and field, set 1–20 points (5 by default), and position the rover."],
    ["READ SOIL", "The rover records available soil readings."],
    ["PLANT THE ROW", "Tap Automatic Planting. The rover moves point to point and operates the gate at each cycle."],
    ["CONFIRM", "Choose Row Planted, Some Planted, None Planted, or Review Later. A full row requires all cycles to finish."],
    ["SAVE", "The run is saved. Confirming some or all planted creates a crop record."],
  ];
  return <div className={styles.plantingGuide}>
    <div className={styles.plantingGuideLayout}>
      <ol className={styles.plantingGuideSteps}>{steps.map(([title, detail], index) => <li className={styles.plantingGuideStepCard} key={title}>
        <span className={styles.plantingGuideNumber}>{index + 1}</span>
        <div>
          <strong>{title}</strong>
          <span>{detail}</span>
        </div>
      </li>)}</ol>
    </div>
    <section className={styles.plantingRowIllustration} aria-labelledby="planting-row-example-title">
      <div className={styles.plantingRowIllustrationHeading}>
        <strong id="planting-row-example-title">EXAMPLE - ONE ROW, FIVE PLANTING POINTS</strong>
        <small>Each planting point appears after the rover passes it.</small>
      </div>
      <svg className={styles.plantingRowSvg} viewBox="0 0 1040 230" role="img" aria-label="A rover travels along a row and reveals each planted seedling after passing its planting point">
        <defs>
          <linearGradient id="rover-body-fill" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stopColor="var(--green-accent)" /><stop offset="1" stopColor="var(--green)" /></linearGradient>
          <linearGradient id="planting-soil-fill" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="#a97948" /><stop offset="1" stopColor="#65452f" /></linearGradient>
          <filter id="rover-shadow" x="-30%" y="-30%" width="160%" height="180%"><feGaussianBlur stdDeviation="3" /></filter>
        </defs>
        <rect x="18" y="134" width="864" height="64" rx="22" fill="var(--surface-raised)" />
        <path className={styles.plantingSideLine} d="M225 156 H842" fill="none" stroke="url(#planting-soil-fill)" strokeWidth="16" strokeLinecap="round" />
        <path className={styles.plantingSideEdge} d="M225 168 H842" fill="none" stroke="var(--green)" strokeWidth="3" strokeDasharray="5 8" strokeLinecap="round" />
        {plantingPoints.map((point, index) => <g key={point}>
          <g className={`${styles.plantingSeedling} ${styles.plantingPointLabel} ${plantingPointClasses[index]}`}>
            <circle cx={point} cy="43" r="12" fill="var(--surface)" stroke="var(--green)" strokeWidth="2" />
            <text x={point} y="47" fill="var(--text)" fontSize="12" fontWeight="900" textAnchor="middle">{index + 1}</text>
          </g>
          <g className={`${styles.plantingSeedling} ${plantingPointClasses[index]}`} transform={`translate(${point} 0)`}>
            <ellipse cx="0" cy="157" rx="17" ry="7" fill="#795334" opacity="0.7" />
            <path d="M0 153 V127" fill="none" stroke="var(--green)" strokeWidth="5" strokeLinecap="round" />
            <path d="M0 140 C-20 136 -22 121 -8 123 C-1 124 1 131 0 140Z" fill="var(--green-accent)" stroke="var(--green)" strokeWidth="2" />
            <path d="M1 135 C17 129 20 116 7 118 C2 119 -1 126 1 135Z" fill="var(--green-accent)" stroke="var(--green)" strokeWidth="2" />
            <ellipse cx="0" cy="153" rx="3" ry="2" fill="#e8bf72" />
          </g>
        </g>)}
        <path d="M40 202 H198" fill="none" stroke="var(--border-soft)" strokeWidth="2" strokeDasharray="5 8" />
        <text x="43" y="220" fill="var(--text-muted)" fontSize="12" fontWeight="700">ROVER START</text>
        <text x="759" y="220" fill="var(--text-muted)" fontSize="12" fontWeight="700">ROW DIRECTION →</text>
        <g className={styles.plantingRover}>
          <ellipse cx="122" cy="159" rx="85" ry="11" fill="#000000" opacity="0.2" filter="url(#rover-shadow)" />
          <path d="M48 139 H185" fill="none" stroke="var(--green)" strokeWidth="4" strokeDasharray="5 5" />
          <rect x="47" y="88" width="138" height="51" rx="12" fill="url(#rover-body-fill)" stroke="var(--green)" strokeWidth="3" />
          <rect x="65" y="69" width="62" height="22" rx="6" fill="var(--surface)" stroke="var(--green)" strokeWidth="3" />
          <path d="M72 74 H120 M72 80 H120 M72 86 H120" stroke="var(--green)" strokeWidth="2" opacity="0.75" />
          <rect x="139" y="98" width="31" height="25" rx="5" fill="var(--surface)" stroke="var(--green)" strokeWidth="2" />
          <path d="M145 105 H164 M145 111 H164 M145 117 H159" stroke="var(--green)" strokeWidth="2" strokeLinecap="round" />
          <circle cx="180" cy="96" r="5" fill="#eaffb7" stroke="var(--green)" strokeWidth="2" />
          <path d="M185 112 H205 V139" fill="none" stroke="var(--text-secondary)" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
          <path d="M198 139 L205 147 L212 139" fill="none" stroke="#a97948" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
          <g className={styles.plantingWheel}>
            <circle cx="76" cy="143" r="16" fill="#202820" stroke="var(--text)" strokeWidth="3" />
            <circle cx="76" cy="143" r="6" fill="var(--surface)" stroke="var(--green)" strokeWidth="2" />
            <path d="M76 130 V135 M76 151 V156 M63 143 H68 M84 143 H89 M67 134 L71 138 M81 148 L85 152 M85 134 L81 138 M71 148 L67 152" stroke="var(--text-muted)" strokeWidth="2" />
          </g>
          <g className={styles.plantingWheel}>
            <circle cx="157" cy="143" r="16" fill="#202820" stroke="var(--text)" strokeWidth="3" />
            <circle cx="157" cy="143" r="6" fill="var(--surface)" stroke="var(--green)" strokeWidth="2" />
            <path d="M157 130 V135 M157 151 V156 M144 143 H149 M165 143 H170 M148 134 L152 138 M162 148 L166 152 M166 134 L162 138 M152 148 L148 152" stroke="var(--text-muted)" strokeWidth="2" />
          </g>
          <circle className={styles.plantingRoverLight} cx="180" cy="96" r="2" fill="#ffffff" />
        </g>
      </svg>
    </section>
  </div>;
}

function SavedRunTimeline({ run }: { run: PlantingRunHistoryRow }) {
  const confirmed = ["Row Planted", "Some Planted", "None Planted"].includes(run.confirmationOutcome);
  const steps = [
    ["PREPARE", run.startedAt ? `Run started ${formatDateTime(run.startedAt)} · ${run.seedName} · ${run.fieldLabel || "Field not labeled"}` : "Start time unavailable", Boolean(run.startedAt)],
    ["READ SOIL", run.soilCapturedAt ? `Historical capture ${formatDateTime(run.soilCapturedAt)} · ${run.provenanceStatus === "verified_hardware" ? "Verified rover hardware" : "Unverified source"} · Moisture ${formatRunSensor(run.soilMoisturePercent, "%")}${run.soilMoistureCalibrated === true ? ` (calibration ${run.calibrationVersion})` : run.soilMoistureCalibrated === false ? " (probe uncalibrated)" : " (calibration unverified)"} · Soil temperature ${formatRunSensor(run.soilTemperatureC, "°C")}` : "No soil snapshot recorded", Boolean(run.soilCapturedAt)],
    ["PLANT ROW", `${run.completedCycles} of ${run.targetCycles ?? "—"} rover gate cycles acknowledged · ${run.plantingStatus}${run.failureCode ? ` · ${run.failureCode}` : ""}`, Boolean(run.completedAt)],
    ["CONFIRM RESULT", run.confirmationOutcome === "Legacy" ? "Legacy run · Worker confirmation was not tracked in the older workflow" : confirmed ? `${run.confirmationOutcome}${run.confirmedAt ? ` · ${formatDateTime(run.confirmedAt)}` : ""}` : "NEEDS REVIEW · No crop is created until a worker confirms", confirmed],
    ["SAVE TO CROPS", run.cropId ? "Crop is available in Crops" : confirmed ? "Run saved; no crop was created for this result" : "Run log is saved; waiting for worker confirmation", true],
  ] as const;
  return <div className={styles.savedRunTimeline}>
    <ol>{steps.map(([title, detail, complete]) => <li key={title} data-complete={complete ? "true" : "false"}>
      <span className={styles.savedRunCheck}>{complete ? <Check size={15} /> : "·"}</span>
      <div><strong>{title}</strong><span>{detail}</span></div>
    </li>)}</ol>
    <div className={styles.savedRunReadings}>
      <span>Raw soil reading (ADC) <strong>{run.soilRaw ?? "Unavailable"}</strong></span>
      <span>Air temperature <strong>{formatRunSensor(run.airTemperatureC, "°C")}</strong></span>
      <span>Humidity <strong>{formatRunSensor(run.humidityPercent, "%")}</strong></span>
      <span>Run completed <strong>{run.completedAt ? formatDateTime(run.completedAt) : "Not recorded"}</strong></span>
    </div>
  </div>;
}

function formatRunSensor(value: number | null, unit: string) {
  return value !== null && Number.isFinite(value) ? `${value}${unit}` : "Unavailable";
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

function ReadOnly({ icon, label, value, detail }: { icon: ReactNode; label: string; value: string; detail?: string }) {
  return (
    <div className={styles.readOnly}>
      <span className={styles.detailMetricLabel}><i aria-hidden="true">{icon}</i>{label}</span>
      <strong>{value}</strong>
      {detail ? <small>{detail}</small> : null}
    </div>
  );
}
