import { useEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import styles from "./pending-action-label.module.css";

export function PendingActionLabel({
  children,
  pending,
  pendingText,
}: {
  children: ReactNode;
  pending: boolean;
  pendingText: string;
}) {
  const labelRef = useRef<HTMLSpanElement>(null);
  const disabledControls = useRef<Map<HTMLFormElement, Array<[HTMLButtonElement | HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement, boolean]>>>(new Map());
  const [form, setForm] = useState<HTMLFormElement | null>(null);
  const [pendingUi, setPendingUi] = useState({ pending, slow: false });
  if (pendingUi.pending !== pending) setPendingUi({ pending, slow: false });

  useEffect(() => {
    const nextForm = labelRef.current?.closest("form") ?? null;
    setForm(nextForm);
    if (!nextForm) return;
    const previousPosition = nextForm.style.position;
    const previousBusy = nextForm.getAttribute("aria-busy");
    const currentControls = () => Array.from(nextForm.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLButtonElement>(
      "input, select, textarea, button",
    )).map((control) => [control, control.disabled] as [typeof control, boolean]);
    if (!disabledControls.current.has(nextForm)) {
      disabledControls.current.set(nextForm, currentControls());
    }
    if (pending) {
      if (getComputedStyle(nextForm).position === "static") nextForm.style.position = "relative";
      nextForm.setAttribute("aria-busy", "true");
      for (const [control] of disabledControls.current.get(nextForm) ?? []) control.disabled = true;
    } else {
      if (nextForm.style.position === "relative" && previousPosition !== "relative") nextForm.style.position = previousPosition;
      if (previousBusy === null) nextForm.removeAttribute("aria-busy");
      else nextForm.setAttribute("aria-busy", previousBusy);
      for (const [control, disabled] of disabledControls.current.get(nextForm) ?? []) control.disabled = disabled;
      disabledControls.current.set(nextForm, currentControls());
    }
    return () => {
      if (nextForm.style.position === "relative" && previousPosition !== "relative") nextForm.style.position = previousPosition;
      if (previousBusy === null) nextForm.removeAttribute("aria-busy");
      else nextForm.setAttribute("aria-busy", previousBusy);
    };
  }, [pending]);

  useEffect(() => {
    if (!pending) return;
    const timer = window.setTimeout(() => setPendingUi({ pending: true, slow: true }), 10_000);
    return () => window.clearTimeout(timer);
  }, [pending]);

  const slow = pendingUi.slow;

  return (
    <>
    <span className="pendingActionLabel" ref={labelRef} aria-live={pending ? "polite" : undefined}>
      {pending ? (
        <>
          <span aria-hidden="true" className="pendingActionSpinner" />
          <span>{pendingText}</span>
        </>
      ) : children}
    </span>
    {pending && form ? createPortal(
      <div className={styles.formBusyOverlay} role="status" aria-live="polite">
        <span aria-hidden="true" className="pendingActionSpinner" />
        <span>{slow ? "This is taking longer than usual. Please wait." : pendingText}</span>
      </div>,
      form,
    ) : null}
    </>
  );
}
