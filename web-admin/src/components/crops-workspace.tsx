"use client";

import { useEffect, useMemo, useRef, useState, useTransition, type FormEvent, type InputHTMLAttributes, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import {
  Check,
  ClipboardCheck,
  CircleSlash2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  CloudRain,
  CloudSun,
  Database,
  Droplets,
  Edit3,
  Filter,
  History,
  Leaf,
  Plus,
  Search,
  SlidersHorizontal,
  Sprout,
  Sun,
  Thermometer,
  X,
} from "lucide-react";
import type { CropActivityRecord, CropItem, CropSensorReading, CropWeatherStatus } from "@/lib/crops";
import type { CropOutcome } from "@/lib/crop-outcomes";
import { formatDate, formatDateTime } from "@/lib/format";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "@/components/action-alert-stack";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { CalendarField } from "@/components/calendar-field";
import { FileUploadField } from "@/components/file-upload-field";
import { NOT_HARVESTED_CAUSES, OTHER_NOT_HARVESTED_CAUSE } from "@/lib/crop-outcome-causes";
import {
  createCropAction,
  cropMaintenanceAction,
  getCropActivityHistoryAction,
  getCropSensorHistoryAction,
  markCropNotHarvestedAction,
  refreshCropWeatherAction,
  updateCropAction,
} from "@/app/(portal)/crops/actions";
import styles from "@/app/(portal)/crops/page.module.css";
import quickActionStyles from "@/app/(portal)/sales/page.module.css";

const stageInputOptions = [
  "Seeded",
  "Seedbed",
  "Germinating",
  "Nursery Seedling",
  "Transplant Review",
  "Establishing",
  "Juvenile",
  "Vegetative",
  "Trellising",
  "Flowering",
  "Pod Formation",
  "Pegging",
  "Pod Development",
  "Maturity Check",
  "First Bearing",
  "Fruiting",
  "Harvest Ready",
  "Repeated Harvest",
  "Completed",
];
const statuses = ["All", "Active", "Needs Attention", "Harvest Ready", "Completed", "Not Harvested"];
const statusInputOptions = statuses.slice(1).filter((status) => status !== "Not Harvested");
const sortOptions = ["Newest", "Name", "Harvest Soon"];

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
  | { type: "activity"; crop: CropItem }
  | { type: "activities"; crop: CropItem }
  | { type: "sensors"; crop: CropItem }
  | { type: "edit"; crop: CropItem }
  | { type: "not-harvested"; crop: CropItem }
  | { type: "outcomes" }
  | null;

export function CropsWorkspace({
  crops,
  weather,
  canAddManualCrop,
  outcomes,
  outcomesError,
}: {
  crops: CropItem[];
  weather: CropWeatherStatus | null;
  canAddManualCrop: boolean;
  outcomes: CropOutcome[];
  outcomesError: string | null;
}) {
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("All");
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
      } catch (error) {
        notify("error", `Weather update failed - ${error instanceof Error ? error.message : "Try again later."}`);
      }
    });
  }, [router, weather?.fetchedAt, weather?.needsRefresh]);

  const filteredCrops = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();

    return [...crops]
      .filter((crop) => {
        const haystack = `${crop.batchCode} ${crop.cropName} ${crop.fieldLabel} ${crop.managerName}`.toLowerCase();

        return (
          (normalizedQuery.length === 0 || haystack.includes(normalizedQuery)) &&
          (status === "All" || displayCropStatus(crop.cropStatus) === status)
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
  }, [crops, query, sort, status]);

  const groupedCrops = useMemo(() => {
    return filteredCrops.reduce<Record<string, CropItem[]>>((groups, crop) => {
      groups[crop.cropName] = [...(groups[crop.cropName] ?? []), crop];
      return groups;
    }, {});
  }, [filteredCrops]);

  return (
    <>
      <section className={styles.weatherStrip} aria-label="Weather and field status">
        <div><CloudSun size={20} /><span>Weather now</span><strong>{weather?.currentCondition ?? "Loading weather"}{weather?.temperatureC == null ? "" : ` · ${weather.temperatureC.toFixed(1)}°C`}</strong></div>
        <div><Droplets size={20} /><span>Rain chance</span><strong>{weather?.rainChancePercent == null ? "--" : `${Math.round(weather.rainChancePercent)}% in the next 24 hours`}</strong></div>
        <div><CloudRain size={20} /><span>Next rain</span><strong>{weather?.nextRainWindow ? formatDateTime(weather.nextRainWindow) : "No rain expected in 24 hours"}</strong></div>
      </section>
      <section className={quickActionStyles.quickActions}>
        <div>
          <p className={quickActionStyles.eyebrow}>Quick action</p>
          <h2>Crop records</h2>
          <span>Add an authorized manual crop or review completed and failed crops.</span>
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
      </section>

      {filteredCrops.length === 0 ? (
        <div className={styles.emptyState}>
          <strong>No crop records match the current view.</strong>
          <span>Try changing the search, status, or sort option.</span>
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
        notify={notify}
        onOpen={setModal}
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
  const hasFieldLabel = crop.fieldLabel.trim().length > 0 && crop.fieldLabel !== "Field not labeled";
  const hasSoilReading = crop.latestSoilPercent !== null;
  const hasHarvestWindow = crop.harvestWindowStart !== null;
  const hasCalamansiMilestone =
    crop.cropName.toLowerCase() === "calamansi" &&
    !hasHarvestWindow &&
    crop.expectedStage.trim().length > 0 &&
    crop.expectedStage !== crop.growthStage;

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
          <dt>Planted</dt>
          <dd>{formatDate(crop.plantingDate)}</dd>
        </div>
        <div>
          <dt>Next care</dt>
          <dd>{crop.careStatus}</dd>
        </div>
        {hasFieldLabel ? <div><dt>Field</dt><dd>{crop.fieldLabel}</dd></div> : null}
        {hasSoilReading ? <div><dt>Soil moisture</dt><dd>{crop.latestSoilPercent!.toFixed(0)}%</dd></div> : null}
        {hasHarvestWindow ? (
          <div>
            <dt>Harvest window</dt>
            <dd>{formatDate(crop.harvestWindowStart!)}{crop.harvestWindowEnd ? ` to ${formatDate(crop.harvestWindowEnd)}` : ""}</dd>
          </div>
        ) : null}
        {hasCalamansiMilestone ? <div><dt>Next milestone</dt><dd>{crop.expectedStage}</dd></div> : null}
      </dl>
      <div className={styles.cardActions}>
        <IconAction label="Edit" tone="edit" onClick={() => onOpen({ type: "edit", crop })}>
          <Edit3 size={16} />
        </IconAction>
        {crop.cropStatus !== "Completed" && crop.cropStatus !== "Cancelled" ? (
          <IconAction label="Mark not harvested" tone="not-harvested" onClick={() => onOpen({ type: "not-harvested", crop })}>
            <CircleSlash2 size={16} />
          </IconAction>
        ) : null}
      </div>
    </article>
  );
}

function CropDialog({
  dialog,
  notify,
  onOpen,
  outcomes,
  outcomesError,
  onClose,
}: {
  dialog: ModalState;
  notify: (tone: AlertTone, text: string) => void;
  onOpen: (modal: ModalState) => void;
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
    activity: { title: "Record Crop Activity", icon: <ClipboardCheck size={18} /> },
    activities: { title: "Crop Activity History", icon: <History size={18} /> },
    sensors: { title: "Crop Sensor Data", icon: <Database size={18} /> },
    edit: { title: "Edit Crop", icon: <Edit3 size={18} /> },
    "not-harvested": { title: "Mark Not Harvested", icon: <CircleSlash2 size={18} /> },
    outcomes: { title: "Past Crops", icon: <History size={18} /> },
  }[dialog.type];

  return (
    <div className={`${styles.modalBackdrop} ${dialog.type === "activities" ? styles.activityHistoryBackdrop : ""}`} data-ui-backdrop="true" role="presentation">
      <section className={`${styles.modal} ${dialog.type === "details" || dialog.type === "activities" || dialog.type === "sensors" ? styles.cropDetailsModal : ""} ${dialog.type === "activities" ? styles.activityHistoryModal : ""} ${dialog.type === "outcomes" ? styles.outcomesModal : ""}`} role="dialog" aria-modal="true" aria-label={modalMeta.title}>
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
            onOpen={onOpen}
          />
        ) : null}
        {dialog.type === "activity" ? (
          <MaintenanceForm
            crop={dialog.crop}
            notify={notify}
            onCancel={() => onOpen({ type: "details", crop: dialog.crop })}
            onSuccess={onClose}
          />
        ) : null}
        {dialog.type === "activities" ? (
          <CropActivityHistoryPanel
            crop={dialog.crop}
            onBack={() => onOpen({ type: "details", crop: dialog.crop })}
          />
        ) : null}
        {dialog.type === "sensors" ? (
          <CropSensorHistoryPanel
            crop={dialog.crop}
            onBack={() => onOpen({ type: "details", crop: dialog.crop })}
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
        {dialog.type === "not-harvested" ? <NotHarvestedForm crop={dialog.crop} notify={notify} onSuccess={onClose} /> : null}
        {dialog.type === "outcomes" ? <CropOutcomesPanel outcomes={outcomes} error={outcomesError} /> : null}
      </section>
    </div>
  );
}

function CropDetails({
  crop,
  onOpen,
}: {
  crop: CropItem;
  onOpen: (modal: ModalState) => void;
}) {
  const progressPercent = cropProgressPercent(crop);

  return (
    <div className={styles.detailsGrid}>
      <div className={styles.detailsTop}>
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
        <div className={styles.detailSummary}>
          <div className={styles.detailTitleBlock}>
            <div className={styles.detailTitleRow}>
              <div>
                <span className={styles.itemCode}>{crop.batchCode}</span>
                <h4>{crop.cropName}</h4>
              </div>
              <span className={styles.status} data-status={crop.cropStatus}>
                {displayCropStatus(crop.cropStatus)}
              </span>
            </div>
          </div>
          <div className={styles.cropProgressPanel}>
            <div className={styles.cropProgressHeader}>
              <div>
                <span>Growth progress</span>
                <strong>{crop.growthStage}</strong>
              </div>
              <b>{progressPercent}%</b>
            </div>
            <div
              aria-label={`${crop.cropName} growth progress`}
              aria-valuemax={100}
              aria-valuemin={0}
              aria-valuenow={progressPercent}
              className={styles.cropProgressTrack}
              role="progressbar"
            >
              <i style={{ width: `${progressPercent}%` }} />
            </div>
            <small>Updates when the crop advances to a new growth stage.</small>
          </div>
          <div className={styles.detailMetrics}>
            <ReadOnly label="Batch ID" value={crop.batchCode} />
            <ReadOnly label="Field" value={crop.fieldLabel} />
            <ReadOnly label="Manager" value={crop.managerName} />
            <ReadOnly label="Planted" value={formatDate(crop.plantingDate)} />
            <ReadOnly
              label="Latest soil"
              value={crop.latestSoilPercent !== null
                ? `${crop.latestSoilPercent.toFixed(0)}%${crop.latestSoilAt ? ` · ${formatDateTime(crop.latestSoilAt)}` : ""}`
                : "No recent reading"}
            />
            <ReadOnly
              label={crop.cropName.toLowerCase() === "calamansi" && !crop.harvestWindowStart ? "Next milestone" : "Harvest window"}
              value={crop.harvestWindowStart
                ? `${formatDate(crop.harvestWindowStart)}${crop.harvestWindowEnd ? ` to ${formatDate(crop.harvestWindowEnd)}` : ""}`
                : crop.expectedStage}
            />
          </div>
        </div>
      </div>
      <section className={styles.detailSection}>
        <div className={styles.careSectionHeader}>
          <div>
            <span>Care status</span>
            <h5>Next action</h5>
          </div>
          <Sprout size={22} />
        </div>
        <p className={styles.careAdvisory}>{crop.careStatus}</p>
        <div className={styles.careSectionActions}>
          <button className={styles.secondaryAction} type="button" onClick={() => onOpen({ type: "sensors", crop })}>
            <Database size={17} />
            <span>VIEW SENSOR DATA</span>
          </button>
          <button className={styles.secondaryAction} type="button" onClick={() => onOpen({ type: "activities", crop })}>
            <History size={17} />
            <span>VIEW ACTIVITY HISTORY</span>
          </button>
          <button className={styles.primaryAction} type="button" onClick={() => onOpen({ type: "activity", crop })}>
            <ClipboardCheck size={17} />
            <span>RECORD ACTIVITY</span>
          </button>
        </div>
      </section>
      {crop.maintenanceNotes !== "No notes recorded." ? (
        <section className={styles.detailSection}>
          <h5>Farm notes</h5>
          <div className={styles.notesPanel}><p>{crop.maintenanceNotes}</p></div>
        </section>
      ) : null}
    </div>
  );
}

function CropActivityHistoryPanel({ crop, onBack }: { crop: CropItem; onBack: () => void }) {
  const [activities, setActivities] = useState<CropActivityRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
      <div className={styles.sensorHistoryIntro}>
        <div>
          <span>{crop.batchCode} · {crop.fieldLabel}</span>
          <h4>{crop.cropName}</h4>
        </div>
        <strong>{activities.length} activit{activities.length === 1 ? "y" : "ies"}</strong>
      </div>

      {loading ? <div className={styles.sensorEmptyState}>Loading crop activity history...</div> : null}
      {error ? <div className={styles.sensorErrorState}>{error}</div> : null}
      {!loading && !error && activities.length === 0 ? (
        <div className={styles.sensorEmptyState}>
          <History size={28} />
          <strong>No activities have been recorded for this crop.</strong>
        </div>
      ) : null}

      {!loading && !error && activities.length > 0 ? (
        <div className={styles.activityHistoryList}>
          {activities.map((activity) => (
            <article className={styles.activityHistoryCard} key={activity.id}>
              <header>
                <div>
                  <strong>{activity.activityType}</strong>
                  <span>{activity.source}</span>
                </div>
                <time>{formatDateTime(activity.performedAt)}</time>
              </header>
              <div className={styles.activityHistoryMeta}>
                <span><b>Performed by</b>{activity.performedBy}</span>
                <span><b>Quantity</b>{activity.quantity === null ? "Not recorded" : `${activity.quantity}${activity.unit ? ` ${activity.unit}` : ""}`}</span>
                <span><b>Material</b>{activity.material || "Not recorded"}</span>
                <span><b>Observed stage</b>{activity.observedStage || "No stage change"}</span>
              </div>
              <div className={styles.activityHistoryNotes}>
                <b>Notes</b>
                <p>{activity.notes?.trim() || "No notes were added."}</p>
              </div>
            </article>
          ))}
        </div>
      ) : null}

      <div className={styles.modalFooterActions}>
        <button className={styles.secondaryAction} type="button" onClick={onBack}>BACK TO CROP DETAILS</button>
      </div>
    </div>
  );
}

function CropSensorHistoryPanel({ crop, onBack }: { crop: CropItem; onBack: () => void }) {
  const [readings, setReadings] = useState<CropSensorReading[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

  const latest = readings[0];

  return (
    <div className={styles.sensorHistoryPanel}>
      <div className={styles.sensorHistoryIntro}>
        <div>
          <span>{crop.batchCode} · {crop.fieldLabel}</span>
          <h4>{crop.cropName}</h4>
        </div>
        <strong>{readings.length} reading{readings.length === 1 ? "" : "s"}</strong>
      </div>

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
                <span>Latest reading</span>
                <h5>Field conditions</h5>
              </div>
              <time>{formatDateTime(latest.recordedAt)}</time>
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
                <span>Reading history</span>
                <h5>Collected data</h5>
              </div>
            </div>
            <div className={styles.sensorHistoryTable}>
              <div className={styles.sensorHistoryHeader} aria-hidden="true">
                <span>Recorded</span><span>Soil</span><span>Soil temp</span><span>Air temp</span><span>Humidity</span><span>Source</span>
              </div>
              {readings.map((reading, index) => (
                <div className={styles.sensorHistoryRow} key={reading.id}>
                  <time>{formatDateTime(reading.recordedAt)}</time>
                  <span data-label="Soil">{formatSensorNumber(reading.soilMoisture)}%</span>
                  <span data-label="Soil temp">{formatSensorNumber(reading.soilTemperature)}°C</span>
                  <span data-label="Air temp">{formatSensorNumber(reading.environmentalTemperature)}°C</span>
                  <span data-label="Humidity">{formatSensorNumber(reading.humidity)}%</span>
                  <span data-label="Source">{reading.source}{index === readings.length - 1 ? " · First" : ""}</span>
                </div>
              ))}
            </div>
          </section>
        </>
      ) : null}

      <div className={styles.modalFooterActions}>
        <button className={styles.secondaryAction} type="button" onClick={onBack}>BACK TO CROP DETAILS</button>
      </div>
    </div>
  );
}

