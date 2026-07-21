import Image from "next/image";
import { LoginForm } from "@/components/login-form";
import { LoginThemeSwitch } from "@/components/login-theme-switch";
import { getCurrentAdminProfile } from "@/lib/auth";
import { redirect } from "next/navigation";
import styles from "./page.module.css";

export default async function LoginPage() {
  const profile = await getCurrentAdminProfile();

  if (profile) {
    redirect("/dashboard");
  }

  return (
    <main className={styles.page}>
      <div className={styles.background} aria-hidden="true" />
      <div className={styles.themeSwitchDock}>
        <LoginThemeSwitch />
      </div>

      <section className={styles.shell} aria-labelledby="login-title">
        <div className={styles.identity}>
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
          <h1 id="login-title">
            Your planting tools are set, and the fields are waiting.
          </h1>
        </div>

        <div className={styles.panel}>
          <div className={styles.panelHeader}>
            <div>
              <p className={styles.eyebrow}>SeedRover web console</p>
              <h2>Sign in to supervise farm operations</h2>
            </div>
          </div>

          <LoginForm />
        </div>
      </section>
    </main>
  );
}
