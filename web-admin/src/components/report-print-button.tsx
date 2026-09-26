"use client";

import { type ReactNode, useState } from "react";
import styles from "./report-print-button.module.css";
import { useActionFeedback } from "@/components/action-feedback";

export function ReportPrintButton({
  children,
  href,
}: {
  children: ReactNode;
  href: string;
}) {
  const [printUrl, setPrintUrl] = useState("");
  const { notify } = useActionFeedback();

  function handlePrint() {
    const separator = href.includes("?") ? "&" : "?";
    setPrintUrl(`${href}${separator}print=${Date.now()}`);
  }

  function printWhenReady(frame: HTMLIFrameElement) {
    let attempts = 0;

    const waitForReport = () => {
      attempts += 1;
      const document = frame.contentDocument;
      const reportReady = document?.querySelector('[data-print-ready="true"]');

      if (reportReady) {
        frame.contentWindow?.focus();
        try {
          frame.contentWindow?.print();
        } catch {
          notify({ tone: "error", text: "The report could not be printed. Please try again." });
        }
        return;
      }
      if (attempts >= 40) {
        notify({ tone: "error", text: "The report did not finish loading and was not printed." });
        return;
      }

      window.setTimeout(waitForReport, 150);
    };

    window.setTimeout(waitForReport, 150);
  }

  return (
    <>
      <button className={styles.printButton} type="button" onClick={handlePrint}>
        {children}
      </button>
      {printUrl ? (
        <iframe
          aria-hidden="true"
          className={styles.printFrame}
          src={printUrl}
          title="Print report"
          onLoad={(event) => printWhenReady(event.currentTarget)}
          onError={() => notify({ tone: "error", text: "The report could not be loaded and was not printed." })}
        />
      ) : null}
    </>
  );
}
