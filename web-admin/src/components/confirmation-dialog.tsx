"use client";

import { useCallback, useRef, useState } from "react";
import { AlertTriangle, CheckCircle2, X } from "lucide-react";
import styles from "./confirmation-dialog.module.css";

export type ConfirmationTone = "default" | "danger";

export type ConfirmationOptions = {
  title?: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: ConfirmationTone;
};

type PendingConfirmation = Required<ConfirmationOptions> & {
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
        cancelLabel: options.cancelLabel ?? "Close",
        tone: options.tone ?? "default",
      });
    });
  }, []);

  const dialog = pending ? (
    <ConfirmationDialog
      key={pending.id}
      options={pending}
      onCancel={() => close(false)}
      onConfirm={() => close(true)}
    />
  ) : null;

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

  return (
    <div className={styles.backdrop} role="presentation">
      <section
        aria-label={options.title}
        aria-modal="true"
        className={styles.modal}
        data-tone={options.tone}
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

        <h2>{options.title}</h2>
        <p>{options.message}</p>

        <div className={styles.actions}>
          <button className={styles.cancelButton} type="button" onClick={onCancel}>
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
