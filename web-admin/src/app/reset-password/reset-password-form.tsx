"use client";

import { useActionState } from "react";
import Link from "next/link";
import { Lock } from "lucide-react";
import {
  updateRecoveredPasswordAction,
  type PasswordUpdateState,
} from "./actions";
import styles from "@/components/login-form.module.css";

const initialState: PasswordUpdateState = { message: "", success: false };

export function ResetPasswordForm() {
  const [state, formAction, pending] = useActionState(
    updateRecoveredPasswordAction,
    initialState,
  );

  if (state.success) {
    return (
      <div className={styles.form}>
        <p className={styles.resetMessage} role="status">{state.message}</p>
        <Link className={styles.submitButton} href="/login">
          Return to sign in
        </Link>
      </div>
    );
  }

  return (
    <form action={formAction} className={styles.form}>
      <label>
        <span>New password</span>
        <div className={styles.inputWrap}>
          <Lock aria-hidden="true" size={18} />
          <input autoComplete="new-password" minLength={8} name="password" required type="password" />
        </div>
      </label>
      <label>
        <span>Confirm new password</span>
        <div className={styles.inputWrap}>
          <Lock aria-hidden="true" size={18} />
          <input autoComplete="new-password" minLength={8} name="confirmation" required type="password" />
        </div>
      </label>
      {state.message ? (
        <p className={styles.message} role="alert">{state.message}</p>
      ) : null}
      <button className={styles.submitButton} disabled={pending} type="submit">
        {pending ? "Updating password…" : "Update password"}
      </button>
    </form>
  );
}
