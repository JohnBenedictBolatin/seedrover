import Image from "next/image";
import { LoginForm } from "@/components/login-form";
import { getCurrentAdminProfile } from "@/lib/auth";
import { redirect } from "next/navigation";
import { Leaf } from "lucide-react";
import styles from "./page.module.css";

export default async function LoginPage() {
  const profile = await getCurrentAdminProfile();

  if (profile) {
    redirect("/dashboard");
  }

  return (
    <main className={styles.page}>
      <div className={styles.background} aria-hidden="true">
        <span className={styles.grid} />
        <div className={styles.fieldRows}>
          {Array.from({ length: 9 }).map((_, index) => (
            <span key={index} />
          ))}
        </div>
      </div>

      <section className={styles.shell} aria-labelledby="login-title">
        <div className={styles.identity}>
          <Image
            alt="SeedRover"
            className={styles.logo}
            height={186}
            priority
            src="/brand/seedrover-logo.png"
            width={278}
          />
          <p>Welcome back!</p>
          <h1 id="login-title">
            Your planting tools are set, and the fields are waiting.
          </h1>
        </div>

        <div className={styles.panel}>
          <div className={styles.panelHeader}>
            <span className={styles.iconBadge}>
              <Leaf size={18} />
            </span>
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
