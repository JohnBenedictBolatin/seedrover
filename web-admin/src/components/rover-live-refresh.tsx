"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useTransition } from "react";
import { RefreshCw } from "lucide-react";
import { startVisiblePolling } from "@/lib/visible-polling.mjs";
import styles from "./rover-live-refresh.module.css";

export function RoverLiveRefresh() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const refreshing = useRef(false);
  const polling = useRef<ReturnType<typeof startVisiblePolling> | null>(null);
  useEffect(() => {
    if (!isPending) refreshing.current = false;
  }, [isPending]);
  const refresh = useCallback(() => {
    if (refreshing.current) return;
    refreshing.current = true;
    startTransition(() => router.refresh());
  }, [router]);
  useEffect(() => {
    const controller = startVisiblePolling({
      task: refresh, intervalMs: 30_000, runOnStart: false,
    });
    polling.current = controller;
    return () => {
      controller.stop();
      polling.current = null;
    };
  }, [refresh]);
  return (
    <div className={styles.controls}>
      <button type="button" className={styles.button} disabled={isPending}
        onClick={() => void polling.current?.run()} aria-busy={isPending}>
        <RefreshCw size={16} aria-hidden="true" />
        {isPending ? "Refreshing…" : "Refresh now"}
      </button>
      <span>Updates every 30 seconds while this page is visible.</span>
    </div>
  );
}
