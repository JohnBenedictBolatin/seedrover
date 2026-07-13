"use client";

import styles from "./print-button.module.css";

export function PrintButton() {
  return (
    <button className={styles.button} type="button" onClick={() => window.print()}>
      Print receipt
    </button>
  );
}
