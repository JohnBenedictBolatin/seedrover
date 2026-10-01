import Image from "next/image";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { LoginThemeSwitch } from "@/components/login-theme-switch";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { ResetPasswordForm } from "./reset-password-form";
import pageStyles from "../login/page.module.css";
import formStyles from "@/components/login-form.module.css";

const recoveryCookieName = "seedrover-password-recovery";

export default async function ResetPasswordPage() {
  const cookieStore = await cookies();
  const recoveryStarted = cookieStore.get(recoveryCookieName)?.value === "1";
  const supabase = await createSupabaseServerClient();
  const user = supabase ? (await supabase.auth.getUser()).data.user : null;

  if (!recoveryStarted || !user) {
    redirect("/login?recovery=invalid");
  }

  return (
    <main className={pageStyles.page}>
      <div aria-hidden="true" className={pageStyles.background} />
      <div className={pageStyles.themeSwitchDock}>
        <LoginThemeSwitch />
      </div>
      <section aria-labelledby="reset-password-title" className={pageStyles.shell}>
        <div className={pageStyles.identity} />
        <div className={pageStyles.loginSide}>
          <div className={pageStyles.loginContent}>
            <div className={pageStyles.loginBrand}>
              <Image
                alt="SeedRover"
                className={`${pageStyles.logo} ${pageStyles.logoDark}`}
                height={186}
                priority
                src="/brand/seedrover-logo-dark.png"
                width={278}
              />
              <Image
                alt="SeedRover"
                className={`${pageStyles.logo} ${pageStyles.logoLight}`}
                height={186}
                priority
                src="/brand/seedrover-logo-light.png"
                width={278}
              />
              <p>Account recovery</p>
              <h1>Choose a new password for your SeedRover account.</h1>
            </div>
            <div className={pageStyles.panel}>
              <div className={pageStyles.panelHeader}>
                <div>
                  <h2 id="reset-password-title">Set a new password</h2>
                </div>
              </div>
              <ResetPasswordForm />
              <Link className={formStyles.linkButton} href="/login">
                Back to sign in
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
