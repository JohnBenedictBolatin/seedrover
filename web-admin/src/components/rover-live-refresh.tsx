"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

export function RoverLiveRefresh() {
  const router = useRouter();
  useEffect(() => {
    const timer = window.setInterval(() => router.refresh(), 2_000);
    return () => window.clearInterval(timer);
  }, [router]);
  return null;
}
