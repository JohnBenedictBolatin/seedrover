"use client";

import { useEffect, useMemo, useRef, useState, useTransition, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import {
  Check,
  ClipboardCheck,
  Apple,
  Bean,
  CalendarDays,
  Cloud,
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
  MapPin,
  Search,
  Sprout,
  Sun,
  Thermometer,
  Trash2,
  UserRound,
  X,
  CircleSlash2,
  Citrus,
  Nut,
} from "lucide-react";
import type { CropActivityRecord, CropItem, CropSensorReading, CropWeatherStatus } from "@/lib/crops";
import type { CropOutcome } from "@/lib/crop-outcomes";
import type { PlantingRunHistoryRow } from "@/app/(portal)/crops/actions";
import { formatDate, formatDateTime } from "@/lib/format";
import { sharedWorkflowTerms } from "@/lib/shared-workflow-terms";
import { farmerCareText, farmerCropNote, farmerCropStatus, farmerCropTips, farmerGrowthStage, farmerSensorLabel } from "@/lib/farmer-copy";
import type { AlertTone } from "@/components/action-alert-stack";
import { useActionFeedback } from "@/components/action-feedback";
import { CalendarField } from "@/components/calendar-field";
import { PendingActionLabel } from "@/components/pending-action-label";
import { FileUploadField } from "@/components/file-upload-field";
import { ThemedSelect } from "@/components/themed-select";
import {
  getPlantingRunsAction,
  getCropActivityHistoryAction,
  getCropHarvestHistoryAction,
  getCropHarvestCorrectionsAction,
  correctCropHarvestAction,
  getCropSensorHistoryAction,
  updateCropAction,
  renameCropPlantingAction,
} from "@/app/(portal)/crops/actions";
import styles from "@/app/(portal)/crops/page.module.css";
import historyStyles from "@/components/crop-history.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";
import inventorySummaryStyles from "@/app/(portal)/inventory/page.module.css";
import { CropCareForm, CropEndForm, TodaysCare, taskActivity } from "@/components/crop-care";

function displayCropStatus(status: string) {
  return status === "Cancelled" ? sharedWorkflowTerms.closedWithoutHarvest : farmerCropStatus(status);
}

const statuses = ["All", "Active", "Needs Attention", "Harvest Ready"];
const statusInputOptions = ["Active", "Needs Attention", "Harvest Ready"];

function localDateInputValue() {
  const date = new Date();
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

type ModalState =
  | { type: "details"; crop: CropItem }
  | { type: "activity"; crop: CropItem; task?: CropItem["tasks"][number]; activity?: "Harvested" | "Not Harvested" }
  | { type: "end-crop"; crop: CropItem }
  | { type: "edit"; crop: CropItem }
  | { type: "rename-crop"; crop: CropItem }
  | { type: "not-harvested"; crop: CropItem }
  | { type: "outcomes" }
  | { type: "planting-guide" }
  | null;

export function CropsWorkspace({
  children,
  crops,
  weather,
  outcomes,
  outcomesError,
  initialPlantingRuns,
  plantingRunsTotal,
  plantingRunsError,
  isAdministrator,
}: {
  children: ReactNode;
  crops: CropItem[];
  weather: CropWeatherStatus | null;
  outcomes: CropOutcome[];
  outcomesError: string | null;
  initialPlantingRuns: PlantingRunHistoryRow[];
  plantingRunsTotal: number;
  plantingRunsError: string | null;
  isAdministrator: boolean;
}) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("All");
  const [stageFilter, setStageFilter] = useState("All stages");
  const [plantedByFilter, setPlantedByFilter] = useState("Anyone");
  const [modal, setModal] = useState<ModalState>(null);
  const [backgroundCrop, setBackgroundCrop] = useState<CropItem | null>(null);
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
    queueMicrotask(() => {
      setCropTab("overview");
      setBackgroundCrop(task ? crop : null);
      setModal(task ? { type: "activity", crop, task } : { type: "details", crop });
    });
    url.searchParams.delete("crop");
    url.searchParams.delete("task");
    window.history.replaceState(window.history.state, "", `${url.pathname}${url.search}${url.hash}`);
  }, [crops]);

  useEffect(() => {
    queueMicrotask(() => {
      setModal((current) => {
        if (!current || !("crop" in current)) return current;
        const latest = crops.find((crop) => crop.id === current.crop.id);
        return latest && latest !== current.crop ? { ...current, crop: latest } : current;
      });
      setBackgroundCrop((current) => {
        if (!current) return current;
        return crops.find((crop) => crop.id === current.id) ?? current;
      });
    });
  }, [crops]);

  function notify(tone: AlertTone, text: string) {
    sendFeedback({ tone, text });
  }

  function openModal(next: ModalState) {
    if (["activity", "end-crop", "rename-crop"].includes(next?.type ?? "") && modal?.type === "details") {
      setBackgroundCrop(modal.crop);
    } else if (!next || !["activity", "end-crop", "rename-crop"].includes(next.type)) {
      setBackgroundCrop(null);
    }
    setModal(next);
  }

  function openCare(crop: CropItem, task?: CropItem["tasks"][number]) {
    setCropTab("overview");
    setBackgroundCrop(crop);
    setModal({ type: "activity", crop, task });
  }

  const filteredCrops = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...crops]
      .filter((crop) => {
        const haystack = `${crop.displayName} ${crop.batchCode} ${crop.cropName} ${crop.growthStage} ${crop.fieldLabel} ${crop.managerName} ${crop.plantedBy}`.toLowerCase();

        return (
          (stageFilter === "All stages" || crop.growthStage === stageFilter) &&
          (plantedByFilter === "Anyone" || crop.plantedBy === plantedByFilter) &&
          (normalizedQuery.length === 0 || haystack.includes(normalizedQuery)) &&
          (status === "All"
            ? !["Completed", "Cancelled", "Not Harvested"].includes(crop.cropStatus)
            : crop.cropStatus === status)
        );
      })
      .sort((left, right) => {
        return right.plantingDate.localeCompare(left.plantingDate);
      });
  }, [crops, plantedByFilter, query, stageFilter, status]);

  const stageOptions = [...new Set(crops.map((crop) => crop.growthStage))].sort((left, right) => left.localeCompare(right));
  const plantedByOptions = [...new Set(crops.map((crop) => crop.plantedBy))]
    .filter((name) => name.trim() && name.trim().toLowerCase() !== "not recorded")
    .sort((left, right) => left.localeCompare(right));

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

        <section
          className={`${quickActionStyles.quickActions} ${styles.cropQuickActionArea} ${inventorySummaryStyles.inventoryQuickActionsPanel}`}
          aria-label="Crop quick actions"
        >
          <div>
            <h2>Plan and review crops</h2>
            <span>Explore planting guidance or review past crop records.</span>
          </div>
          <div className={`${styles.cropQuickActionButtons} ${inventorySummaryStyles.inventoryQuickActions}`}>
            <button className={quickActionStyles.recordSaleButton} type="button" onClick={() => openModal({ type: "planting-guide" })}>
              <span className={quickActionStyles.recordSaleText}>PLANT GUIDE</span>
              <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><BookOpenCheck size={20} /></span>
            </button>
            <button className={`${quickActionStyles.recordSaleButton} ${styles.cropHistoryButton}`} type="button" onClick={() => openModal({ type: "outcomes" })}>
              <span className={quickActionStyles.recordSaleText}>VIEW CROP HISTORY</span>
              <span className={quickActionStyles.recordSaleIcon} aria-hidden="true"><History size={20} /></span>
            </button>
          </div>
        </section>

        <aside className={styles.cropCareSidebar} aria-label="Today's crop care">
          <FarmForecast weather={weather} />
          <TodaysCare crops={crops} onOpen={openCare} />
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
            formatOption={farmerCropStatus}
            onChange={setStatus}
          />
          <ThemedSelect
            icon={<Filter size={17} />}
            label="Crop stage"
            options={["All stages", ...stageOptions]}
            value={stageFilter}
            variant="toolbar"
            formatOption={(value) => value === "All stages" ? value : farmerGrowthStage(value)}
            onChange={setStageFilter}
          />
          <ThemedSelect icon={<Filter size={17} />} label="Who planted" options={["Anyone", ...plantedByOptions]} value={plantedByFilter} variant="toolbar" onChange={setPlantedByFilter} />
        </section>

        <div className={styles.cropCollection}>
          {filteredCrops.length === 0 ? (
            <div className={styles.emptyState}>
              <strong>No crop records match the current view.</strong>
              <span>Try changing the search or filters.</span>
            </div>
          ) : (
            <section className={styles.stockGroups}>
              {Object.entries(groupedCrops).map(([groupKey, groupCrops]) => (
                <CropGroup
                  crops={groupCrops}
                  key={groupKey}
                  name={groupKey}
                  onOpen={(next) => { setCropTab("overview"); openModal(next); }}
                />
              ))}
            </section>
          )}
        </div>
      </div>

      {backgroundCrop && ["activity", "end-crop", "rename-crop"].includes(modal?.type ?? "") ? <CropDialog
        dialog={{ type: "details", crop: backgroundCrop }}
        cropTab={cropTab}
        onCropTabChange={setCropTab}
        notify={notify}
        onOpen={() => {}}
        outcomes={outcomes}
        isAdministrator={isAdministrator}
        outcomesError={outcomesError}
        initialPlantingRuns={initialPlantingRuns}
        plantingRunsTotal={plantingRunsTotal}
        plantingRunsError={plantingRunsError}
        onClose={() => {}}
        background
      /> : null}
      <CropDialog
        dialog={modal}
        cropTab={cropTab}
        onCropTabChange={setCropTab}
        notify={notify}
        onOpen={openModal}
        outcomes={outcomes}
        isAdministrator={isAdministrator}
        outcomesError={outcomesError}
        initialPlantingRuns={initialPlantingRuns}
        plantingRunsTotal={plantingRunsTotal}
        plantingRunsError={plantingRunsError}
        onClose={() => openModal(
          modal && (modal.type === "activity" || modal.type === "end-crop" || modal.type === "rename-crop")
            ? { type: "details", crop: modal.crop }
            : null,
        )}
        stacked={Boolean(backgroundCrop && ["activity", "end-crop", "rename-crop"].includes(modal?.type ?? ""))}
      />
    </>
  );
}

