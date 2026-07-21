import Image from "next/image";
import styles from "./brand-mark.module.css";

type BrandMarkProps = {
  compact?: boolean;
};

export function BrandMark({ compact = false }: BrandMarkProps) {
  if (compact) {
    return null;
  }

  return (
    <div className={styles.brand} aria-label="SeedRover">
      <Image
        alt="SeedRover"
        className={`${styles.logo} ${styles.logoDark}`}
        height={46}
        priority
        src="/brand/seedrover-sidebar.png"
        width={138}
      />
      <Image
        alt="SeedRover"
        className={`${styles.logo} ${styles.logoLight}`}
        height={46}
        priority
        src="/brand/seedrover-sidebar-light.png"
        width={138}
      />
    </div>
  );
}
