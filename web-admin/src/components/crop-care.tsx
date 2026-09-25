"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, ChevronLeft, ChevronRight } from "lucide-react";
import { CalendarField } from "@/components/calendar-field";
import { FileUploadField } from "@/components/file-upload-field";
import { ThemedSelect } from "@/components/themed-select";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { sharedWorkflowTerms } from "@/lib/shared-workflow-terms";
import type { CropItem, CropTask } from "@/lib/crops";
import { cropMaintenanceAction, getHarvestDestinationAction } from "@/app/(portal)/crops/actions";
import dashboardStyles from "@/app/(portal)/dashboard/page.module.css";
import cropStyles from "@/app/(portal)/crops/page.module.css";
import styles from "./crop-care.module.css";

const actions = { Watered: "Watering", Fertilized: "Fertilizing", Inspected: "Field check", "Stage Observed": "Observe growth", Transplanted: "Transplanting", Harvested: "Harvest batch", "Not Harvested": sharedWorkflowTerms.closeWithoutHarvest };
type Activity = keyof typeof actions;
export function taskActivity(task?: CropTask): Activity {
  return task?.task_type === "Water" ? "Watered" : task?.task_type === "Fertilize" ? "Fertilized" : task?.task_type === "Transplant" ? "Transplanted" : "Inspected";
}
const localTime = () => { const d = new Date(); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16); };

