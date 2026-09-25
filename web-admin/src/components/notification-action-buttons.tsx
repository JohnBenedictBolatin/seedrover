"use client";

import { useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { deleteNotificationAction, markNotificationReadAction } from "@/app/(portal)/notifications/actions";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";

export function NotificationReadButton({ id, isRead, children }: { id: string; isRead: boolean; children: ReactNode }) {
  const [pending, setPending] = useState(false);
  const { notify } = useActionFeedback();
  const router = useRouter();
  return <button aria-label={isRead ? "Mark unread" : "Mark read"} disabled={pending} type="button" onClick={async () => {
    if (pending) return;
    setPending(true);
    try {
      const data = new FormData();
      data.set("notification_id", id);
      data.set("is_read", String(!isRead));
      const result = await markNotificationReadAction(data);
      notify({ tone: result.ok ? result.tone ?? "success" : "error", text: result.message });
      if (result.ok) router.refresh();
    } catch (error) {
      notify({ tone: "error", text: error instanceof Error ? error.message : "Unable to update the notification." });
    } finally { setPending(false); }
  }}>{children}</button>;
}

export function NotificationDeleteButton({ id, className, children }: { id: string; className?: string; children: ReactNode }) {
  const [pending, setPending] = useState(false);
  const { notify } = useActionFeedback();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();
  return <>
    <button aria-label="Delete notification" className={className} disabled={pending} type="button" onClick={async () => {
      if (pending) return;
      const confirmed = await confirm({ title: "Delete notification?", message: "This notification will be permanently deleted.", confirmLabel: "Delete notification", tone: "danger" });
      if (!confirmed) return;
      setPending(true);
      try {
        const data = new FormData();
        data.set("notification_id", id);
        const result = await deleteNotificationAction(data);
        notify({ tone: result.ok ? result.tone ?? "success" : "error", text: result.message });
        if (result.ok) router.refresh();
      } catch (error) {
        notify({ tone: "error", text: error instanceof Error ? error.message : "Unable to delete the notification." });
      } finally { setPending(false); }
    }}>{children}</button>
    {confirmationDialog}
  </>;
}
