"use client";

import { useEffect, useRef, type KeyboardEvent } from "react";
import { AlertTriangle, CheckCircle2, Info, X } from "lucide-react";
import type { ActionAlert } from "./action-alert-stack";
import styles from "./confirmation-dialog.module.css";

export function ActionResultDialog({ alert, onClose }: { alert: ActionAlert; onClose: () => void }) {
  const dialogRef = useRef<HTMLElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const onCloseRef = useRef(onClose);
  const titleId = `result-title-${alert.id}`;

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    closeRef.current?.focus();
    const timer = window.setTimeout(() => onCloseRef.current(), 3000);
    return () => {
      window.clearTimeout(timer);
      returnFocusRef.current?.focus();
    };
  }, [alert.id]);

  function onKeyDown(event: KeyboardEvent<HTMLElement>) {
    if (event.key === "Escape") {
      event.preventDefault();
      onClose();
      return;
    }
    if (event.key !== "Tab") return;
    event.preventDefault();
    closeRef.current?.focus();
  }

  const tone = alert.tone === "error" ? "danger" : alert.tone === "warning" ? "warning" : "default";
  return <div className={styles.backdrop} data-ui-backdrop="true" data-ui-confirmation-backdrop="true" role="presentation">
    <section aria-labelledby={titleId} aria-modal="true" className={styles.modal} data-tone={tone} onKeyDown={onKeyDown} ref={dialogRef} tabIndex={-1} role="dialog">
      <button aria-label="Close message" className={styles.closeButton} ref={closeRef} type="button" onClick={onClose}><X size={18} /></button>
      <div className={styles.iconWrap} aria-hidden="true">
        {alert.tone === "success" ? <CheckCircle2 size={26} /> : alert.tone === "info" ? <Info size={26} /> : <AlertTriangle size={26} />}
      </div>
      <h2 className={styles.resultMessage} id={titleId} role={alert.tone === "error" ? "alert" : "status"} aria-live={alert.tone === "error" ? "assertive" : "polite"}>{alert.text}</h2>
    </section>
  </div>;
}
