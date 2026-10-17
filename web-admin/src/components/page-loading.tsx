import styles from "./page-loading.module.css";
import loaderStyles from "@/app/loading.module.css";
import type { ReactNode } from "react";

export type PageLoadingVariant =
  | "generic"
  | "dashboard"
  | "inventory"
  | "crops"
  | "sales"
  | "sales-detail"
  | "customers"
  | "notifications"
  | "rover"
  | "investments"
  | "users"
  | "activity"
  | "history";

function Blocks({ count, className = "" }: { count: number; className?: string }) {
  return (
    <>
      {Array.from({ length: count }, (_, index) => (
        <i aria-hidden="true" className={`${styles.block} ${className}`} key={index} />
      ))}
    </>
  );
}

function PageHeader({ action = false }: { action?: boolean }) {
  return (
    <header className={styles.header}>
      <div className={styles.headingText}>
        <Blocks count={1} className={styles.eyebrow} />
        <Blocks count={1} className={styles.title} />
        <Blocks count={1} className={styles.subtitle} />
      </div>
      {action ? <Blocks count={1} className={styles.action} /> : null}
    </header>
  );
}

function Metrics({ count = 4 }: { count?: number }) {
  return (
    <section className={styles.metrics}>
      {Array.from({ length: count }, (_, index) => (
        <div className={styles.metric} key={index}>
          <Blocks count={1} className={styles.metricLabel} />
          <Blocks count={1} className={styles.metricValue} />
        </div>
      ))}
    </section>
  );
}

function Toolbar() {
  return (
    <div className={styles.toolbar}>
      <Blocks count={1} className={styles.search} />
      <Blocks count={2} className={styles.toolbarButton} />
    </div>
  );
}

function Table({ rows = 5, columns = 5 }: { rows?: number; columns?: number }) {
  return (
    <section className={styles.table}>
      <div className={styles.tableHeader} style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}><Blocks count={columns} className={styles.tableCell} /></div>
      {Array.from({ length: rows }, (_, row) => (
        <div className={styles.tableRow} key={row} style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}><Blocks count={columns} className={styles.tableCell} /></div>
      ))}
    </section>
  );
}

function Panel({ className = "", children }: { className?: string; children: ReactNode }) {
  return <section className={`${styles.panel} ${className}`}>{children}</section>;
}

function DashboardSkeleton() {
  return (
    <>
      <Metrics />
      <div className={styles.dashboardGrid}>
        <Panel className={styles.chartPanel}>
          <Blocks count={1} className={styles.panelTitle} />
          <Blocks count={1} className={styles.chart} />
        </Panel>
        <Panel className={styles.chartPanel}>
          <Blocks count={1} className={styles.panelTitle} />
          <Blocks count={1} className={styles.chart} />
        </Panel>
        <Panel className={styles.listPanel}>
          <Blocks count={1} className={styles.panelTitle} />
          <Blocks count={4} className={styles.listRow} />
        </Panel>
      </div>
    </>
  );
}

function InventorySkeleton() {
  return <><Metrics /><Toolbar /><Table columns={6} /></>;
}

function CropsSkeleton() {
  return <><Metrics count={3} /><div className={styles.tabs}><Blocks count={4} className={styles.tab} /></div><Toolbar /><Table columns={5} /></>;
}

function SalesSkeleton() {
  return <><Metrics count={3} /><Toolbar /><Table columns={6} /></>;
}

function CustomersSkeleton() {
  return <><Metrics count={3} /><Toolbar /><div className={styles.tabs}><Blocks count={3} className={styles.tab} /></div><Table columns={5} /></>;
}

function NotificationsSkeleton() {
  return (
    <>
      <Metrics />
      <Panel className={styles.listPanel}>
        <Blocks count={1} className={styles.panelTitle} />
        <Blocks count={5} className={styles.notificationRow} />
      </Panel>
    </>
  );
}

function RoverSkeleton() {
  return (
    <div className={styles.roverGrid}>
      <Panel>
        <Blocks count={1} className={styles.panelTitle} />
        <div className={styles.sensorGrid}><Blocks count={4} className={styles.sensor} /></div>
        <Blocks count={1} className={styles.panelTitle} />
        <Table rows={4} columns={4} />
      </Panel>
      <Panel className={styles.commandPanel}>
        <Blocks count={1} className={styles.panelTitle} />
        <Blocks count={6} className={styles.notificationRow} />
      </Panel>
    </div>
  );
}

function InvestmentsSkeleton() {
  return (
    <>
      <Metrics />
      <div className={styles.dashboardGrid}>
        <Panel className={styles.chartPanel}>
          <Blocks count={1} className={styles.panelTitle} />
          <Blocks count={1} className={styles.chart} />
        </Panel>
        <Panel className={styles.listPanel}>
          <Blocks count={1} className={styles.panelTitle} />
          <Blocks count={4} className={styles.listRow} />
        </Panel>
      </div>
      <Toolbar />
      <Table columns={6} />
    </>
  );
}

function DetailSkeleton() {
  return (
    <>
      <div className={styles.detailGrid}>
        <Panel><Blocks count={1} className={styles.panelTitle} /><Blocks count={5} className={styles.listRow} /></Panel>
        <Panel><Blocks count={1} className={styles.panelTitle} /><Blocks count={4} className={styles.listRow} /></Panel>
      </div>
      <Table rows={4} columns={5} />
    </>
  );
}

function Content({ variant }: { variant: PageLoadingVariant }) {
  switch (variant) {
    case "dashboard":
      return <DashboardSkeleton />;
    case "inventory":
      return <InventorySkeleton />;
    case "crops":
      return <CropsSkeleton />;
    case "sales":
      return <SalesSkeleton />;
    case "sales-detail":
      return <DetailSkeleton />;
    case "customers":
      return <CustomersSkeleton />;
    case "notifications":
      return <NotificationsSkeleton />;
    case "rover":
      return <RoverSkeleton />;
    case "investments":
      return <InvestmentsSkeleton />;
    case "users":
      return <><Metrics count={3} /><Toolbar /><Table columns={5} /></>;
    case "activity":
      return <><Metrics count={3} /><Toolbar /><Table columns={6} /></>;
    case "history":
      return <><Toolbar /><Table columns={7} /></>;
    default:
      return <><Metrics count={3} /><Toolbar /><Table columns={4} /></>;
  }
}

export function PageLoading({ variant = "generic" }: { variant?: PageLoadingVariant }) {
  return (
    <main className={styles.screen} aria-label="Loading page">
      <div className={styles.page} aria-hidden="true">
        <PageHeader action={variant === "inventory" || variant === "sales" || variant === "users"} />
        <Content variant={variant} />
      </div>
      <div className={styles.loaderOverlay}>
        <div className={loaderStyles.banterLoader} role="status" aria-live="polite">
          <span className={loaderStyles.loadingText}>Loading SeedRover</span>
          {Array.from({ length: 9 }, (_, index) => <div className={loaderStyles.banterLoaderBox} key={index} />)}
        </div>
      </div>
    </main>
  );
}