function SensorValue({ icon, label, unit, value }: { icon: ReactNode; label: string; unit: string; value: number }) {
  return (
    <div className={styles.sensorValueCard}>
      <span>{icon}</span>
      <div>
        <small>{label}</small>
        <strong>{formatSensorNumber(value)}{unit}</strong>
      </div>
    </div>
  );
}

function formatSensorNumber(value: number) {
  return Number.isFinite(value) ? value.toFixed(1) : "--";
}

function cropProgressPercent(crop: CropItem) {
  if (crop.cropStatus === "Completed") return 100;
  if (crop.cropStatus === "Harvest Ready") return 94;

  const stage = crop.growthStage.toLowerCase();
  if (stage.includes("repeated harvest")) return 96;
  if (stage.includes("harvest ready") || stage.includes("maturity")) return 92;
  if (stage.includes("first bearing") || stage.includes("fruiting")) return 86;
  if (stage.includes("pod development")) return 84;
  if (stage.includes("pod formation") || stage.includes("pegging")) return 76;
  if (stage.includes("flowering")) return 68;
  if (stage.includes("trellis")) return 60;
  if (stage.includes("vegetative") || stage.includes("juvenile")) return 52;
  if (stage.includes("establish")) return 44;
  if (stage.includes("transplant")) return 38;
  if (stage.includes("nursery")) return 30;
  if (stage.includes("germinat")) return 22;
  if (stage.includes("seed")) return 12;
  return 8;
}

