"use client";

import { useEffect, useRef, useState } from "react";
import { CheckCircle2, CloudOff } from "lucide-react";
import { startVisiblePolling } from "@/lib/visible-polling.mjs";
import styles from "./connectivity-status.module.css";

type ConnectionState = "connected" | "offline" | "reconnecting" | "restored";

export function ConnectivityStatus({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ConnectionState>("connected");
  const stateRef = useRef<ConnectionState>("connected");

  useEffect(() => {
    let active = true;
    let restoredTimer: number | undefined;
    let request: AbortController | undefined;

    const update = (next: ConnectionState) => {
      stateRef.current = next;
      setState(next);
    };

    const check = async () => {
      if (!navigator.onLine) {
        update("offline");
        return;
      }
      request = new AbortController();
      try {
        const response = await fetch("/api/connectivity", {
          cache: "no-store",
          signal: AbortSignal.any([request.signal, AbortSignal.timeout(6000)]),
        });
        if (!response.ok) throw new Error("Backend unavailable");
        if (!active) return;
        if (!navigator.onLine) {
          update("offline");
          return;
        }
        if (stateRef.current === "offline" || stateRef.current === "reconnecting") {
          update("restored");
          window.clearTimeout(restoredTimer);
          restoredTimer = window.setTimeout(() => update("connected"), 3500);
        } else if (stateRef.current !== "restored") {
          update("connected");
        }
      } catch {
        if (active) update(navigator.onLine ? "reconnecting" : "offline");
      }
    };

    const handleOffline = () => {
      window.clearTimeout(restoredTimer);
      update("offline");
    };
    if (!navigator.onLine) handleOffline();
    const polling = startVisiblePolling({ task: check, intervalMs: 120_000 });
    window.addEventListener("offline", handleOffline);

    return () => {
      active = false;
      polling.stop();
      request?.abort();
      window.clearTimeout(restoredTimer);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  return <>
    {state !== "connected" ? (
      <div className={styles.banner} data-state={state} role="status" aria-live="polite">
        {state === "restored" ? (
          <CheckCircle2 size={18} aria-hidden="true" />
        ) : (
          <CloudOff size={18} aria-hidden="true" />
        )}
        <span>{state === "restored"
          ? "Connection restored. Refreshing data is safe."
          : state === "offline"
            ? "No internet connection. Reconnect to an internet network to save web changes. If a transaction was interrupted, check its record before retrying."
            : "SeedRover web services are temporarily unavailable. Changes cannot be saved right now. If a transaction was interrupted, check its record before retrying."}</span>
      </div>
    ) : null}
    {children}
  </>;
}
