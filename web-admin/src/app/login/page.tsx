import Image from "next/image";
import { LoginForm } from "@/components/login-form";
import { LoginThemeSwitch } from "@/components/login-theme-switch";
import styles from "./page.module.css";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const recoveryError = typeof params.recovery === "string" ? params.recovery : null;
  const authError = typeof params.error === "string" ? params.error : null;
  const authErrorCode = typeof params.error_code === "string" ? params.error_code : null;
  const hasRecoveryQueryError = recoveryError === "invalid" || Boolean(authError);
  const initialResetMessage = recoveryError === "invalid"
    ? "This password reset link could not be verified. Request a new link and open it again."
    : authError
      ? authErrorCode === "otp_expired"
        ? "This password reset link has expired or was already used. Request a new link."
        : "We couldn't verify this password reset link. Request a new link and try again."
      : "";

  return (
    <main className={styles.page}>
      <div className={styles.background} aria-hidden="true" />
      <div className={styles.themeSwitchDock}>
        <LoginThemeSwitch />
      </div>

      <section className={styles.shell} aria-labelledby="login-title">
        <div className={styles.identity}>
        </div>

        <div className={styles.loginSide}>
          <div className={styles.loginContent}>
            <div className={styles.loginBrand}>
            <Image
            alt="SeedRover"
            className={`${styles.logo} ${styles.logoDark}`}
            height={186}
            priority
            src="/brand/seedrover-logo-dark.png"
            width={278}
          />
            <Image
            alt="SeedRover"
            className={`${styles.logo} ${styles.logoLight}`}
            height={186}
            priority
            src="/brand/seedrover-logo-light.png"
            width={278}
          />
            <p>Welcome back!</p>
            <h1 id="login-title">Manage your farm in one convenient system.</h1>
            </div>
            <div className={styles.panel}>
              <div className={styles.panelHeader}>
                <div>
                  <h2>Sign in</h2>
              </div>
            </div>

            <LoginForm hasRecoveryQueryError={hasRecoveryQueryError} initialResetMessage={initialResetMessage} />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