function MaintenanceForm({
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

  const activityOptions = [
    "Watered",
    "Fertilized",
    "Inspected",
    ...(crop.cropName.toLowerCase() === "calamansi" ? ["Transplanted"] : []),
    ...(crop.cropStatus === "Harvest Ready" || crop.growthStage === "Repeated Harvest" ? ["Harvested"] : []),
  ];
  const recommendedActivity = crop.careStatus.toLowerCase().includes("water")
    ? "Watered"
    : crop.careStatus.toLowerCase().includes("fertiliz")
      ? "Fertilized"
      : crop.careStatus.toLowerCase().includes("harvest") && activityOptions.includes("Harvested")
        ? "Harvested"
        : "Inspected";

  return (
    <>
    <div className={styles.activityFormIntro}>
      <span>{crop.fieldLabel}</span>
      <div>
        <h4>{crop.cropName}</h4>
        <strong>{crop.careStatus}</strong>
      </div>
    </div>
    <form className={`${styles.formGrid} ${styles.activityForm}`} onSubmit={handleSubmit}>
      <input name="id" type="hidden" value={crop.id} />
      <section className={styles.activityFormSection}>
        <div className={styles.activityFormSectionTitle}>
          <span>1</span>
          <div><strong>Activity</strong><small>Choose what was completed and the observed crop stage.</small></div>
        </div>
        <div className={styles.twoColumn}>
          <ThemedSelect label="Activity type" name="activity" options={activityOptions} defaultValue={recommendedActivity} />
          <ThemedSelect label="Observed stage" name="observed_stage" options={["", ...stageInputOptions]} defaultValue="" />
        </div>
      </section>
      <section className={styles.activityFormSection}>
        <div className={styles.activityFormSectionTitle}>
          <span>2</span>
          <div><strong>Amount and material</strong><small>Leave these blank when they do not apply.</small></div>
        </div>
        <div className={styles.twoColumn}>
          <Field label="Quantity" min="0" name="quantity" placeholder="e.g. 12" step="0.01" type="number" />
          <Field label="Unit" name="unit" placeholder="e.g. liters or grams" />
        </div>
        <Field label="Material used" name="material" placeholder="e.g. irrigation water or 14-14-14 fertilizer" />
      </section>
      <section className={styles.activityFormSection}>
        <div className={styles.activityFormSectionTitle}>
          <span>3</span>
          <div><strong>Notes</strong><small>Add a short field observation for the farm record.</small></div>
        </div>
        <label>
          <span>Activity notes</span>
          <textarea name="notes" placeholder="e.g. Soil was slightly dry before watering" />
        </label>
      </section>
      <div className={styles.modalFooterActions}>
        <button className={styles.secondaryAction} disabled={pending} type="button" onClick={onCancel}>CANCEL</button>
        <button className={styles.primaryAction} disabled={pending} type="submit">
          <Check size={17} />
          <span>{pending ? "RECORDING..." : "RECORD ACTIVITY"}</span>
        </button>
      </div>
    </form>
    {confirmationDialog}
    </>
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
    const form = event.currentTarget;

    const confirmed = await confirm({
      message: crop
        ? "Are you sure you want to save these crop record changes?"
        : "Are you sure you want to create this crop record?",
      confirmLabel: crop ? "Save Changes" : "Save Crop",
    });

    if (!confirmed) {
      return;
    }

    const formData = new FormData(form);

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
        <CalendarField
          label="Planting date"
          name="planting_date"
          required
          defaultValue={crop?.plantingDate ?? localDateInputValue()}
        />
        <CalendarField label="Estimated harvest" name="estimated_harvest" defaultValue={crop?.estimatedHarvest ?? ""} />
      </div>
      <div className={styles.twoColumn}>
        <ThemedSelect label="Growth stage" name="growth_stage" options={stageInputOptions} defaultValue={crop?.growthStage ?? "Seeded"} />
        {crop ? <ThemedSelect label="Status" name="crop_status" options={statusInputOptions} defaultValue={displayCropStatus(crop.cropStatus)} /> : null}
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
      <button className={styles.primaryAction} disabled={pending} type="submit">
        <Sprout size={17} />
        <span>{pending ? "Saving..." : crop ? "Save Changes" : "Save Crop"}</span>
      </button>
    </form>
    {confirmationDialog}
    </>
  );
}

function NotHarvestedForm({ crop, notify, onSuccess }: { crop: CropItem; notify: (tone: AlertTone, text: string) => void; onSuccess: () => void }) {
  const [pending, startTransition] = useTransition();
  const [cause, setCause] = useState<string>(NOT_HARVESTED_CAUSES[0]);
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
      <div className={styles.activityFormIntro}>
        <span>Crop outcome</span>
        <div>
          <h4>{crop.cropName}</h4>
          <strong>Move to Past Crops</strong>
        </div>
      </div>
      <form className={`${styles.formGrid} ${styles.activityForm}`} onSubmit={handleSubmit}>
        <input name="id" type="hidden" value={crop.id} />
        <section className={styles.activityFormSection}>
          <div className={styles.activityFormSectionTitle}>
            <span>1</span>
            <div><strong>Primary cause</strong><small>Select the main reason this crop could not be harvested.</small></div>
          </div>
          <ThemedSelect
            label="Cause"
            name="cause"
            onChange={setCause}
            options={[...NOT_HARVESTED_CAUSES]}
            required
            value={cause}
          />
          {cause === OTHER_NOT_HARVESTED_CAUSE ? (
            <Field label="Other cause" name="other_cause" placeholder="e.g. Seed contamination" required />
          ) : null}
        </section>
        <section className={styles.activityFormSection}>
          <div className={styles.activityFormSectionTitle}>
            <span>2</span>
            <div><strong>Details</strong><small>Describe what happened and any conditions that affected the crop.</small></div>
          </div>
          <label><span>Additional details</span><textarea name="details" placeholder="e.g. Leaf damage spread across the row after three days of heavy rain" required /></label>
        </section>
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
        <div className={styles.outcomeSectionHeader}><div><span>History</span><h4>Past crop outcomes</h4></div><p>{outcomes.length} record{outcomes.length === 1 ? "" : "s"}</p></div>
        {outcomes.length === 0 ? (
          <div className={styles.outcomesEmpty}>No crop outcomes have been recorded yet.</div>
        ) : (
          <div className={styles.outcomeTable}>
            <div className={styles.outcomeTableHeader}><span>Crop</span><span>Outcome</span><span>Reason</span><span>Quantity</span><span>Marked by</span><span>Recorded</span></div>
            {visibleOutcomes.map((outcome) => (
              <div className={styles.outcomeRow} key={outcome.id}>
                <strong data-label="Crop">{outcome.cropName}</strong>
                <span className={styles.outcomeStatusCell} data-label="Outcome"><span className={styles.outcomeStatus} data-outcome={outcome.outcome.toLowerCase()}>{outcome.outcome === "Failed" ? "Not Harvested" : outcome.outcome}</span></span>
                <span data-label="Reason">{outcome.reason ?? "No reason recorded"}</span>
                <span data-label="Quantity">{outcome.quantity === null ? "Not recorded" : `${outcome.quantity} kg`}</span>
                <span data-label="Marked by">{outcome.recordedByName}</span>
                <span data-label="Recorded">{formatDateTime(outcome.recordedAt)}</span>
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
      className={`${styles.themedSelect} ${variant === "toolbar" ? styles.themedSelectToolbar : styles.themedSelectForm}`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
          setOpen(false);
        }
      }}
    >
      {name ? <input name={name} type="hidden" value={selectedValue} /> : null}
      {variant === "form" ? <span className={styles.themedSelectLabel}>{label}{required ? <span aria-hidden="true" className={styles.requiredMarker}>*</span> : null}</span> : null}
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        {variant === "toolbar" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
        <span className={styles.themedSelectValue}>{selectedValue || "No stage change"}</span>
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
                <span>{option || "No stage change"}</span>
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
  tone: "water" | "edit" | "not-harvested";
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
