"use client";

import { startTransition, useActionState, useState } from "react";
import { Eye, EyeOff, Lock, LogIn, UserRound } from "lucide-react";
import {
  forgotPasswordAction,
  signInAction,
  type LoginState,
} from "@/app/login/actions";
import styles from "./login-form.module.css";

const initialState: LoginState = {
  message: "",
};

export function LoginForm() {
  const [state, formAction, pending] = useActionState(signInAction, initialState);
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [username, setUsername] = useState("");
  const [resetMessage, setResetMessage] = useState("");
  const [resetPending, setResetPending] = useState(false);

  function handleForgotPassword() {
    setResetPending(true);
    startTransition(async () => {
      const message = await forgotPasswordAction(username);
      setResetMessage(message);
      setResetPending(false);
    });
  }

  return (
    <form className={styles.form} action={formAction}>
      <label>
        <span>Username</span>
        <div className={styles.inputWrap}>
          <UserRound aria-hidden="true" size={19} />
          <input
            autoComplete="username"
            name="username"
            placeholder="farm.manager"
            required
            type="text"
            value={username}
            onChange={(event) => setUsername(event.target.value)}
          />
        </div>
      </label>
      <label>
        <span>Password</span>
        <div className={styles.inputWrap}>
          <Lock aria-hidden="true" size={19} />
          <input
            autoComplete="current-password"
            name="password"
            placeholder="Password"
            required
            type={showPassword ? "text" : "password"}
          />
          <button
            aria-label={showPassword ? "Hide password" : "Show password"}
            className={styles.iconButton}
            type="button"
            onClick={() => setShowPassword((current) => !current)}
          >
            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        </div>
      </label>
      <div className={styles.options}>
        <label className={styles.checkLabel}>
          <input
            checked={rememberMe}
            name="rememberMe"
            type="checkbox"
            value="true"
            onChange={(event) => setRememberMe(event.target.checked)}
          />
          <span>Remember me</span>
        </label>
        <button
          className={styles.linkButton}
          type="button"
          disabled={resetPending}
          onClick={handleForgotPassword}
        >
          {resetPending ? "Sending..." : "Forgot password?"}
        </button>
      </div>
      {resetMessage ? (
        <p className={styles.resetMessage} role="status">
          {resetMessage}
        </p>
      ) : null}
      {state.message ? (
        <p className={styles.message} role="status">
          {state.message}
        </p>
      ) : null}
      <button className={styles.submitButton} type="submit" disabled={pending}>
        <LogIn aria-hidden="true" size={18} />
        <span>{pending ? "Signing in..." : "Log in"}</span>
      </button>
    </form>
  );
}
