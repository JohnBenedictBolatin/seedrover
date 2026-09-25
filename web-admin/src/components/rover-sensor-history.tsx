"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";
import { useState } from "react";
import type { RoverSensorReading } from "@/lib/rover";
import { formatDateTime } from "@/lib/format";
import styles from "@/app/(portal)/rover-monitor/page.module.css";

const pageSize = 10;

export function SensorHistoryTable({ readings }: { readings: RoverSensorReading[] }) {
  const [page, setPage] = useState(1);
  const pageCount = Math.max(1, Math.ceil(readings.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const start = (currentPage - 1) * pageSize;
  const visibleReadings = readings.slice(start, start + pageSize);

  if (readings.length === 0) {
    return <div className={styles.emptyState}>No sensor readings saved yet.</div>;
  }

  return (
    <>
      <div className={styles.sensorTableWrap}>
        <table className={styles.sensorTable}>
          <thead>
            <tr>
              <th scope="col">Recorded</th>
              <th scope="col">Soil moisture (%)</th>
              <th scope="col">Raw soil probe (ADC)</th>
              <th scope="col">Soil temp (°C)</th>
              <th scope="col">Air temp (°C)</th>
              <th scope="col">Humidity (%)</th>
              <th scope="col">Source</th>
              <th scope="col">Trust</th>
            </tr>
          </thead>
          <tbody>
            {visibleReadings.map((reading) => (
              <tr key={reading.id}>
                <td data-label="Recorded">
                  <time dateTime={reading.recordedAt}>{formatDateTime(reading.recordedAt)}</time>
                </td>
                <SensorValue label="Soil moisture (%)" value={reading.soilMoisture} unit="%" />
                <SensorValue label="Raw soil probe (ADC)" value={reading.soilRaw} unit="" />
                <SensorValue label="Soil temp (°C)" value={reading.soilTemperature} unit="°C" />
                <SensorValue label="Air temp (°C)" value={reading.environmentalTemperature} unit="°C" />
                <SensorValue label="Humidity (%)" value={reading.humidity} unit="%" />
                <td data-label="Source">{reading.source || "Unavailable"}</td>
                <td data-label="Trust">
                  {reading.provenanceStatus === "verified_hardware" ? "Verified hardware" : reading.provenanceStatus === "demo" ? "Demo" : reading.provenanceStatus === "simulated" ? "Simulated" : "Unverified"} · {reading.fresh ? "Fresh" : "Stale"}
                  {reading.soilMoistureCalibrated === true ? ` · calibration ${reading.calibrationVersion ?? "version unavailable"}` : reading.soilMoistureCalibrated === false ? " · moisture % unavailable, probe not calibrated" : " · moisture calibration status unavailable"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pageCount > 1 ? (
        <nav className={styles.pagination} aria-label="Sensor reading history pagination">
          <button
            aria-label="Previous sensor readings page"
            disabled={currentPage === 1}
            type="button"
            onClick={() => setPage((value) => Math.max(1, Math.min(value, pageCount) - 1))}
          >
            <ChevronLeft size={17} />
          </button>
          <span>
            Page {currentPage} of {pageCount}
          </span>
          <button
            aria-label="Next sensor readings page"
            disabled={currentPage === pageCount}
            type="button"
            onClick={() => setPage((value) => Math.min(pageCount, Math.min(value, pageCount) + 1))}
          >
            <ChevronRight size={17} />
          </button>
        </nav>
      ) : null}
    </>
  );
}

function SensorValue({ label, unit, value }: { label: string; unit: string; value: number | null }) {
  return (
    <td data-label={label}>
      {value == null ? "Unavailable" : `${formatSensorValue(value)}${unit}`}
    </td>
  );
}

function formatSensorValue(value: number) {
  return new Intl.NumberFormat("en-PH", {
    maximumFractionDigits: Number.isInteger(value) ? 0 : 1,
  }).format(value);
}