export function TodaysCare({ crops, onOpen }: { crops: CropItem[]; onOpen: (crop: CropItem, task?: CropTask) => void }) {
  const [page, setPage] = useState(1);
  const pageSize = 3;
  const rank = (priority: string) => priority === "Critical" ? 0 : priority === "Important" ? 1 : 2;
  const tasks = crops
    .filter((crop) => !["Completed", "Cancelled"].includes(crop.cropStatus))
    .flatMap((crop) => crop.tasks
      .filter((task) => ["Due", "Overdue"].includes(task.status) ||
        (task.status === "Upcoming" && new Date(task.due_at).getTime() < Date.now() + 86400000))
      .map((task) => ({ crop, task })))
    .sort((a, b) => rank(a.task.priority) - rank(b.task.priority) || a.task.due_at.localeCompare(b.task.due_at));
  const pageCount = Math.max(1, Math.ceil(tasks.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const visibleTasks = tasks.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  return (
    <section className={dashboardStyles.listPanel} aria-labelledby="today-care-heading">
      <div className={dashboardStyles.sectionHeader}>
        <div>
          <p className={dashboardStyles.eyebrow}>Crop care</p>
          <h2 id="today-care-heading">Today&apos;s care</h2>
        </div>
        <span className={dashboardStyles.panelPill}>{tasks.length} {tasks.length === 1 ? "task" : "tasks"}</span>
      </div>
      {tasks.length ? (
        <div className={dashboardStyles.riskList} id="today-care-tasks">
          {visibleTasks.map(({ crop, task }) => (
            <article key={task.id} className={`${dashboardStyles.riskItem} ${styles.careTask}`} data-priority={task.priority}>
              <div className={styles.careTaskDetails}>
                <strong>{task.title}</strong>
                <span>{crop.cropName} Â· {crop.batchCode}</span>
              </div>
              <em>{task.priority}</em>
              <div className={styles.careTaskDue}>
                <time dateTime={task.due_at}>Due {new Date(task.due_at).toLocaleString([], { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })}</time>
              </div>
              <button className={styles.careTaskOpen} type="button" title={`Open ${crop.cropName} activity`} aria-label={`Open activity for ${crop.cropName}, batch ${crop.batchCode}`} onClick={() => onOpen(crop, task)}>
                <ArrowRight size={17} aria-hidden="true" />
              </button>
            </article>
          ))}
        </div>
      ) : <p className={styles.carePanelEmpty}>No care tasks due today.</p>}
      {pageCount > 1 && (
        <nav className={`${dashboardStyles.activityPagination} ${styles.carePanelPagination}`} aria-label="Today's care pages">
          <button aria-label="Previous care tasks" disabled={currentPage === 1} type="button" onClick={() => setPage((value) => Math.max(1, Math.min(value, pageCount) - 1))}>
            <ChevronLeft size={16} aria-hidden="true" />
          </button>
          <span>Page {currentPage} of {pageCount}</span>
          <button aria-label="Next care tasks" disabled={currentPage === pageCount} type="button" onClick={() => setPage((value) => Math.min(pageCount, Math.min(value, pageCount) + 1))}>
            <ChevronRight size={16} aria-hidden="true" />
          </button>
        </nav>
      )}
    </section>
  );
}
export function CropCareForm({ crop, task, initialActivity, onCancel, onSuccess, notify }: {
  crop: CropItem; task?: CropTask; initialActivity?: Activity; onCancel: () => void; onSuccess: () => void; notify: (tone: "success" | "error", message: string) => void;
}) {
  const [activity, setActivity] = useState<Activity>(initialActivity ?? taskActivity(task));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [quantity, setQuantity] = useState("");
  const [performedAt, setPerformedAt] = useState(localTime);
  const [observedStage, setObservedStage] = useState("");
  const [observation, setObservation] = useState("");
  const [unit, setUnit] = useState(() => typeof window === "undefined" ? "liters" : localStorage.getItem(`crop-unit:${initialActivity ?? taskActivity(task)}`) ?? "liters");
  const [destination, setDestination] = useState<{ id: string; name: string } | null>(null);
  const [receipt, setReceipt] = useState(false);
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const payload = useRef<FormData | null>(null);
  const submission = useRef("");
  const router = useRouter();
  useEffect(() => { submission.current = crypto.randomUUID(); }, []);
  useEffect(() => {
    queueMicrotask(() => setUnit(localStorage.getItem(`crop-unit:${activity}`) ?? (activity === "Watered" ? "liters" : "grams")));
    if (activity !== "Harvested") return;
    let active = true;

    getHarvestDestinationAction(crop.id).then((value) => { if (active) setDestination(value); }).catch((e) => { if (active) setError(String(e.message)); });
    return () => { active = false; };
  }, [activity, crop.id]);
  async function save() {
    if (busy || !payload.current) return;
    setBusy(true); setError("");
    try {
      await cropMaintenanceAction(payload.current);
      localStorage.setItem(`crop-unit:${activity}`, unit);
      router.refresh();
      if (activity === "Harvested") {
        setReceipt(true);
        notify("success", `${quantity} kg harvested from ${crop.batchCode} and added to ${destination?.name} inventory.`);
      }
      else { notify("success", activity === "Not Harvested" ? "Batch closed without harvest. No inventory was added." : `${actions[activity]} saved. The crop journal and care tasks are updated.`); onSuccess(); }
    } catch (e) {
      const message = e instanceof Error ? e.message : "Unable to save. Your entries are still here; retry when connected.";
      setError(message);
      notify("error", message);
    }
    finally { setBusy(false); }
  }
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (activity === "Stage Observed" && !observedStage) {
      setError("Select the growth stage you observed before saving.");
      return;
    }
    if (activity === "Inspected" && !observation) {
      setError("Choose whether the crop looks normal or has an issue.");
      return;
    }
    const data = new FormData(event.currentTarget);
    data.set("submission_id", submission.current);
    data.set("performed_at", new Date(String(data.get("performed_at"))).toISOString());
    payload.current = data;
    if (["Harvested", "Not Harvested"].includes(activity)) {
      const harvested = activity === "Harvested";
      const confirmed = await confirm({
        title: harvested ? "Review harvest" : "Close batch without harvest?",
        message: harvested
          ? `This will add ${quantity} kg from ${crop.batchCode} to ${destination?.name} inventory and close the batch.`
          : `This will close ${crop.cropName} batch ${crop.batchCode} without adding inventory.`,
        summary: <><strong>{crop.cropName} · {crop.batchCode}</strong>{harvested ? <p>{quantity} kg → {destination?.name}</p> : <p>{String(data.get("notes") ?? "")}</p>}</>,
        confirmLabel: harvested ? sharedWorkflowTerms.harvestAndClose : sharedWorkflowTerms.closeWithoutHarvest,
        tone: harvested ? "default" : "danger",
      });
      if (!confirmed) return;
    }
    void save();
  }
  const activityOptions = (Object.keys(actions) as Activity[]).filter((value) => initialActivity === "Not Harvested"
    ? value === "Not Harvested"
    : value !== "Not Harvested" && (value !== "Transplanted" || crop.cropName.toLowerCase() === "calamansi") && (!task || value === taskActivity(task)));
  if (receipt) return <section className={cropStyles.activityFormSection} role="status">
    <div className={cropStyles.activityFormIntro}><span>HARVEST COMPLETE</span><div><h4>{crop.cropName}</h4><strong>{crop.batchCode}</strong></div></div>
    <p><strong>{quantity} kg</strong> added to {destination?.name} inventory. This batch is closed.</p>
    <div className={cropStyles.modalFooterActions}><a className={cropStyles.secondaryAction} href="/inventory">View inventory</a><button className={cropStyles.primaryAction} type="button" onClick={onSuccess}><span>View batch journal</span></button></div>
  </section>;
  return <form className={`${cropStyles.formGrid} ${cropStyles.activityForm}`} onSubmit={submit}>
    <div className={cropStyles.activityFormIntro}>
      <span>{activity === "Not Harvested" ? "CLOSE WITHOUT HARVEST" : "CROP DETAILS"}</span>
      <div><h4>{crop.cropName}</h4><strong>{crop.fieldLabel} · {crop.batchCode} · {crop.growthStage}</strong></div>
    </div>
    <input type="hidden" name="id" value={crop.id} />
    <input type="hidden" name="task_id" value={task?.id ?? ""} />
    <input type="hidden" name="activity" value={activity} />
    {activityOptions.length > 1 && <ThemedSelect label="Activity" required options={activityOptions.map((value) => actions[value])} value={actions[activity]} onChange={(value) => {
      const selected = activityOptions.find((option) => actions[option] === value);
      if (selected) { setActivity(selected); setError(""); }
    }} />}
    <CalendarField className={cropStyles.activityFormWide} includeTime label={sharedWorkflowTerms.dateAndTime} min={`${crop.plantingDate}T00:00`} max={localTime()} name="performed_at" required value={performedAt} onChange={setPerformedAt} disabled={busy} />
    {(["Watered", "Fertilized", "Harvested"] as Activity[]).includes(activity) ? <div className={cropStyles.twoColumn}>
      <label className={activity === "Harvested" ? cropStyles.activityFormWide : undefined}><span>{activity === "Harvested" ? "Total batch weight (kg)" : "Amount"}</span><input name="quantity" type="number" min="0.01" step="0.01" required value={quantity} onChange={(event) => setQuantity(event.target.value)} disabled={busy} /></label>
      {activity === "Harvested" ? <input name="unit" type="hidden" value="kg" /> : <label><span>Unit</span><input name="unit" required value={unit} onChange={(event) => setUnit(event.target.value)} disabled={busy} /></label>}
    </div> : null}
    {activity === "Harvested" ? <div className={`${cropStyles.notesPanel} ${cropStyles.activityFormWide}`}><span>Inventory destination</span><p>{destination?.name ?? "Checking inventory..."}</p></div> : null}
    {activity === "Fertilized" ? <label className={cropStyles.activityFormWide}><span>Fertilizer used</span><input name="material" required disabled={busy} /></label> : null}
    {activity === "Inspected" ? <ThemedSelect label="Observation" name="material" options={["Looks normal", "Issue noticed"]} placeholder="Choose an observation" required value={observation} onChange={(value) => { setObservation(value); setError(""); }} /> : null}
    {activity === "Stage Observed" ? <ThemedSelect label="Observed growth stage" name="observed_stage" options={crop.stages} required value={observedStage} onChange={(value) => { setObservedStage(value); setError(""); }} /> : null}
    {activity === "Transplanted" ? <label className={cropStyles.activityFormWide}><span>Transplanted to</span><input name="material" required disabled={busy} /></label> : null}
    <label><span>{activity === "Not Harvested" ? "Reason for closure" : "Notes (optional)"}</span><textarea name="notes" required={activity === "Not Harvested"} disabled={busy} /></label>
    {activity === "Stage Observed" ? <FileUploadField accept="image/jpeg,image/png,image/webp" disabled={busy} helperText="JPG, PNG or WEBP - up to 5 MB each" label="Growth photos (optional)" multiple name="photos" prompt="Choose growth photos" /> : null}
    {error && <div role="alert" className={cropStyles.sensorErrorState}>{error}</div>}
    <div className={cropStyles.modalFooterActions}>
      <button className={cropStyles.secondaryAction} type="button" disabled={busy} onClick={onCancel}>CANCEL</button>
      <button className={cropStyles.primaryAction} type="submit" disabled={busy || (activity === "Harvested" && !destination)}><span>{busy ? "SAVING..." : activity === "Harvested" ? "REVIEW HARVEST" : activity === "Not Harvested" ? "REVIEW CLOSURE" : `SAVE ${actions[activity].toUpperCase()}`}</span></button>
    </div>
    {confirmationDialog}
  </form>;
}
