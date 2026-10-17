import { Suspense } from "react";
import { AppShell } from "@/components/app-shell";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getNotificationsDashboard } from "@/lib/notifications";
import { redirect } from "next/navigation";
import Loading from "../loading";

export default function PortalLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return <Suspense fallback={<Loading />}><PortalShell>{children}</PortalShell></Suspense>;
}

async function PortalShell({ children }: { children: React.ReactNode }) {
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    redirect("/login");
  }

  const notificationData = await getNotificationsDashboard(profile);

  return (
    <AppShell
      notifications={notificationData.notifications}
      notificationsError={notificationData.error}
      notificationsSummary={notificationData.summary}
      profile={profile}
    >
      {children}
    </AppShell>
  );
}