function FarmForecast({ weather }: { weather: CropWeatherStatus | null }) {
  const isAvailable = Boolean(weather && weather.currentCondition !== "Weather unavailable");
  const weatherTone = getWeatherTone(weather?.currentCondition ?? "");
  const nextRain = weather?.nextRainWindow ? formatDateTime(weather.nextRainWindow) : null;
  const conditionContext = weather ? explainWeatherCondition(weather.currentCondition) : "Weather details are not available right now.";

  return (
    <section className={styles.farmForecastCard} aria-label="Isarog Farm weather forecast" data-available={isAvailable}>
      <div className={styles.farmForecastHeader}>
        <span className={styles.farmForecastIcon} data-weather={weatherTone} aria-hidden="true">
          {weatherTone === "clear" ? <Sun size={22} /> : weatherTone === "rain" || weatherTone === "storm" ? <Droplets size={22} /> : <Cloud size={22} />}
        </span>
        <div>
          <span className={styles.farmForecastEyebrow}>Isarog Farm forecast</span>
          <strong>{isAvailable ? weather?.currentCondition : "Forecast unavailable"}</strong>
          <p className={styles.farmForecastContext}>{conditionContext}</p>
        </div>
      </div>
      <div className={styles.farmForecastMetrics}>
        <div>
          <span>Temperature</span>
          <strong>{weather?.temperatureC == null ? "N/A" : `${Math.round(weather.temperatureC)}°C`}</strong>
        </div>
        <div>
          <span>Rain chance</span>
          <strong>{weather?.rainChancePercent == null ? "N/A" : `${Math.round(weather.rainChancePercent)}%`}</strong>
        </div>
      </div>
      <p className={styles.farmForecastRain}>
        <Droplets size={15} aria-hidden="true" />
        <span>{nextRain ? `Next rain window · ${nextRain}` : isAvailable ? "No rain window is expected in the next 24 hours" : "A forecast will appear when weather data is available"}</span>
      </p>
      {weather?.source === "WeatherAPI" ? (
        <a className={styles.farmForecastAttribution} href="https://www.weatherapi.com/" target="_blank" rel="noreferrer">Weather data by WeatherAPI.com</a>
      ) : null}
    </section>
  );
}

function getWeatherTone(condition: string): "clear" | "cloudy" | "rain" | "storm" | "unknown" {
  const normalized = condition.toLowerCase();
  if (!normalized || normalized === "weather unavailable") return "unknown";
  if (normalized.includes("thunder")) return "storm";
  if (["rain", "drizzle", "shower", "snow", "sleet", "ice"].some((word) => normalized.includes(word))) return "rain";
  if (["sun", "clear"].some((word) => normalized.includes(word))) return "clear";
  return "cloudy";
}

