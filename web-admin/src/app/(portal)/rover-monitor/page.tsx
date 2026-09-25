import {
  Activity,
  Clock3,
  Droplets,
  Radio,
  ShieldAlert,
  Sun,
  Thermometer,
  Wifi,
} from "lucide-react";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { RoverCommandHistory } from "@/components/rover-command-history";
import { RoverLiveRefresh } from "@/components/rover-live-refresh";
import { SensorHistoryTable } from "@/components/rover-sensor-history";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { getRoverMonitor, type RoverSensorReading, type RoverStatus } from "@/lib/rover";
import styles from "./page.module.css";

export default async function RoverMonitorPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Inventory Manager", "Inventory Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const { status, commands, sensors, sensorHistory, statusError, commandError, sensorError } =
    await getRoverMonitor({ commandLimit: 100 });

  return (
    <div className={styles.page}>
      <RoverLiveRefresh />
      <header className={styles.header}>
        <ModuleHeaderIntro mascot="rover_monitor">
          <p className={styles.eyebrow}>Farm</p>
          <h1>Rover Monitor</h1>
          <p>Rover state, sensor readings, and command history.</p>
        </ModuleHeaderIntro>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      <section className={styles.statusPanel} aria-label="Rover status summary">
        {statusError ? <DataError title="Rover status is unavailable." message={statusError} /> : null}
        <div className={styles.statusGrid}>
          <StatusSummary icon={<Radio size={17} />} label="Rover status">
            {status?.roverStatus ?? "Unavailable"}
          </StatusSummary>
          <StatusSummary icon={<Activity size={17} />} label="Cloud heartbeat">
            {status?.heartbeatFresh == null ? "Unavailable" : status.heartbeatFresh ? "Current" : "Stale"}
          </StatusSummary>
          <StatusSummary icon={<Wifi size={17} />} label="Wi-Fi">
            {reportedValue(
              status?.wifiConnected == null ? null : status.wifiConnected ? "Connected" : "Disconnected",
              status?.heartbeatFresh,
            )}
          </StatusSummary>
          <StatusSummary icon={<ShieldAlert size={17} />} label="Emergency stop">
            {reportedValue(
              status?.emergencyStop == null ? null : status.emergencyStop ? "Active" : "Inactive",
              status?.heartbeatFresh,
            )}
          </StatusSummary>
          <StatusSummary icon={<Activity size={17} />} label="Current activity">
            {reportedValue(status?.currentActivity ?? null, status?.heartbeatFresh)}
          </StatusSummary>
          <StatusSummary icon={<Clock3 size={17} />} label="Last update">
            {status?.lastUpdated ? formatDateTime(status.lastUpdated) : "Unavailable"}
          </StatusSummary>
        </div>
      </section>

      <section className={styles.monitorGrid} aria-label="Rover monitoring details">
        <article className={styles.panel}>
          <PanelTitle title="Sensor readings" icon={<Droplets size={18} />} />
          {sensorError ? <DataError title="Sensor readings could not be loaded." message={sensorError} /> : null}
          <LatestSensors history={sensorHistory} sensors={sensors} />
          <p className={styles.latestMeta}>
            {sensors ? `Verified hardware · ${sensors.source || "Source unavailable"} · ${formatDateTime(sensors.recordedAt)} · ${sensors.fresh ? "Fresh" : "Stale"} · ${sensors.soilMoistureCalibrated === true ? `moisture calibration ${sensors.calibrationVersion ?? "version unavailable"}` : sensors.soilMoistureCalibrated === false ? "moisture % unavailable · probe not calibrated" : "moisture calibration status unavailable"}` : "No fresh, verified hardware reading is available."}
          </p>
          <div className={styles.historySection}>
            <div className={styles.historyHeading}>
              <div>
                <h3>Reading history</h3>
                <p>Newest first · up to 100 saved readings</p>
              </div>
              <span>{sensorError ? "Unavailable" : `${sensorHistory.length} readings`}</span>
            </div>
            {sensorError ? (
              <EmptyState title="History unavailable." />
            ) : (
              <SensorHistoryTable readings={sensorHistory} />
            )}
          </div>
        </article>

        <aside className={`${styles.panel} ${styles.commandPanel}`} aria-label="Command history">
          <RoverCommandHistory commands={commands} error={commandError} />
        </aside>
      </section>
    </div>
  );
}

function StatusSummary({
  children,
  icon,
  label,
}: {
  children: ReactNode;
  icon: ReactNode;
  label: string;
}) {
  return (
    <div className={styles.statusSummary}>
      <span className={styles.statusIcon}>{icon}</span>
      <div>
        <span>{label}</span>
        <strong>{children}</strong>
      </div>
    </div>
  );
}

function PanelTitle({ icon, title }: { icon: ReactNode; title: string }) {
  return (
    <div className={styles.panelHeader}>
      <div>
        <h2>
          <span>{icon}</span>
          {title}
        </h2>
      </div>
    </div>
  );
}

