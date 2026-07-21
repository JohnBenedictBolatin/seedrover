"use client";

import { useRef } from "react";
import { useConfirmationDialog, type ConfirmationTone } from "./confirmation-dialog";

type ConfirmSubmitButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  confirmMessage: string;
  confirmTitle?: string;
  confirmLabel?: string;
  confirmTone?: ConfirmationTone;
};

export function ConfirmSubmitButton({
  children,
  confirmLabel = "Confirm",
  confirmMessage,
  confirmTitle = "Are you sure?",
  confirmTone = "danger",
  onClick,
  ...props
}: ConfirmSubmitButtonProps) {
  const buttonRef = useRef<HTMLButtonElement | null>(null);
  const { confirm, confirmationDialog } = useConfirmationDialog();

  return (
    <>
      <button
        {...props}
        ref={buttonRef}
        type="button"
        onClick={async (event) => {
          const confirmed = await confirm({
            title: confirmTitle,
            message: confirmMessage,
            confirmLabel,
            tone: confirmTone,
          });

          if (!confirmed) {
            return;
          }

          onClick?.(event);

          if (event.defaultPrevented) {
            return;
          }

          const form = buttonRef.current?.form;

          if (!form) {
            return;
          }

          try {
            form.requestSubmit();
          } catch {
            form.submit();
          }
        }}
      >
        {children}
      </button>
      {confirmationDialog}
    </>
  );
}
