"use client";

import { Antenna, ChevronLeft, ChevronRight } from "lucide-react";
import { useState } from "react";
import { formatDateTime } from "@/lib/format";
import type { RoverCommand } from "@/lib/rover";
import dashboardStyles from "@/app/(portal)/dashboard/page.module.css";
import styles from "@/app/(portal)/rover-monitor/page.module.css";

const pageSize = 5;

export function RoverCommandHistory({ commands, error }: { commands: RoverCommand[]; error: string | null }) {
  const [page, setPage] = useState(1);
  const pageCount = Math.max(1, Math.ceil(commands.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const start = (currentPage - 1) * pageSize;
  const visibleCommands = commands.slice(start, start + pageSize);
  const showPagination = !error && pageCount > 1;

  return (
    <div className={styles.commandHistory}>
      <div className={styles.panelHeader}>
        <h2>
          <span><Antenna size={18} /></span>
          Command history
        </h2>
        {showPagination ? (
          <nav className={dashboardStyles.activityPagination} aria-label="Command history pagination">
            <button
              aria-label="Previous command page"
              disabled={currentPage === 1}
              type="button"
              onClick={() => setPage((value) => Math.max(1, Math.min(value, pageCount) - 1))}
            >
              <ChevronLeft size={16} />
            </button>
            <span>Page {currentPage} of {pageCount}</span>
            <button
              aria-label="Next command page"
              disabled={currentPage === pageCount}
              type="button"
              onClick={() => setPage((value) => Math.min(pageCount, Math.min(value, pageCount) + 1))}
            >
              <ChevronRight size={16} />
            </button>
          </nav>
        ) : null}
      </div>
      {error ? (
        <div className={styles.dataError} role="status">
          <strong>Command history could not be loaded.</strong>
          <span>{error}</span>
        </div>
      ) : commands.length === 0 ? (
        <div className={styles.emptyState}>No rover commands recorded yet.</div>
      ) : (
        <div className={styles.commandList}>
          {visibleCommands.map((command) => (
            <CommandItem command={command} key={command.id} />
          ))}
        </div>
      )}
    </div>
  );
}

function CommandItem({ command }: { command: RoverCommand }) {
  const details = [payloadSummary(command), command.failureDetails ? `Failure: ${command.failureDetails}` : null]
    .filter((value): value is string => Boolean(value));
  const recordedAt = command.executedAt ?? command.acknowledgedAt ?? command.createdAt;
  const timeLabel = commandTimeLabel(command);

  return (
    <article className={styles.commandItem}>
      <div className={styles.commandHeading}>
        <strong>{commandLabel(command.command)}</strong>
        <span className={styles.status} data-status={command.status}>
          {commandStatus(command.status)}
        </span>
      </div>
      <div className={styles.commandMeta}>
        <div className={styles.commandMetaRow}>
          <span>Requested by</span>
          <strong>{command.issuedBy}</strong>
        </div>
        <div className={styles.commandMetaRow}>
          <span>{timeLabel}</span>
          <time dateTime={recordedAt}>{formatDateTime(recordedAt)}</time>
        </div>
      </div>
      {details.length ? <p className={styles.commandDetails}>{details.join(" · ")}</p> : null}
    </article>
  );
}

function commandLabel(command: string) {
  const labels: Record<string, string> = {
    EMERGENCY_STOP: "Emergency stop",
    GET_ROBOT_STATUS: "Check rover status",
    GET_SENSOR_DATA: "Read sensor measurements",
    MOVE_BACKWARD: "Move backward",
    MOVE_FORWARD: "Move forward",
    PAUSE_PLANTING: "Pause planting",
    PING: "Check rover connection",
    REFRESH_CAMERA: "Refresh camera feed",
    RESUME_PLANTING: "Resume planting",
    START_CAMERA: "Start camera",
    START_PLANTING: "Start planting",
    STOP: "Stop rover",
    STOP_CAMERA: "Stop camera",
    STOP_PLANTING: "Stop planting",
    TURN_LEFT: "Turn left",
    TURN_RIGHT: "Turn right",
  };

  if (labels[command]) return labels[command];

  return command
    .toLowerCase()
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function commandStatus(status: string) {
  const labels: Record<string, string> = {
    Busy: "Rover busy",
    Disconnected: "Rover disconnected",
    Failed: "Failed",
    "Invalid Command": "Not supported",
    Pending: "Waiting",
    Sent: "Sent to rover",
    Success: "Completed",
  };

  return labels[status] ?? commandLabel(status);
}

function commandTimeLabel(command: RoverCommand) {
  if (command.executedAt) return command.status === "Success" ? "Completed" : "Processed";
  if (command.acknowledgedAt) return "Rover replied";
  return "Requested";
}

function payloadSummary(command: RoverCommand) {
  const payload = command.payload;
  const values: string[] = [];
  const crop = [payload.seed_name, payload.seed_type, payload.crop_name, payload.crop].find(
    (value): value is string => typeof value === "string" && value.trim().length > 0,
  );

  if (crop) values.push(`Crop: ${humanizeValue(crop)}`);
  if (typeof payload.field_label === "string" && payload.field_label.trim()) {
    values.push(`Field: ${payload.field_label.trim()}`);
  }
  if (typeof payload.speed === "number") values.push(`Travel speed: ${payload.speed}%`);
  if (typeof payload.row_spacing_cm === "number") values.push(`Row spacing: ${payload.row_spacing_cm} cm`);
  if (typeof payload.notes === "string" && payload.notes.trim()) {
    values.push(`Note: ${payload.notes.trim()}`);
  }

  return values.length ? values.join(" · ") : null;
}

function humanizeValue(value: string) {
  return value
    .trim()
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
