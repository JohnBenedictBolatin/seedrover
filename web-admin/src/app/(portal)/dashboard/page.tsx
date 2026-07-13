import styles from "./page.module.css";

const metrics = [
  { label: "Sales today", value: "Awaiting data" },
  { label: "Sales this month", value: "Awaiting data" },
  { label: "Inventory value", value: "Awaiting data" },
  { label: "Low stock items", value: "Awaiting data" },
];

const setupItems = [
  "Connect Supabase project",
  "Enable role-based admin access",
  "Create inventory and sales tables",
  "Build receipt and export workflow",
];

export default function DashboardPage() {
  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div>
          <p className={styles.eyebrow}>SeedRover farm console</p>
          <h1>Operations dashboard</h1>
          <p className={styles.subcopy}>
            A clean starting point for farm managers to supervise sales, inventory, crops, and
            rover activity from the web.
          </p>
        </div>
        <span className={styles.phase}>Foundation</span>
      </header>

      <section className={styles.metricGrid} aria-label="Farm metrics">
        {metrics.map((metric) => (
          <article className={styles.metricCard} key={metric.label}>
            <p>{metric.label}</p>
            <strong>{metric.value}</strong>
          </article>
        ))}
      </section>

      <section className={styles.contentGrid}>
        <article className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>Next build steps</p>
              <h2>Sales and inventory core</h2>
            </div>
          </div>
          <div className={styles.steps}>
            {setupItems.map((item, index) => (
              <div className={styles.step} key={item}>
                <span className="mono">{String(index + 1).padStart(2, "0")}</span>
                <p>{item}</p>
              </div>
            ))}
          </div>
        </article>

        <article className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>Inventory watch</p>
              <h2>Low stock</h2>
            </div>
          </div>
          <div className={styles.emptyState}>
            <span className="mono">--</span>
            <p>No inventory records are connected yet.</p>
          </div>
        </article>

        <article className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>Rover monitor</p>
              <h2>Status only</h2>
            </div>
          </div>
          <div className={styles.statusList}>
            <span>Controls are intentionally sidelined for the web console.</span>
            <span>Activity and device health will be read-only.</span>
          </div>
        </article>
      </section>
    </div>
  );
}
