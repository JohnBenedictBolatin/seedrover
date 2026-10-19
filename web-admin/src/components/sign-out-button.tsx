"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";
import { signOutAction } from "@/app/(portal)/actions";
import { useActionFeedback } from "@/components/action-feedback";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { PendingActionLabel } from "@/components/pending-action-label";
import styles from "./app-shell.module.css";

export function SignOutButton({ collapsed }: { collapsed: boolean }) {
  const [pending, setPending] = useState(false);
  const router = useRouter();
  const { notify, clearFeedback } = useActionFeedback();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  return <>
    <button aria-label={pending ? "Signing out" : "Sign out"} aria-busy={pending} className={styles.signOutButton} disabled={pending} title={pending ? "Signing out..." : "Sign out"} type="button" onClick={async () => {
      if (pending) return;
      const confirmed = await confirm({ title: "Sign out?", message: "You are about to sign out of the SeedRover web console.", confirmLabel: "Sign out" });
      if (!confirmed) return;
      setPending(true);
      try {
        const result = await signOutAction();
        if (result?.ok === false) notify({ tone: "error", text: result.message });
        else { clearFeedback(); router.replace("/login"); }
      } catch (error) {
        notify({ tone: "error", text: error instanceof Error ? error.message : "Unable to sign out. Please try again." });
      } finally { setPending(false); }
    }}>
      {collapsed && pending ? <span aria-hidden="true" className="pendingActionSpinner" /> : <LogOut size={16} />}
      {!collapsed ? <PendingActionLabel pending={pending} pendingText="Signing out...">Sign out</PendingActionLabel> : null}
    </button>
    {confirmationDialog}
  </>;
}
