import { redirect } from "next/navigation";
import { getCurrentAdminProfile } from "@/lib/auth";
import { formatDateTime } from "@/lib/format";
import { getRoverMonitor } from "@/lib/rover";
import styles from "./page.module.css";

export default async function RoverMonitorPage() {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  if (profile.roleName === "Farm Inventory Manager") {
    redirect("/dashboard");
  }

  const { status, commands, error } = await getRoverMonitor();

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>Farm supervision</p>
          <h1>Rover Monitor</h1>
          <p>
            Read-only rover status and activity monitoring for managers. Control actions stay
            in the mobile app.
          </p>
        </div>
        <span className={styles.readOnly}>Read only</span>
      </header>

      {error ? (
        <section className={styles.notice}>
          <strong>Rover status is not available yet.</strong>
          <span>{error}</span>
        </section>
      ) : null}

      <section className={styles.metricGrid} aria-label="Rover status summary">
        <article className={styles.metric}>
          <p>Status</p>
          <strong>{status?.roverStatus ?? "Unknown"}</strong>
        </article>
        <article className={styles.metric}>
          <p>Battery</p>
          <strong className="mono">{status ? `${status.batteryLevel}%` : "--"}</strong>
        </article>
        <article className={styles.metric}>
          <p>Seed level</p>
          <strong className="mono">{status ? `${status.seedLevel}%` : "--"}</strong>
        </article>
        <article className={styles.metric}>
          <p>Speed</p>
          <strong className="mono">{status ? `${status.speed}%` : "--"}</strong>
        </article>
      </section>

      <section className={styles.contentGrid}>
        <article className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>Current state</p>
              <h2>Device health</h2>
            </div>
          </div>

          {status ? (
            <div className={styles.healthGrid}>
              <div>
                <span>Current activity</span>
                <strong>{status.currentActivity}</strong>
              </div>
              <div>
                <span>Wi-Fi</span>
                <strong>{status.wifiConnected ? "Connected" : "Disconnected"}</strong>
              </div>
              <div>
                <span>Bluetooth</span>
                <strong>
                  {status.bluetoothConnected ? "Connected" : "Disconnected"}
                </strong>
              </div>
              <div>
                <span>Camera</span>
                <strong>{status.cameraConnected ? "Connected" : "Disconnected"}</strong>
              </div>
              <div>
                <span>Emergency stop</span>
                <strong className={status.emergencyStop ? styles.danger : ""}>
                  {status.emergencyStop ? "Active" : "Inactive"}
                </strong>
              </div>
              <div>
                <span>Last update</span>
                <strong>{formatDateTime(status.lastUpdated)}</strong>
              </div>
            </div>
          ) : (
            <div className={styles.emptyState}>
              <strong>No active rover status row found.</strong>
              <span>The monitor will populate once rover status data is available.</span>
            </div>
          )}
        </article>

        <article className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>Recent activity</p>
              <h2>Command history</h2>
            </div>
          </div>

          {commands.length === 0 ? (
            <div className={styles.emptyState}>
              <strong>No rover commands found.</strong>
              <span>Recent mobile rover activity will appear here.</span>
            </div>
          ) : (
            <div className={styles.commandList}>
              {commands.map((command) => (
                <div className={styles.commandItem} key={command.id}>
                  <div>
                    <strong>{command.command}</strong>
                    <span>{command.issuedBy}</span>
                  </div>
                  <span>{command.status}</span>
                  <small>{formatDateTime(command.createdAt)}</small>
                </div>
              ))}
            </div>
          )}
        </article>
      </section>
    </div>
  );
}
