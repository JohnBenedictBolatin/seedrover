"use client";

import styles from "./print-button.module.css";
import { useActionFeedback } from "@/components/action-feedback";

export function PrintButton() {
  const { notify } = useActionFeedback();
  return (
    <button className={styles.button} type="button" onClick={() => {
      try { window.print(); }
      catch { notify({ tone: "error", text: "Unable to open the print dialog." }); }
    }}>
      Print receipt
    </button>
  );
}
