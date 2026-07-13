import styles from "./brand-mark.module.css";

type BrandMarkProps = {
  compact?: boolean;
};

export function BrandMark({ compact = false }: BrandMarkProps) {
  return (
    <div className={styles.brand} aria-label="SeedRover">
      <span className={styles.icon} aria-hidden="true">
        <span className={styles.leaf} />
        <span className={styles.stem} />
      </span>
      {!compact && (
        <span className={styles.copy}>
          <span className={styles.name}>SeedRover</span>
          <span className={styles.label}>Farm Admin</span>
        </span>
      )}
    </div>
  );
}
