"use client";

import { AlertTriangle, CheckCircle2, Info, X } from "lucide-react";
import styles from "./action-alert-stack.module.css";

export type AlertTone = "success" | "info" | "warning" | "error";

export type ActionAlert = {
  id: number;
  tone: AlertTone;
  text: string;
  operationId?: string;
};

export function ActionAlertStack({
  alerts,
  onDismiss,
  onPause,
}: {
  alerts: ActionAlert[];
  onDismiss: (id: number) => void;
  onPause: (id: number, paused: boolean) => void;
}) {
  if (alerts.length === 0) return null;

  return (
    <div className={styles.alertStack}>
      {alerts.map((alert) => (
        <div
          className={styles.alertCard}
          data-tone={alert.tone}
          key={alert.id}
          role={alert.tone === "error" ? "alert" : "status"}
          aria-live={alert.tone === "error" ? "assertive" : "polite"}
          onMouseEnter={() => onPause(alert.id, true)}
          onMouseLeave={(event) => { if (!event.currentTarget.contains(document.activeElement)) onPause(alert.id, false); }}
          onFocus={() => onPause(alert.id, true)}
          onBlur={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null) && !event.currentTarget.matches(":hover")) onPause(alert.id, false); }}
        >
          {alert.tone === "success" ? <CheckCircle2 size={20} /> : alert.tone === "warning" || alert.tone === "error" ? <AlertTriangle size={20} /> : <Info size={20} />}
          <span>{alert.text}</span>
          <button aria-label="Dismiss message" type="button" onClick={() => onDismiss(alert.id)}><X size={16} /></button>
        </div>
      ))}
    </div>
  );
}
