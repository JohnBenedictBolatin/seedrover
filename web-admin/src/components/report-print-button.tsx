"use client";

import { type ReactNode, useState } from "react";
import styles from "./report-print-button.module.css";

export function ReportPrintButton({
  children,
  href,
}: {
  children: ReactNode;
  href: string;
}) {
  const [printUrl, setPrintUrl] = useState("");

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

      if (reportReady || attempts >= 40) {
        frame.contentWindow?.focus();
        frame.contentWindow?.print();
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
        />
      ) : null}
    </>
  );
}
