"use client";

import { useEffect, useState } from "react";

export function LiveDateTime() {
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    setNow(new Date());

    const timer = window.setInterval(() => {
      setNow(new Date());
    }, 1000);

    return () => window.clearInterval(timer);
  }, []);

  if (!now) {
    return (
      <div>
        <p suppressHydrationWarning>Loading date</p>
        <strong suppressHydrationWarning>--:--:-- --</strong>
      </div>
    );
  }

  const date = new Intl.DateTimeFormat("en-PH", {
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric",
  }).format(now);

  const time = new Intl.DateTimeFormat("en-PH", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  }).format(now);

  return (
    <div>
      <p>{date}</p>
      <strong>{time}</strong>
    </div>
  );
}
