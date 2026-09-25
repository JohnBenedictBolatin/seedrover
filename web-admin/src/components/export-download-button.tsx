"use client";

import { useState, type ReactNode } from "react";
import { useActionFeedback } from "@/components/action-feedback";

export function ExportDownloadButton({ href, children, className }: { href: string; children: ReactNode; className?: string }) {
  const [pending, setPending] = useState(false);
  const { notify } = useActionFeedback();
  return <a className={className} href={href} aria-disabled={pending} onClick={async (event) => {
    event.preventDefault();
    if (pending) return;
    setPending(true);
    try {
      const response = await fetch(href);
      if (!response.ok) throw new Error(response.status === 401 ? "Your session expired. Sign in and try again." : `Export failed (${response.status}). Please try again.`);
      if ((response.headers.get("content-type") ?? "").includes("text/html")) throw new Error("Your session may have expired. Sign in and try again.");
      const blob = await response.blob();
      const disposition = response.headers.get("content-disposition") ?? "";
      const filename = disposition.match(/filename="?([^";]+)"?/i)?.[1] ?? "seedrover-export";
      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = objectUrl;
      link.download = filename;
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
      notify({ tone: "success", text: "Export ready." });
    } catch (error) {
      notify({ tone: "error", text: error instanceof Error ? error.message : "Unable to prepare the export." });
    } finally { setPending(false); }
  }}>{children}</a>;
}
