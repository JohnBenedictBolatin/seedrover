"use client";

import { Info } from "lucide-react";
import styles from "./action-alert-stack.module.css";

export type AlertTone = "success" | "info" | "warning" | "error";

export type ActionAlert = {
  id: number;
  tone: AlertTone;
  text: string;
};

export function ActionAlertStack({
  alerts,
  onDismiss,
}: {
  alerts: ActionAlert[];
  onDismiss: (id: number) => void;
}) {
  if (alerts.length === 0) {
    return null;
  }

  return (
    <div className={styles.alertStack}>
      {alerts.map((alert) => (
        <button
          className={styles.alertCard}
          data-tone={alert.tone}
          key={alert.id}
          role="alert"
          type="button"
          onClick={() => onDismiss(alert.id)}
        >
          <Info size={20} />
          <span>{alert.text}</span>
        </button>
      ))}
    </div>
  );
}
