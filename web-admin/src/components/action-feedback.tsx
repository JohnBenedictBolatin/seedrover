"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { ActionAlertStack, type ActionAlert, type AlertTone } from "./action-alert-stack";
import { ActionResultDialog } from "./action-result-dialog";

type FeedbackInput = { tone: AlertTone; text: string; operationId?: string };
type FeedbackContextValue = {
  notify: (input: FeedbackInput) => void;
  clearFeedback: () => void;
};
const FeedbackContext = createContext<FeedbackContextValue | null>(null);

export function ActionFeedbackProvider({ children }: { children: ReactNode }) {
  const [results, setResults] = useState<ActionAlert[]>([]);
  const [alerts, setAlerts] = useState<ActionAlert[]>([]);
  const ids = useRef(0);
  const operations = useRef(new Map<string, number>());
  const timers = useRef(new Map<number, number>());

  const clearFeedback = useCallback(() => {
    for (const timer of timers.current.values()) window.clearTimeout(timer);
    timers.current.clear();
    operations.current.clear();
    setResults([]);
    setAlerts([]);
  }, []);

  const dismissAlert = useCallback((id: number) => {
    window.clearTimeout(timers.current.get(id));
    timers.current.delete(id);
    setAlerts((current) => current.filter((item) => item.id !== id));
  }, []);

  const pauseAlert = useCallback((id: number, paused: boolean) => {
    if (paused) {
      window.clearTimeout(timers.current.get(id));
      timers.current.delete(id);
      return;
    }
    const alert = alerts.find((item) => item.id === id);
    if (alert && !timers.current.has(id)) {
      timers.current.set(id, window.setTimeout(() => dismissAlert(id), 5000));
    }
  }, [alerts, dismissAlert]);

  const notify = useCallback(({ tone, text, operationId }: FeedbackInput) => {
    const id = ++ids.current;
    const alert = { id, tone, text, operationId };
    if (tone === "info") {
      setAlerts((current) => [...current, alert].slice(-3));
      timers.current.set(id, window.setTimeout(() => dismissAlert(id), 5000));
      return;
    }

    if (operationId) {
      const previous = operations.current.get(operationId);
      if (previous !== undefined) {
        setResults((current) => current.map((item) => item.id === previous ? alert : item));
        operations.current.set(operationId, id);
        return;
      }
      operations.current.set(operationId, id);
    }
    setResults((current) => [...current, alert]);
  }, [dismissAlert]);

  const closeResult = useCallback((id: number) => {
    setResults((current) => current.filter((item) => item.id !== id));
    for (const [key, value] of operations.current) if (value === id) operations.current.delete(key);
  }, []);

  useEffect(() => () => { for (const timer of timers.current.values()) window.clearTimeout(timer); }, []);

  const result = results[0];
  return <FeedbackContext.Provider value={{ notify, clearFeedback }}>
    {children}
    {typeof document !== "undefined" ? createPortal(<>
      <ActionAlertStack alerts={alerts} onDismiss={dismissAlert} onPause={pauseAlert} />
      {result ? <ActionResultDialog alert={result} onClose={() => closeResult(result.id)} /> : null}
    </>, document.body) : null}
  </FeedbackContext.Provider>;
}

export function useActionFeedback() {
  const context = useContext(FeedbackContext);
  if (!context) throw new Error("useActionFeedback must be used inside ActionFeedbackProvider.");
  return context;
}