function explainWeatherCondition(condition: string) {
  const normalized = condition.toLowerCase();
  if (normalized.includes("overcast")) return "Clouds cover nearly all the sky. That does not necessarily mean rain.";
  if (normalized.includes("cloud")) return "Clouds are present, but that does not necessarily mean rain.";
  if (normalized.includes("thunder")) return "Thunderstorms may bring lightning and sudden rain.";
  if (normalized.includes("drizzle")) return "Light rain is falling or expected.";
  if (normalized.includes("rain")) return "Rain is falling or expected around the farm.";
  if (normalized.includes("fog") || normalized.includes("mist")) return "Fine droplets in the air may reduce visibility.";
  if (normalized.includes("sun") || normalized.includes("clear")) return "Mostly clear skies, with little or no cloud cover.";
  return "This describes the current sky; check the rain chance below for expected precipitation.";
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
  const icon = <CropIdentityIcon name={name} size={22} />;

  function scrollCards(direction: "left" | "right") {
    const row = rowRef.current;
    if (!row) return;
    const cardWidth = row.querySelector<HTMLElement>("[data-crop-card]")?.offsetWidth ?? 220;
    row.scrollBy({ behavior: "smooth", left: direction === "right" ? cardWidth + 10 : -(cardWidth + 10) });
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

function CropIdentityIcon({ name, size, fallback = "sprout" }: { name: string; size: number; fallback?: "leaf" | "sprout" }) {
  const normalized = name.toLowerCase();
  if (normalized.includes("calamansi")) return <Citrus size={size} />;
  if (normalized.includes("peanut")) return <Nut size={size} />;
  if (normalized.includes("sitaw") || normalized.includes("string bean")) return <Bean size={size} />;
  return fallback === "leaf" ? <Leaf size={size} /> : <Sprout size={size} />;
}

function cropStageArtworkScale(stage: string) {
  const normalized = stage.trim().toLowerCase().replace(/[_-]+/g, " ");
  if (normalized.includes("seed") || normalized.includes("seedbed")) return 2.2;
  if (normalized.includes("germinat")) return 1.8;
  if (normalized.includes("nursery") || normalized.includes("transplant")) return 1.55;
  if (normalized.includes("establish") || normalized.includes("juvenile")) return 1.3;
  return 1;
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
          <Image
            unoptimized
            width={720}
            height={480}
            alt={`${crop.cropName} crop`}
            className={
              crop.imageUrl.startsWith("/images/crops/")
                ? styles.stageCropCardImage
                : styles.cropCardImage
            }
            src={crop.imageUrl}
          />
        ) : (
          <Sprout size={40} />
        )}
      </div>
      <div className={styles.cardTitleRow}>
        <div className={styles.cropCardIdentity}>
          <h4 className={styles.cropCardPlantingName}>{crop.displayName}</h4>
          <span className={styles.status} data-status={crop.cropStatus}>
            {displayCropStatus(crop.cropStatus)}
          </span>
        </div>
      </div>
      <p className={styles.cropCardId}>{crop.batchCode}</p>
      <dl className={styles.cardFacts}>
        <div>
          <dt>Stage</dt>
          <dd>{farmerGrowthStage(crop.growthStage)}</dd>
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
      <div className={styles.cardActions}>
        <button
          aria-label={`View details for ${crop.displayName}, ${crop.cropName}, ${crop.batchCode}`}
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
  isAdministrator,
  initialPlantingRuns,
  plantingRunsTotal,
  plantingRunsError,
  onClose,
  background = false,
  stacked = false,
}: {
  dialog: ModalState;
  cropTab: "overview" | "sensors" | "growth" | "activity";
  onCropTabChange: (tab: "overview" | "sensors" | "growth" | "activity") => void;
  notify: (tone: AlertTone, text: string) => void;
  onOpen: (modal: ModalState) => void;
  outcomes: CropOutcome[];
  outcomesError: string | null;
  isAdministrator: boolean;
  initialPlantingRuns: PlantingRunHistoryRow[];
  plantingRunsTotal: number;
  plantingRunsError: string | null;
  onClose: () => void;
  background?: boolean;
  stacked?: boolean;
}) {
  const dialogRef = useRef<HTMLElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);
  const cropId = dialog && "crop" in dialog ? dialog.crop.id : null;
  const dialogType = dialog?.type ?? null;
  const [visitedCropTabs, setVisitedCropTabs] = useState<Set<"overview" | "sensors" | "growth" | "activity">>(new Set(["overview"]));
  const [cropDataVersion, setCropDataVersion] = useState(0);
  useEffect(() => {
    if (background) return;
    if (!dialogType) {
      if (previousFocus.current?.isConnected) previousFocus.current.focus();
      previousFocus.current = null;
      return;
    }
    if (!previousFocus.current) {
      previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    }
    dialogRef.current?.focus();
  }, [background, dialogType, cropId]);

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
    details: { title: dialog.type === "details" ? dialog.crop.displayName : "Crop Details", icon: dialog.type === "details" ? <CropIdentityIcon name={dialog.crop.cropName} size={18} fallback="leaf" /> : <Leaf size={18} /> },
    activity: { title: dialog.type === "activity" && dialog.activity === "Not Harvested" ? sharedWorkflowTerms.closeWithoutHarvest : dialog.type === "activity" && dialog.activity === "Harvested" ? "Record harvest" : "Record care", icon: <ClipboardCheck size={18} /> },
    "end-crop": { title: "End crop", icon: <CircleSlash2 size={18} /> },
    edit: { title: "Edit Crop", icon: <Edit3 size={18} /> },
    "rename-crop": { title: "Rename planting", icon: <Edit3 size={18} /> },
    "not-harvested": { title: sharedWorkflowTerms.closeWithoutHarvest, icon: <CircleSlash2 size={18} /> },
    outcomes: { title: "Crop History", icon: <History size={18} /> },
    "planting-guide": { title: "How Planting Works", icon: <BookOpenCheck size={18} /> },
  }[dialog.type];

  return (
    <div className={`${styles.modalBackdrop} ${background ? styles.modalBackdropBehind : ""} ${stacked ? styles.modalBackdropStacked : ""}`} data-ui-backdrop="true" role="presentation" aria-hidden={background || undefined} inert={background || undefined} onMouseDown={(event) => { if (!background && event.target === event.currentTarget) onClose(); }}>
      <section ref={dialogRef} tabIndex={-1} onKeyDown={(event) => {
        if (event.key === "Escape") { event.stopPropagation(); onClose(); return; }
        if (event.key !== "Tab" || !dialogRef.current) return;
        const focusable = Array.from(dialogRef.current.querySelectorAll<HTMLElement>('button:not(:disabled), [href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])')).filter((element) => element.tabIndex >= 0 && !element.closest("[hidden]"));
        if (!focusable.length) { event.preventDefault(); return; }
        const first = focusable[0]; const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }} data-crop-tab={dialog.type === "details" ? cropTab : undefined} className={`${styles.modal} ${dialog.type === "details" ? styles.cropWorkspaceModal : ""} ${dialog.type === "outcomes" ? historyStyles.dialog : ""} ${dialog.type === "planting-guide" ? styles.plantingGuideModal : ""}`} role="dialog" aria-modal={background ? undefined : "true"} aria-label={dialog.type === "details" ? `Crop details for ${dialog.crop.cropName}, ID ${dialog.crop.batchCode}` : modalMeta.title}>
        <header className={styles.modalHeader}>
          <h3 className={styles.modalTitle}>
            <span className={styles.modalTitleIcon} aria-hidden="true">
              {modalMeta.icon}
            </span>
            <span className={styles.cropModalTitleText}>
              <span className={dialog.type === "details" ? styles.cropModalNameRow : undefined}>
                {modalMeta.title}
                {dialog.type === "details" ? <span className={styles.status} data-status={dialog.crop.cropStatus}>{displayCropStatus(dialog.crop.cropStatus)}</span> : null}
                {dialog.type === "details" && dialog.crop.cropStatus !== "Completed" && dialog.crop.cropStatus !== "Cancelled" ? (
                  <button
                    aria-label={`End crop ${dialog.crop.displayName}`}
                    className={styles.endCropHeaderButton}
                    title="End crop"
                    type="button"
                    onClick={() => onOpen({ type: "end-crop", crop: dialog.crop })}
                  >
                    <Trash2 size={16} aria-hidden="true" />
                  </button>
                ) : null}
              </span>
              {dialog.type === "details" ? <small className={styles.cropModalIdentity}>{dialog.crop.cropName} · {dialog.crop.batchCode}</small> : null}
            </span>
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
          {visitedCropTabs.has("overview") ? <div hidden={cropTab !== "overview"} id="crop-tabpanel" role="tabpanel" aria-labelledby="crop-tab-overview"><CropDetails crop={dialog.crop} isAdministrator={isAdministrator} /></div> : null}
          {visitedCropTabs.has("sensors") ? <div hidden={cropTab !== "sensors"} id="crop-tabpanel-sensors" role="tabpanel" aria-labelledby="crop-tab-sensors"><CropSensorHistoryPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} /></div> : null}
          {visitedCropTabs.has("growth") ? <div hidden={cropTab !== "growth"} id="crop-tabpanel-growth" role="tabpanel" aria-labelledby="crop-tab-growth"><CropGrowthJourneyPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} onRecordHarvest={() => onOpen({ type: "activity", crop: dialog.crop, activity: "Harvested" })} /></div> : null}
          {visitedCropTabs.has("activity") ? <div hidden={cropTab !== "activity"} id="crop-tabpanel-activity" role="tabpanel" aria-labelledby="crop-tab-activity"><CropActivityHistoryPanel key={`${dialog.crop.id}-${cropDataVersion}`} crop={dialog.crop} /></div> : null}
        </div> : null}
        {dialog.type === "details" ? <div className={`${styles.cropWorkspaceFooter} ${styles.modalFooterActions}`}>
          <button className={styles.secondaryAction} type="button" onClick={() => onOpen({ type: "rename-crop", crop: dialog.crop })}><Edit3 size={16} aria-hidden="true" /><span>RENAME</span></button>
          {dialog.crop.cropStatus !== "Completed" && dialog.crop.cropStatus !== "Cancelled" ? <>
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
        {dialog.type === "end-crop" ? <CropEndForm
          crop={dialog.crop}
          notify={notify}
          onCancel={() => onOpen({ type: "details", crop: dialog.crop })}
          onSuccess={() => { setCropDataVersion((version) => version + 1); onCropTabChange("overview"); onOpen({ type: "details", crop: dialog.crop }); }}
        /> : null}
        {dialog.type === "edit" ? (
          <CropForm
            action={updateCropAction}
            crop={dialog.crop}
            notify={notify}
            onCancel={() => onOpen({ type: "details", crop: dialog.crop })}
            onSuccess={() => onOpen({ type: "details", crop: dialog.crop })}
          />
        ) : null}
        {dialog.type === "rename-crop" ? <RenameCropForm crop={dialog.crop} notify={notify} onCancel={() => onOpen({ type: "details", crop: dialog.crop })} onSuccess={() => onOpen({ type: "details", crop: dialog.crop })} /> : null}
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

function CropDetails({ crop, isAdministrator }: { crop: CropItem; isAdministrator: boolean }) {
  const growthStages = crop.stages;
  const nextCareTitle = farmerCareText(crop.nextCareTask ?? crop.careStatus ?? "No scheduled care");
  const nextCareContext = [
    farmerCareText(crop.careStatus) !== nextCareTitle ? farmerCareText(crop.careStatus) : null,
    crop.nextCareDueAt ? `Due ${formatDate(crop.nextCareDueAt)}` : null,
  ].filter(Boolean).join(" · ");
  const cropNote = crop.maintenanceNotes?.trim() && crop.maintenanceNotes !== "No notes recorded."
    ? farmerCropNote(crop.maintenanceNotes.trim())
    : null;
  const careTips = farmerCropTips(crop.cropProfileKey, crop.growthStage);
  const stagePosition = stageIndex(crop.growthStage, growthStages);
  const isCompleted = ["Completed", "Harvested"].includes(crop.cropStatus) ||
    ["Completed", "Harvested"].includes(crop.growthStage);
  const progress = isCompleted
    ? 100
    : stagePosition >= 0
    ? Math.round(((stagePosition + 1) / Math.max(1, growthStages.length)) * 100)
    : 0;

  return (
    <div className={styles.detailsGrid}>
      <div className={styles.detailsTop}>
        <div className={styles.detailImagePanel}>
          {crop.imageUrl ? (
            <Image
              unoptimized
              width={900}
              height={600}
              alt={`${crop.cropName} crop`}
              src={crop.imageUrl}
              style={crop.imageUrl.startsWith("/images/crops/")
                ? { transform: `scale(${cropStageArtworkScale(crop.growthStage)})` }
                : undefined}
            />
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
            <h4>{nextCareTitle}</h4>
            {nextCareContext ? <p>{nextCareContext}</p> : null}
          </section>
          <div className={styles.detailMetrics}>
            <ReadOnly icon={<CalendarDays size={18} />} label="Planted" value={formatDate(crop.plantingDate)} />
            <ReadOnly icon={<Sprout size={18} />} label="Growth stage" value={farmerGrowthStage(crop.growthStage)} />
            <ReadOnly
              icon={<UserRound size={18} />}
              label="Planted by"
              value={crop.managerName || "Unassigned"}
            />
            <ReadOnly
              icon={<MapPin size={18} />}
              label="Planting location"
              value={crop.fieldLabel || "Not recorded"}
            />
            <ReadOnly
              icon={<Droplets size={18} />}
              label="Planting cycles"
              value={formatPlantingDrops(crop.plantingCompletedDrops, crop.plantingTargetDrops)}
            />
            {crop.harvestCount > 0 ? <ReadOnly
              icon={<Apple size={18} />}
              label="Harvested so far"
              value={`${crop.harvestCount} ${crop.harvestCount === 1 ? "harvest" : "harvests"} · ${crop.harvestedQuantity.toFixed(2)} kg`}
            /> : null}
          </div>
        </div>
      </div>
      <div className={styles.detailsLowerGrid}>
        <section className={styles.cropProgressPanel} aria-label="Crop growth progress">
          <div className={styles.cropProgressHeader}>
            <div>
              <span>GROWTH PROGRESS</span>
              <strong>{farmerGrowthStage(crop.growthStage)}</strong>
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
          <small>
            {isCompleted
              ? "Crop cycle completed."
              : stagePosition >= 0
                ? `Step ${stagePosition + 1} of ${growthStages.length} in this crop's growth`
                : growthStages.length === 0
                  ? "Growth progress is unavailable because this crop has no growth steps saved."
                  : "Growth progress is unavailable because this stage is not in this crop's plan."}
          </small>
        </section>
        <section className={`${styles.detailSection} ${styles.cropCareTips}`} aria-label={`Care tips for ${crop.displayName}`}>
          <div>
            <h5>CARE TIPS</h5>
            <span>{farmerGrowthStage(crop.growthStage)}</span>
          </div>
          <ul>
            {careTips.map((tip) => <li key={tip}>{tip}</li>)}
          </ul>
          {cropNote ? <p className={styles.cropFarmerNote}><strong>Your note:</strong> {cropNote}</p> : null}
        </section>
      </div>
      {crop.harvestCount > 0 ? <CropHarvestHistory crop={crop} isAdministrator={isAdministrator} /> : null}
    </div>
  );
}

function CropHarvestHistory({ crop, isAdministrator }: { crop: CropItem; isAdministrator: boolean }) {
  const [rows, setRows] = useState<{ id: string; quantity: number; unit: string; harvest_date: string; harvested_by_name: string | null; remarks: string | null }[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [loadedCropId, setLoadedCropId] = useState<string | null>(null);
  const [correction, setCorrection] = useState<NonNullable<typeof rows[number]> | null>(null);
  useEffect(() => {
    let active = true;
    getCropHarvestHistoryAction(crop.id, 20, 0)
      .then((result) => { if (active) { setRows(result as typeof rows); setHasMore(result.length === 20); setLoadedCropId(crop.id); setError(null); } })
      .catch((caught: unknown) => { if (active) { setError(caught instanceof Error ? caught.message : "Harvest history could not be loaded."); setLoadedCropId(crop.id); } });
    return () => { active = false; };
  }, [crop.id]);
  const isLoading = loadedCropId !== crop.id;
  async function loadOlderHarvests() {
    setLoadingMore(true);
    setError(null);
    try {
      const older = await getCropHarvestHistoryAction(crop.id, 20, rows.length) as typeof rows;
      setRows((current) => [...current, ...older]);
      setHasMore(older.length === 20);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Older harvests could not be loaded.");
    } finally {
      setLoadingMore(false);
    }
  }
  return <section className={styles.detailSection} aria-label="Harvest history">
    <h5>HARVEST HISTORY</h5>
    {error && !isLoading ? <p role="alert">{error}</p> : null}
    {isLoading ? <p>Loading harvests...</p> : error ? <p>Harvest history is unavailable.</p> : rows.length === 0 ? <p>No harvests are recorded.</p> : <ul>
      {rows.map((row) => <li key={row.id}><strong>{Number(row.quantity).toFixed(2)} kg · {formatDate(row.harvest_date)}</strong><span>{row.harvested_by_name ?? "Farmer"}{row.remarks ? ` · ${row.remarks}` : ""}</span>{isAdministrator && crop.cropStatus !== "Completed" && crop.cropStatus !== "Cancelled" ? <button type="button" onClick={() => setCorrection(row)}>Correct harvest</button> : null}</li>)}
    </ul>}
    {hasMore && rows.length > 0 && !isLoading ? <button type="button" disabled={loadingMore} onClick={loadOlderHarvests}>
      {loadingMore ? "Loading…" : "Load older harvests"}
    </button> : null}
    {correction ? <HarvestCorrectionDialog row={correction} onClose={() => setCorrection(null)} onSaved={async () => {
      setCorrection(null);
      const updated = await getCropHarvestHistoryAction(crop.id, 20, 0) as typeof rows;
      setRows(updated);
      setError(null);
    }} /> : null}
  </section>;
}

function HarvestCorrectionDialog({ row, onClose, onSaved }: {
  row: { id: string; quantity: number; remarks: string | null };
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const [busy, setBusy] = useState(false);
  const [revisionLoaded, setRevisionLoaded] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [revision, setRevision] = useState(0);
  const [quantity, setQuantity] = useState(String(row.quantity));
  const [notes, setNotes] = useState(row.remarks ?? "");
  const [reason, setReason] = useState("");
  const submissionId = useRef("");
  const router = useRouter();
  const { notify } = useActionFeedback();
  useEffect(() => {
    let alive = true;
    getCropHarvestCorrectionsAction(row.id).then((items) => {
      if (alive) {
        setRevision(items.length ? Number((items[0] as { revision: number }).revision) : 0);
        setRevisionLoaded(true);
      }
    }).catch((caught: unknown) => {
      if (alive) setError(caught instanceof Error ? caught.message : "Correction history could not be checked.");
    });
    return () => { alive = false; };
  }, [row.id]);
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    const data = new FormData(event.currentTarget);
    data.set("harvest_id", row.id);
    submissionId.current ||= crypto.randomUUID();
    data.set("submission_id", submissionId.current);
    data.set("expected_revision", String(revision));
    try {
      const result = await correctCropHarvestAction(data);
      submissionId.current = "";
      await onSaved();
      router.refresh();
      notify({ tone: "success", text: `Harvest corrected to ${Number(result.quantity).toFixed(2)} kg.` });
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Harvest could not be corrected.");
      setBusy(false);
    }
  }
  return <div className={`${styles.modalBackdrop} ${styles.modalBackdropStacked}`} role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose(); }}>
    <section className={styles.modal} role="dialog" aria-modal="true" aria-labelledby="harvest-correction-title">
      <header><h2 id="harvest-correction-title">Correct harvest</h2><button type="button" aria-label="Close" disabled={busy} onClick={onClose}><X /></button></header>
      <form onSubmit={save}>
        <p>Only the weight and notes can change. Crop, date, and inventory destination stay the same.</p>
        <p>Previous: <strong>{Number(row.quantity).toFixed(2)} kg</strong></p>
        <label>Correct weight (kg)<input name="quantity" type="number" min="0.01" step="0.01" required value={quantity} disabled={busy} onChange={(event) => setQuantity(event.target.value)} /></label>
        <p>New weight: <strong>{Number(quantity || 0).toFixed(2)} kg</strong></p>
        <label>Notes<textarea name="notes" maxLength={2000} value={notes} disabled={busy} onChange={(event) => setNotes(event.target.value)} /></label>
        <label>Why are you correcting this harvest?<textarea name="reason" maxLength={500} required value={reason} disabled={busy} onChange={(event) => setReason(event.target.value)} /></label>
        {error ? <p role="alert">{error}</p> : null}
        <footer><button type="button" disabled={busy} onClick={onClose}>Cancel</button><button type="submit" disabled={busy || !revisionLoaded}>{busy ? "Saving correction…" : "Save correction"}</button></footer>
      </form>
    </section>
  </div>;
}

function formatPlantingDrops(completed: number | null, target: number | null) {
  if (completed == null && target == null) return "Not recorded";
  if (completed == null) return `${target} planned cycles`;
  if (target == null) return `${completed} completed cycles`;
  return `${completed} of ${target} cycles`;
}

function CropGrowthJourneyPanel({ crop, onRecordHarvest }: { crop: CropItem; onRecordHarvest: () => void }) {
  const [activities, setActivities] = useState<CropActivityRecord[]>([]);
  const [expandedPhotoStages, setExpandedPhotoStages] = useState<Set<string>>(() => new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const harvestReadyIndex = stageIndex("Harvest Ready", crop.stages);
  const currentStageIndex = ["Completed", "Cancelled", "Not Harvested"].includes(crop.cropStatus)
    ? -1
    : crop.cropStatus === "Harvest Ready" && harvestReadyIndex >= 0
      ? harvestReadyIndex
      : stageIndex(crop.growthStage, crop.stages);
  const stages = crop.stages;
  const activityByStage = useMemo(() => {
    const byStage = new Map<string, CropActivityRecord>();

    for (const activity of activities) {
      if (!activity.observedStage) continue;
      const key = stageObservationKey(activity.observedStage, stages);
      if (!byStage.has(key)) byStage.set(key, activity);
    }

    return byStage;
  }, [activities, stages]);

  const photosByStage = useMemo(() => {
    const byStage = new Map<string, { photo: CropActivityRecord["photos"][number]; activity: CropActivityRecord }[]>();

    for (const activity of activities) {
      if (!activity.observedStage || !activity.photos.length) continue;
      const key = stageObservationKey(activity.observedStage, stages);
      const stagePhotos = byStage.get(key) ?? [];
      byStage.set(key, [...stagePhotos, ...activity.photos.map((photo) => ({ photo, activity }))]);
    }

    return byStage;
  }, [activities, stages]);

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
        <span className={styles.growthJourneyCurrent}><small>GROWTH STAGE</small><strong>{farmerGrowthStage(crop.growthStage)}</strong></span>
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
            const skipped = !observed && !current && currentStageIndex > index;
            const complete = observed || skipped;
            const canRecordHarvest = current && !["Completed", "Cancelled", "Not Harvested"].includes(crop.cropStatus) && (
              normalizeStage(stage) === "harvest ready" ||
              (crop.harvestMode === "repeat" && crop.harvestCount > 0) ||
              (crop.harvestMode === "repeat" && crop.cropProfileKey === "calamansi" && normalizeStage(stage) === "first bearing")
            );

            return (
              <div className={`${styles.growthTimelineItem} ${complete ? styles.growthTimelineItemCompleted : ""} ${current ? styles.growthTimelineItemCurrent : ""}`} key={stage}>
                <div className={styles.growthTimelineTrack} aria-hidden="true">
                  <span className={styles.growthTimelinePoint}>{complete ? <Check size={20} strokeWidth={4} /> : index + 1}</span>
                </div>
                <div className={styles.growthStageRow}>
                  <div>
                    <strong>{farmerGrowthStage(stage)}</strong>
                    <small>{activity ? formatDateTime(activity.performedAt) : skipped ? "Stage passed without an observation" : current ? "Current stage in crop record" : "No observation recorded"}</small>
                  </div>
                  <span className={styles.growthStageStatus}>{observed ? "Recorded" : skipped ? "Skipped" : current ? "Current step" : "Not seen yet"}</span>
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
                    <div className={styles.growthStagePhotos} hidden={!photosExpanded} id={`growth-photos-${crop.id}-${index}`} aria-label={`${farmerGrowthStage(stage)} observation photos`}>
                      {stagePhotos.map(({ activity: photoActivity, photo }, photoIndex) => (
                        <a href={photo.url} key={photo.path} target="_blank" rel="noreferrer" aria-label={`Open ${farmerGrowthStage(stage)} growth photo ${photoIndex + 1}, recorded ${formatDateTime(photoActivity.performedAt)}`}>
                          <Image unoptimized width={168} height={126} src={photo.url} alt={`${farmerGrowthStage(stage)} growth observation photo, recorded ${formatDateTime(photoActivity.performedAt)}`} />
                        </a>
                      ))}
                    </div>
                  ) : null}
                  {canRecordHarvest ? (
                    <>
                      <button className={`${styles.secondaryAction} ${styles.growthHarvestAction}`} type="button" onClick={onRecordHarvest}>
                        <Apple size={16} aria-hidden="true" />
                        <span>Record harvest</span>
                      </button>
                      <small className={styles.growthHarvestHint}>{crop.harvestMode === "repeat" ? "Each picking is added to inventory. This crop stays active for future harvests." : "The harvest is added to inventory and closes this crop."}</small>
                    </>
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

function stageObservationKey(observedStage: string, stages: string[]) {
  const normalized = normalizeStage(observedStage);
  if (stages.some((stage) => normalizeStage(stage) === normalized)) return normalized;

  // Planting records use the generic "Seeded" label, while some crop plans
  // name that same first stage "Seedbed".
  if (normalized === "seeded" && stages.some((stage) => normalizeStage(stage) === "seedbed")) {
    return "seedbed";
  }

  return normalized;
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

  const latest = readings.find((reading) => reading.provenanceStatus === "verified_hardware");
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
              <time>{latest.source} · {formatDateTime(latest.recordedAt)} · {latest.fresh ? "Fresh" : "Stale"}</time>
            </div>
            <div className={styles.sensorSummaryGrid}>
              <SensorValue tone="moisture" icon={<Droplets size={19} />} label="Water in soil" unit="%" value={latest.soilMoisture} />
              <SensorValue tone="soil" icon={<Thermometer size={19} />} label="Soil temperature" unit="°C" value={latest.soilTemperature} />
              <SensorValue tone="air" icon={<Sun size={19} />} label="Air temperature" unit="°C" value={latest.environmentalTemperature} />
              <SensorValue tone="humidity" icon={<Cloud size={19} />} label="Humidity" unit="%" value={latest.humidity} />
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
                <span>Recorded</span><span>Soil</span><span>Soil temp</span><span>Air temp</span><span>Humidity</span>
              </div>
              {visibleReadings.map((reading) => (
                <div className={styles.sensorHistoryRow} key={reading.id}>
                  <time>{formatDateTime(reading.recordedAt)}{reading.provenanceStatus === "simulated" && reading.calibrationVersion === "display-sample-v1" ? " · Estimated sample" : ""}</time>
                  <span data-label="Soil moisture">{formatSensorValue(reading.soilMoisture, "%")}</span>
                  <span data-label="Soil temp">{formatSensorValue(reading.soilTemperature, "°C")}</span>
                  <span data-label="Air temp">{formatSensorValue(reading.environmentalTemperature, "°C")}</span>
                  <span data-label="Humidity">{formatSensorValue(reading.humidity, "%")}</span>
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

function SensorValue({ icon, label, tone, unit, value }: { icon: ReactNode; label: string; tone: "moisture" | "soil" | "air" | "humidity"; unit: string; value: number | null }) {
  return (
    <div className={styles.sensorValueCard} data-tone={tone}>
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
}: {
  action: (formData: FormData) => void | Promise<void>;
  crop: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onCancel: () => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const currentStageIndex = crop.stages.findIndex((stage) => stage.trim().toLowerCase() === crop.growthStage.trim().toLowerCase());
  const editableStages = currentStageIndex >= 0 ? crop.stages.slice(currentStageIndex) : crop.stages;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const formData = new FormData(form);

    startTransition(async () => {
      try {
        await action(formData);
        notify("success", "Crop details updated successfully.");
        onSuccess();
        router.refresh();
      } catch (error) {
        notify("error", error instanceof Error ? error.message : "Something went wrong.");
      }
    });
  }

  return (
    <>
    <form className={styles.formGrid} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={crop.id} />
      <p className={styles.cropModalIdentity}>Crop type: {crop.cropName}. This cannot be changed here because it determines the harvest inventory type.</p>
      <div className={styles.twoColumn}>
        <CalendarField
          label="Planting date"
          name="planting_date"
          required
          defaultValue={crop.plantingDate}
        />
        <CalendarField label="Estimated harvest" min={localDateInputValue()} name="estimated_harvest" defaultValue={crop?.estimatedHarvest ?? ""} />
      </div>
      <div className={styles.twoColumn}>
        <ThemedSelect label="Growth stage" name="growth_stage" options={editableStages} defaultValue={crop?.growthStage ?? "Seeded"} formatOption={farmerGrowthStage} />
        <ThemedSelect label="Status" name="crop_status" options={statusInputOptions} defaultValue={crop?.cropStatus ?? "Active"} formatOption={farmerCropStatus} />
      </div>
      <label>
        <span>Maintenance notes</span>
        <textarea name="maintenance_notes" placeholder="e.g. Watered every morning; monitor leaf growth" defaultValue={crop?.maintenanceNotes ?? ""} />
      </label>
      <FileUploadField
        accept="image/jpeg,image/png,image/webp"
        helperText="JPG, PNG or WEBP · up to 5 MB"
        label="Crop image"
        name="image"
        prompt={crop?.imagePath ? "Choose replacement image" : "Choose crop image"}
      />
      <div className={styles.modalFooterActions}>
        <button className={styles.secondaryAction} disabled={pending} type="button" onClick={onCancel}>CANCEL</button>
        <button className={styles.primaryAction} disabled={pending} type="submit">
          <Sprout size={17} />
          <PendingActionLabel pending={pending} pendingText="Saving changes...">SAVE CHANGES</PendingActionLabel>
        </button>
      </div>
    </form>
    </>
  );
}

function RenameCropForm({
  crop,
  notify,
  onCancel,
  onSuccess,
}: {
  crop: CropItem;
  notify: (tone: AlertTone, text: string) => void;
  onCancel: () => void;
  onSuccess: () => void;
}) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const submission = useRef<{ signature: string; id: string } | null>(null);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const data = new FormData(event.currentTarget);
    const plantingName = String(data.get("planting_name") ?? "").trim().replace(/\s+/g, " ");
    const signature = `${plantingName}:${crop.plantingNameVersion}`;
    if (!submission.current || submission.current.signature !== signature) {
      submission.current = { signature, id: crypto.randomUUID() };
    }
    data.set("crop_id", crop.id);
    data.set("expected_version", String(crop.plantingNameVersion));
    data.set("submission_id", submission.current.id);
    startTransition(async () => {
      try {
        await renameCropPlantingAction(data);
        submission.current = null;
        notify("success", "Planting name saved.");
        router.refresh();
        onSuccess();
      } catch (error) {
        notify("error", error instanceof Error ? error.message : "Could not save the planting name.");
      }
    });
  }

  return <form className={styles.formGrid} onSubmit={submit}>
    <p className={styles.cropModalIdentity}>Name this planting of {crop.cropName}. Your tracking ID stays {crop.batchCode}.</p>
    <label>
      <span>Planting name</span>
      <input name="planting_name" required minLength={1} maxLength={60} disabled={pending} defaultValue={crop.displayName} autoFocus />
    </label>
    <div className={styles.modalFooterActions}>
      <button className={styles.secondaryAction} disabled={pending} type="button" onClick={onCancel}>CANCEL</button>
      <button className={styles.primaryAction} disabled={pending} type="submit"><PendingActionLabel pending={pending} pendingText="Saving name...">SAVE NAME</PendingActionLabel></button>
    </div>
  </form>;
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
                <td data-label="Crop"><strong>{outcome.cropName}</strong>{outcome.cropType !== outcome.cropName ? <small>{outcome.cropType}</small> : null}</td>
                <td data-label="Outcome"><HistoryBadge label={outcome.outcome === "Failed" ? sharedWorkflowTerms.closedWithoutHarvest : outcome.outcome} /></td>
                <td data-label="Reason / notes">{outcome.reason === "Harvest recorded from the crop card." ? "—" : farmerCropNote(outcome.reason ?? "")?.trim() || "—"}</td>
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
                <td data-label="Result"><HistoryBadge label={plantingResultLabel(run.confirmationOutcome)} />{run.confirmationOutcome === "Legacy" ? <small>{run.plantingStatus}</small> : null}</td>
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
  const tone = ["harvested", "finished", "row planted", "some planted", "planted"].includes(key) ? "success"
    : ["not harvested", "failed", "lost"].includes(key) ? "danger"
    : ["pending", "needs review"].includes(key) ? "warning"
    : "neutral";
  return <span className={historyStyles.badge} data-tone={tone}>{label}</span>;
}

function plantingResultLabel(outcome: string) {
  if (outcome === "Row Planted" || outcome === "Some Planted") return "Planted";
  if (outcome === "None Planted") return "Not planted";
  if (outcome === "Pending") return "Needs review";
  return outcome;
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
  const steps = [
    ["Connect to the rover", "Join the rover’s Wi-Fi and open Rover Control."],
    ["Choose the seed and field", "Select what you are planting and where the row is."],
    ["Set the row", "Choose 1–20 planting points (the starting value is 5) and place the rover at the row’s beginning."],
    ["Start planting", "Check any available readings, tap Automatic Planting, and keep the row clear while the rover moves."],
    ["Check what was planted", "Wait for the run to finish and compare completed cycles with your planned points. Use the completed count if the rover stopped early."],
    ["Confirm the result", "Tap Planted if seeds went into the row, or Not planted if none did."],
    ["Save the run", "Save to keep the run in Crop History. A crop record is created when you choose Planted."],
  ] as const;

  return <div className={`${styles.plantingGuide} ${styles.plantingGuideExperience}`}>
    <p className={styles.simpleGuideIntro}>Follow these steps each time you plant a row with the rover.</p>
    <ol className={styles.simpleGuideSteps}>
      {steps.map(([title, detail], index) => <li key={title}>
        <span className={styles.simpleGuideNumber} aria-hidden="true">{index + 1}</span>
        <div><strong>{title}</strong><p>{detail}</p></div>
      </li>)}
    </ol>
  </div>;
}

function SavedRunTimeline({ run }: { run: PlantingRunHistoryRow }) {
  const confirmed = ["Row Planted", "Some Planted", "None Planted"].includes(run.confirmationOutcome);
  const steps = [
    ["PREPARE", run.startedAt ? `Run started ${formatDateTime(run.startedAt)} · ${run.seedName} · ${run.fieldLabel || "Field not labeled"}` : "Start time unavailable", Boolean(run.startedAt)],
    ["READ SOIL", run.soilCapturedAt ? `Historical capture ${formatDateTime(run.soilCapturedAt)} · ${run.provenanceStatus === "verified_hardware" ? "Verified rover hardware" : "Unverified source"} · Moisture ${formatRunSensor(run.soilMoisturePercent, "%")} · Soil temperature ${formatRunSensor(run.soilTemperatureC, "°C")}` : "No soil snapshot recorded", Boolean(run.soilCapturedAt)],
    ["PLANT ROW", `${run.completedCycles} of ${run.targetCycles ?? "—"} rover gate cycles acknowledged · ${run.plantingStatus}${run.failureCode ? ` · ${run.failureCode}` : ""}`, Boolean(run.completedAt)],
    ["CONFIRM RESULT", run.confirmationOutcome === "Legacy" ? "Older run · Worker confirmation was not tracked" : confirmed ? `${plantingResultLabel(run.confirmationOutcome)}${run.confirmedAt ? ` · ${formatDateTime(run.confirmedAt)}` : ""}` : "Needs review · No crop is created until a worker confirms", confirmed],
    ["SAVE TO CROPS", run.cropId ? "Crop is available in Crops" : confirmed ? "Run saved; no crop was created for this result" : "Run log is saved; waiting for worker confirmation", true],
  ] as const;
  return <div className={styles.savedRunTimeline}>
    <ol>{steps.map(([title, detail, complete]) => <li key={title} data-complete={complete ? "true" : "false"}>
      <span className={styles.savedRunCheck}>{complete ? <Check size={15} /> : "·"}</span>
      <div><strong>{title}</strong><span>{detail}</span></div>
    </li>)}</ol>
    <div className={styles.savedRunReadings}>
      <span>{farmerSensorLabel("Raw soil probe (ADC)")} <strong>{run.soilRaw ?? "Unavailable"}</strong></span>
      <span>Air temperature <strong>{formatRunSensor(run.airTemperatureC, "°C")}</strong></span>
      <span>Humidity <strong>{formatRunSensor(run.humidityPercent, "%")}</strong></span>
      <span>Run completed <strong>{run.completedAt ? formatDateTime(run.completedAt) : "Not recorded"}</strong></span>
    </div>
  </div>;
}

function formatRunSensor(value: number | null, unit: string) {
  return value !== null && Number.isFinite(value) ? `${value}${unit}` : "Unavailable";
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
