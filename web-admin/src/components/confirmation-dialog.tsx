"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode, type KeyboardEvent } from "react";
import { createPortal } from "react-dom";
import { AlertTriangle, CheckCircle2, X } from "lucide-react";
import styles from "./confirmation-dialog.module.css";

export type ConfirmationTone = "default" | "danger";

export type ConfirmationOptions = {
  title?: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: ConfirmationTone;
  summary?: ReactNode;
};

type PendingConfirmation = Omit<Required<ConfirmationOptions>, "summary"> & {
  summary?: ReactNode;
  id: number;
};

export function useConfirmationDialog() {
  const resolverRef = useRef<((confirmed: boolean) => void) | null>(null);
  const [pending, setPending] = useState<PendingConfirmation | null>(null);

  const close = useCallback((confirmed: boolean) => {
    resolverRef.current?.(confirmed);
    resolverRef.current = null;
    setPending(null);
  }, []);

  const confirm = useCallback((options: ConfirmationOptions) => {
    resolverRef.current?.(false);

    return new Promise<boolean>((resolve) => {
      resolverRef.current = resolve;
      setPending({
        id: Date.now(),
        title: options.title ?? "Are you sure?",
        message: options.message,
        confirmLabel: options.confirmLabel ?? "Confirm",
        cancelLabel: options.cancelLabel ?? "Cancel",
        tone: options.tone ?? "default",
        summary: options.summary,
      });
    });
  }, []);

  const dialog = pending && typeof document !== "undefined" ? createPortal((
    <ConfirmationDialog
      key={pending.id}
      options={pending}
      onCancel={() => close(false)}
      onConfirm={() => close(true)}
    />
  ), document.body) : null;

  return { confirm, confirmationDialog: dialog };
}

function ConfirmationDialog({
  onCancel,
  onConfirm,
  options,
}: {
  onCancel: () => void;
  onConfirm: () => void;
  options: PendingConfirmation;
}) {
  const isDanger = options.tone === "danger";
  const dialogRef = useRef<HTMLElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const titleId = `confirmation-title-${options.id}`;
  const messageId = `confirmation-message-${options.id}`;
  const summaryId = `confirmation-summary-${options.id}`;

  useEffect(() => {
    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    cancelRef.current?.focus();
    return () => returnFocusRef.current?.focus();
  }, []);

  function onKeyDown(event: KeyboardEvent<HTMLElement>) {
    if (event.key === "Escape") {
      event.preventDefault();
      onCancel();
      return;
    }
    if (event.key !== "Tab") return;
    const focusable = dialogRef.current?.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [href], [tabindex]:not([tabindex="-1"])');
    if (!focusable?.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }

  return (
    <div className={styles.backdrop} data-ui-backdrop="true" data-ui-confirmation-backdrop="true" role="presentation">
      <section
        aria-labelledby={titleId}
        aria-describedby={options.summary ? `${messageId} ${summaryId}` : messageId}
        aria-modal="true"
        className={styles.modal}
        data-tone={options.tone}
        onKeyDown={onKeyDown}
        ref={dialogRef}
        tabIndex={-1}
        role="dialog"
      >
        <button
          aria-label="Close confirmation"
          className={styles.closeButton}
          type="button"
          onClick={onCancel}
        >
          <X size={18} />
        </button>

        <div className={styles.iconWrap} aria-hidden="true">
          {isDanger ? <AlertTriangle size={26} /> : <CheckCircle2 size={26} />}
        </div>

        <h2 id={titleId}>{options.title}</h2>
        <p id={messageId}>{options.message}</p>
        {options.summary ? <div className={styles.summary} id={summaryId}>{options.summary}</div> : null}

        <div className={styles.actions}>
          <button ref={cancelRef} className={styles.cancelButton} type="button" onClick={onCancel}>
            <span>{options.cancelLabel}</span>
          </button>
          <button
            className={isDanger ? styles.dangerButton : styles.confirmButton}
            type="button"
            onClick={onConfirm}
          >
            <span>{options.confirmLabel}</span>
          </button>
        </div>
      </section>
    </div>
  );
}
