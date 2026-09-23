import {
  Activity,
  Antenna,
  Camera,
  Droplets,
  Radio,
  Sun,
  Thermometer,
  Wifi,
} from "lucide-react";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { CountUpValue } from "@/components/count-up-value";
import { LiveDateTime } from "@/components/live-date-time";
import { ModuleHeaderIntro } from "@/components/module-header-intro";
import { RoverLiveRefresh } from "@/components/rover-live-refresh";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { getRoverMonitor, type RoverCommand, type RoverSensorReading, type RoverStatus } from "@/lib/rover";
import styles from "./page.module.css";
import { pingRoverAction, releaseRoverLeaseAction } from "./actions";

export default async function RoverMonitorPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (["Farm Inventory Manager", "Inventory Staff"].includes(profile.roleName)) {
    redirect("/dashboard");
  }

  const { status, commands, sensors, error } = await getRoverMonitor();

  return (
    <div className={styles.page}>
      <RoverLiveRefresh />
      <header className={styles.header}>
          <ModuleHeaderIntro mascot="rover_monitor">
            <p className={styles.eyebrow}>Farm</p>
            <h1>Rover Monitor</h1>
            <p>Connection status, sensors, planting sessions, and commands.</p>
          </ModuleHeaderIntro>
        <div className={styles.liveDateTime}>
          <LiveDateTime />
        </div>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Rover status is not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Rover status summary">
        <MetricCard icon={<Radio size={20} />} label="Status" value={status?.roverStatus ?? "Unknown"} />
        <MetricCard icon={<Wifi size={20} />} label="Cloud heartbeat" value={status?.heartbeatFresh ? "Current" : "Stale"} />
        <MetricCard icon={<Droplets size={20} />} label="Last soil reading" numeric={sensors != null} suffix="%" value={sensors?.soilMoisture ?? "Unavailable"} />
        <MetricCard icon={<Thermometer size={20} />} label="Last temperature" value={sensors?.environmentalTemperature == null ? "Unavailable" : `${formatSensorValue(sensors.environmentalTemperature)}°C`} />
      </section>

      <section className={styles.monitorGrid}>
        <article className={`${styles.panel} ${styles.cameraPanel}`}>
          <PanelTitle eyebrow="Camera" title="Field View" icon={<Camera size={18} />} />
          <div className={styles.cameraPreview} data-connected="false">
            <Camera size={46} />
            <strong>Local camera feed</strong>
            <span>The ESP32-CAM feed is available only while connected to the rover&apos;s local network.</span>
          </div>
          <div className={styles.pillRow}>
            <StatusPill icon={<Wifi size={15} />} label="Wi-Fi" active={status?.wifiConnected === true} />
          </div>
        </article>

        <article className={styles.panel}>
          <PanelTitle eyebrow="Current state" title="Device health" icon={<Activity size={18} />} />
          {status ? <DeviceHealth status={status} /> : <EmptyState title="No rover status yet." text="Waiting for the rover to report its status." />}
        </article>

        <article className={styles.panel}>
          <PanelTitle eyebrow="Sensors" title="Soil and environment" icon={<Droplets size={18} />} />
          {sensors ? <SensorGrid sensors={sensors} /> : <EmptyState title="No sensor readings yet." />}
        </article>
      </section>

      <section className={styles.commandPanel}>
        <div className={styles.commandPanelTop}>
          <PanelTitle eyebrow="Recent activity" title="Command history" icon={<Antenna size={18} />} />
          <div className={styles.commandActions}>
            <form action={pingRoverAction}>
              <button className={styles.pingButton} type="submit">Ping rover</button>
            </form>
            <form action={releaseRoverLeaseAction}>
              <button className={styles.releaseButton} type="submit">Release control</button>
            </form>
          </div>
        </div>
        <div className={styles.commandLayout}>
          <div className={styles.historyWrap}>
            {commands.length === 0 ? (
              <EmptyState title="No rover commands yet." />
            ) : (
              <div className={styles.commandList}>
                {commands.map((command) => (
                  <CommandItem command={command} key={command.id} />
                ))}
              </div>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}

function MetricCard({
  icon,
  label,
  numeric = false,
  suffix = "",
  value,
}: {
  icon: ReactNode;
  label: string;
  numeric?: boolean;
  suffix?: string;
  value: number | string;
}) {
  return (
    <article className={styles.metric}>
      <div className={styles.metricMeta}>
        <span className={styles.metricIcon}>{icon}</span>
        <p>{label}</p>
      </div>
      {numeric ? (
        <div className={styles.metricValue}>
          <CountUpValue className="mono" value={Number(value)} />
          <span>{suffix}</span>
        </div>
      ) : (
        <strong>{value}</strong>
      )}
    </article>
  );
}

function PanelTitle({ eyebrow, icon, title }: { eyebrow: string; icon: ReactNode; title: string }) {
  return (
    <div className={styles.panelHeader}>
      <div>
        <p className={styles.eyebrow}>{eyebrow}</p>
        <h2>
          <span>{icon}</span>
          {title}
        </h2>
      </div>
    </div>
  );
}

function DeviceHealth({ status }: { status: RoverStatus }) {
  const items = [
    ["Current activity", status.currentActivity],
    ["Emergency stop", status.emergencyStop ? "Active" : "Inactive"],
    ["Last update", formatDateTime(status.lastUpdated)],
    ["Connection mode", status.wifiConnected ? "Cloud heartbeat via Wi-Fi" : "Offline / stale"],
  ];

  return (
    <div className={styles.healthGrid}>
      {items.map(([label, value]) => (
        <div key={label}>
          <span>{label}</span>
          <strong className={label === "Emergency stop" && value === "Active" ? styles.danger : ""}>
            {value}
          </strong>
        </div>
      ))}
    </div>
  );
}

function SensorGrid({ sensors }: { sensors: RoverSensorReading }) {
  const sensorItems = [
    { label: "Soil Moisture", value: sensors.soilMoisture, unit: "%", icon: <Droplets size={20} />, status: moistureStatus(sensors.soilMoisture) },
    { label: "Soil Temp", value: sensors.soilTemperature, unit: "°C", icon: <Thermometer size={20} />, status: null },
    { label: "Temperature", value: sensors.environmentalTemperature, unit: "°C", icon: <Sun size={20} />, status: null },
    { label: "Humidity", value: sensors.humidity, unit: "%", icon: <Droplets size={20} />, status: null },
  ];

  return (
    <div className={styles.sensorGrid}>
      {sensorItems.map((sensor) => (
        <div className={styles.sensorCard} data-status={sensor.status ?? "Unavailable"} key={sensor.label}>
          <span>{sensor.icon}</span>
          <div>
            <small>{sensor.label}</small>
            <strong>
              {sensor.value == null ? "Unavailable" : `${formatSensorValue(sensor.value)}${sensor.unit}`}
            </strong>
          </div>
          <em>{sensor.value == null ? "Not measured" : sensor.status ?? "Recorded"}</em>
        </div>
      ))}
      <time>{sensors.fresh ? "Live reading" : "Last recorded reading"} · {sensors.source} · {formatDateTime(sensors.recordedAt)}</time>
    </div>
  );
}

function CommandItem({ command }: { command: RoverCommand }) {
  return (
    <article className={styles.commandItem}>
      <div>
        <strong>{commandLabel(command.command)}</strong>
        <span>{command.issuedBy}</span>
      </div>
      <span className={styles.status} data-status={command.status}>{command.status}</span>
      <small>{payloadSummary(command)}</small>
      <time>{formatDateTime(command.executedAt ?? command.createdAt)}</time>
    </article>
  );
}

function StatusPill({
  active,
  icon,
  label,
}: {
  active: boolean;
  icon: ReactNode;
  label: string;
}) {
  return (
    <span className={styles.statusPill} data-active={active ? "true" : "false"}>
      {icon}
      {label} {active ? "ON" : "OFF"}
    </span>
  );
}

function EmptyState({ text, title }: { text?: string; title: string }) {
  return (
    <div className={styles.emptyState}>
      <strong>{title}</strong>
      {text ? <span>{text}</span> : null}
    </div>
  );
}

function commandLabel(command: string) {
  return command
    .toLowerCase()
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function payloadSummary(command: RoverCommand) {
  const speed = command.payload.speed;
  const seedName = command.payload.seed_name;

  if (typeof seedName === "string") {
    return seedName;
  }

  if (typeof speed === "number") {
    return `Speed ${speed}%`;
  }

  if (command.command === "PING" && command.acknowledgedAt) {
    return `PONG in ${Math.max(0, new Date(command.acknowledgedAt).getTime() - new Date(command.createdAt).getTime())} ms`;
  }

  if (command.failureDetails) return command.failureDetails;

  return command.executedAt ? "Executed" : "Queued";
}

function moistureStatus(value: number) {
  if (value >= 35 && value <= 55) {
    return "Good";
  }

  if (value >= 25 && value <= 70) {
    return "Moderate";
  }

  return "Needs Attention";
}

function formatSensorValue(value: number) {
  return new Intl.NumberFormat("en-PH", {
    maximumFractionDigits: Number.isInteger(value) ? 0 : 1,
  }).format(value);
}
