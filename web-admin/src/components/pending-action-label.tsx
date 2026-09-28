import type { ReactNode } from "react";

export function PendingActionLabel({
  children,
  pending,
  pendingText,
}: {
  children: ReactNode;
  pending: boolean;
  pendingText: string;
}) {
  if (!pending) return children;

  return (
    <span className="pendingActionLabel" aria-live="polite">
      <span aria-hidden="true" className="pendingActionSpinner" />
      <span>{pendingText}</span>
    </span>
  );
}
