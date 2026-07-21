"use client";

import { useEffect, useMemo, useState } from "react";

type CountUpValueProps = {
  className?: string;
  currency?: boolean;
  durationMs?: number;
  value: number;
};

export function CountUpValue({
  className,
  currency = false,
  durationMs = 900,
  value,
}: CountUpValueProps) {
  const [displayValue, setDisplayValue] = useState(0);

  useEffect(() => {
    let frame = 0;
    let startTime = 0;

    setDisplayValue(0);

    function step(timestamp: number) {
      if (!startTime) {
        startTime = timestamp;
      }

      const progress = Math.min((timestamp - startTime) / durationMs, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setDisplayValue(value * eased);

      if (progress < 1) {
        frame = window.requestAnimationFrame(step);
      }
    }

    frame = window.requestAnimationFrame(step);

    return () => window.cancelAnimationFrame(frame);
  }, [durationMs, value]);

  const formatted = useMemo(() => {
    if (currency) {
      return new Intl.NumberFormat("en-PH", {
        style: "currency",
        currency: "PHP",
        maximumFractionDigits: 2,
      }).format(displayValue);
    }

    return new Intl.NumberFormat("en-PH", {
      maximumFractionDigits: Number.isInteger(value) ? 0 : 2,
    }).format(displayValue);
  }, [currency, displayValue, value]);

  return <strong className={className}>{formatted}</strong>;
}
