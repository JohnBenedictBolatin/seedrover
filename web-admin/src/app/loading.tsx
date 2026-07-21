import styles from "./loading.module.css";

export default function Loading() {
  return (
    <main className={styles.loadingScreen} aria-label="Loading SeedRover">
      <div className={styles.banterLoader} role="status" aria-live="polite">
        <span className={styles.loadingText}>Loading SeedRover</span>
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
        <div className={styles.banterLoaderBox} />
      </div>
    </main>
  );
}
