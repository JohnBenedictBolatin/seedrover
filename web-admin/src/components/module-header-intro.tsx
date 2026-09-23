import type { ReactNode } from "react";
import styles from "./module-header-intro.module.css";

export type ModuleHeaderMascot =
  | "activity_log"
  | "crops"
  | "customers"
  | "dashboard"
  | "inventory"
  | "investments"
  | "rover_monitor"
  | "sales"
  | "users";

export function ModuleHeaderIntro({
  children,
  mascot,
}: {
  children: ReactNode;
  mascot: ModuleHeaderMascot;
}) {
  return (
    <div className={styles.intro}>
      <span aria-hidden="true" className={styles.mascot}>
        <img alt="" src={`/mascots/${mascot}.png`} />
      </span>
      <div className={styles.copy}>{children}</div>
    </div>
  );
}
