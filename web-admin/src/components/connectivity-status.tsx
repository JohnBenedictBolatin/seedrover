"use client";

import { useEffect, useRef, useState } from "react";
import { AlertTriangle, CheckCircle2, CloudOff } from "lucide-react";
import styles from "./connectivity-status.module.css";

type ConnectionState = "connected" | "reconnecting" | "restored";

export function ConnectivityStatus({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ConnectionState>("connected");
  const stateRef = useRef<ConnectionState>("connected");
  const checkingRef = useRef(false);

  useEffect(() => {
    let active = true;
    let restoredTimer: number | undefined;

    const update = (next: ConnectionState) => {
      stateRef.current = next;
      setState(next);
    };

    const check = async () => {
      if (!navigator.onLine) {
        update("reconnecting");
        return;
      }
      if (checkingRef.current) return;
      checkingRef.current = true;
      try {
        const response = await fetch("/api/connectivity", {
          cache: "no-store",
          signal: AbortSignal.timeout(6000),
        });
        if (!response.ok) throw new Error("Backend unavailable");
        if (!active) return;
        if (stateRef.current === "reconnecting") {
          update("restored");
          window.clearTimeout(restoredTimer);
          restoredTimer = window.setTimeout(() => update("connected"), 3500);
        } else if (stateRef.current !== "restored") {
          update("connected");
        }
      } catch {
        if (active) update("reconnecting");
      } finally {
        checkingRef.current = false;
      }
    };

    const handleOffline = () => update("reconnecting");
    const handleOnline = () => void check();
    void check();
    const interval = window.setInterval(() => void check(), 20000);
    window.addEventListener("offline", handleOffline);
    window.addEventListener("online", handleOnline);

    return () => {
      active = false;
      window.clearInterval(interval);
      window.clearTimeout(restoredTimer);
      window.removeEventListener("offline", handleOffline);
      window.removeEventListener("online", handleOnline);
    };
  }, []);

  return <>
    {state !== "connected" ? (
      <div className={styles.banner} data-state={state} role="status" aria-live="polite">
        {state === "restored" ? <CheckCircle2 size={18} aria-hidden="true" /> : state === "reconnecting" ? <CloudOff size={18} aria-hidden="true" /> : <AlertTriangle size={18} aria-hidden="true" />}
        <span>{state === "restored"
          ? "Connection restored. Refreshing data is safe."
          : "Reconnecting to SeedRover. Changes cannot be saved while the connection is unavailable. If a transaction was interrupted, check its record before submitting it again."}</span>
      </div>
    ) : null}
    {children}
  </>;
}
