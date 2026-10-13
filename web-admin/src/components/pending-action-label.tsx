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
  return (
    <span className="pendingActionLabel" aria-live={pending ? "polite" : undefined}>
      {pending ? (
        <>
          <span aria-hidden="true" className="pendingActionSpinner" />
          <span>{pendingText}</span>
        </>
      ) : children}
    </span>
  );
}