type SensorField = "soilMoisture" | "soilTemperature" | "environmentalTemperature" | "humidity";

function LatestSensors({
  history,
  sensors,
}: {
  history: RoverSensorReading[];
  sensors: RoverSensorReading | null;
}) {
  const items: Array<{
    label: string;
    field: SensorField;
    value: number | null;
    unit: string;
    tone: "water" | "soil" | "air" | "humidity";
    icon: ReactNode;
  }> = [
    { label: "Soil moisture", field: "soilMoisture", value: sensors?.soilMoisture ?? null, unit: "%", tone: "water", icon: <Droplets size={19} /> },
    { label: "Soil temperature", field: "soilTemperature", value: sensors?.soilTemperature ?? null, unit: "°C", tone: "soil", icon: <Thermometer size={19} /> },
    { label: "Air temperature", field: "environmentalTemperature", value: sensors?.environmentalTemperature ?? null, unit: "°C", tone: "air", icon: <Sun size={19} /> },
    { label: "Humidity", field: "humidity", value: sensors?.humidity ?? null, unit: "%", tone: "humidity", icon: <Droplets size={19} /> },
  ];
  const recentHistory = history
    .filter((reading) => reading.provenanceStatus === "verified_hardware" && reading.fresh)
    .slice(0, 12)
    .reverse();

  return (
    <section className={styles.sensorMetrics} aria-label="Latest sensor values">
      {items.map((sensor) => (
        <div className={styles.sensorMetric} data-tone={sensor.tone} key={sensor.label}>
          <div className={styles.sensorMetricTitle}>
            <span className={styles.sensorIcon}>{sensor.icon}</span>
            <small>{sensor.label}</small>
          </div>
          <div className={styles.sensorValue}>
            {sensor.value == null ? (
              <strong className={styles.unavailableValue}>Unavailable</strong>
            ) : (
              <>
                <strong>{formatSensorValue(sensor.value)}</strong>
                <span>{sensor.unit}</span>
              </>
            )}
          </div>
          <SensorTrend
            label={sensor.label}
            readings={recentHistory
              .map((reading) => reading[sensor.field])
              .filter((value): value is number => typeof value === "number")}
            unit={sensor.unit}
          />
        </div>
      ))}
    </section>
  );
}

function SensorTrend({ label, readings, unit }: { label: string; readings: number[]; unit: string }) {
  const width = 240;
  const height = 56;
  const inset = 5;
  const low = readings.length ? Math.min(...readings) : null;
  const high = readings.length ? Math.max(...readings) : null;
  const spread = low == null || high == null || high === low ? 1 : high - low;
  const points = readings.map((value, index) => ({
    x: readings.length === 1 ? width - inset : inset + (index / (readings.length - 1)) * (width - inset * 2),
    y: low === high ? height / 2 : height - inset - ((value - (low ?? 0)) / spread) * (height - inset * 2),
    value,
  }));
  const linePath = points
    .map((point, index) => `${index === 0 ? "M" : "L"}${point.x.toFixed(1)},${point.y.toFixed(1)}`)
    .join(" ");
  const firstPoint = points[0];
  const lastPoint = points[points.length - 1];
  const areaPath = firstPoint && lastPoint
    ? `${linePath} L${lastPoint.x.toFixed(1)},${height} L${firstPoint.x.toFixed(1)},${height} Z`
    : "";

  return (
    <div className={styles.sensorTrend}>
      {points.length ? (
        <svg
          aria-label={`${label} trend across ${points.length} recent readings`}
          className={styles.trendChart}
          preserveAspectRatio="none"
          role="img"
          viewBox={`0 0 ${width} ${height}`}
        >
          <path d={areaPath} fill="currentColor" opacity="0.12" />
          <path d={linePath} fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" />
          {lastPoint ? <circle cx={lastPoint.x} cy={lastPoint.y} fill="currentColor" r="4" /> : null}
        </svg>
      ) : (
        <div className={styles.emptyTrend} aria-hidden="true" />
      )}
      <div className={styles.trendMeta}>
        {low == null || high == null ? (
          <span>No measurements</span>
        ) : (
          <>
            <span>Low {formatSensorValue(low)}{unit}</span>
            <span>{readings.length} samples</span>
            <span>High {formatSensorValue(high)}{unit}</span>
          </>
        )}
      </div>
    </div>
  );
}

function DataError({ title, message }: { title: string; message: string }) {
  return (
    <div className={styles.dataError} role="status">
      <strong>{title}</strong>
      <span>{message}</span>
    </div>
  );
}

function EmptyState({ title }: { title: string }) {
  return <div className={styles.emptyState}>{title}</div>;
}

function reportedValue(value: string | null, heartbeatFresh: boolean | null | undefined) {
  if (value == null || value.length === 0) return "Unavailable";
  return heartbeatFresh === false ? `${value} · last reported` : value;
}

function formatSensorValue(value: number) {
  return new Intl.NumberFormat("en-PH", {
    maximumFractionDigits: Number.isInteger(value) ? 0 : 1,
  }).format(value);
}
