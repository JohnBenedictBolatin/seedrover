import Image from "next/image";
import { LoginForm } from "@/components/login-form";
import { LoginThemeSwitch } from "@/components/login-theme-switch";
import styles from "./page.module.css";

export default async function LoginPage() {
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

            <LoginForm />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
