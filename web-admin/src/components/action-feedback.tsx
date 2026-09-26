"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "./action-alert-stack";

type FeedbackInput = { tone: AlertTone; text: string; operationId?: string };
const FeedbackContext = createContext<{ notify: (input: FeedbackInput) => void } | null>(null);

export function ActionFeedbackProvider({ children }: { children: ReactNode }) {
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);
  const timers = useRef(new Map<number, number>());
  const operations = useRef(new Map<string, number>());
  const scheduleDismiss = useCallback((id: number) => {
    timers.current.set(id, window.setTimeout(() => {
      setAlerts((current) => current.filter((item) => item.id !== id));
      timers.current.delete(id);
      for (const [key, value] of operations.current) if (value === id) operations.current.delete(key);
    }, 5000));
  }, []);
  const notify = useCallback(({ tone, text, operationId }: FeedbackInput) => {
    const id = Date.now() + Math.random();
    if (operationId) {
      const previous = operations.current.get(operationId);
      if (previous !== undefined) {
        window.clearTimeout(timers.current.get(previous));
        timers.current.delete(previous);
      }
      operations.current.set(operationId, id);
    }
    setAlerts((current) => [...current.filter((alert) => !operationId || alert.operationId !== operationId), { id, tone, text, operationId }].slice(-3));
    if (tone === "success" || tone === "info") {
      scheduleDismiss(id);
    }
  }, [scheduleDismiss]);
  const dismiss = useCallback((id: number) => {
    window.clearTimeout(timers.current.get(id));
    timers.current.delete(id);
    for (const [key, value] of operations.current) if (value === id) operations.current.delete(key);
    setAlerts((current) => current.filter((alert) => alert.id !== id));
  }, []);
  const pause = useCallback((id: number, paused: boolean) => {
    if (paused) {
      window.clearTimeout(timers.current.get(id));
      timers.current.delete(id);
      return;
    }
    const alert = alerts.find((item) => item.id === id);
    if (alert && (alert.tone === "success" || alert.tone === "info") && !timers.current.has(id)) scheduleDismiss(id);
  }, [alerts, scheduleDismiss]);
  useEffect(() => () => { for (const timer of timers.current.values()) window.clearTimeout(timer); }, []);
  return <FeedbackContext.Provider value={{ notify }}>
    {children}
    {typeof document !== "undefined" ? createPortal(<ActionAlertStack alerts={alerts} onDismiss={dismiss} onPause={pause} />, document.body) : null}
  </FeedbackContext.Provider>;
}

export function useActionFeedback() {
  const context = useContext(FeedbackContext);
  if (!context) throw new Error("useActionFeedback must be used inside ActionFeedbackProvider.");
  return context;
}
