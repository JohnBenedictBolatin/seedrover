import { AppShell } from "@/components/app-shell";
import { getCurrentAdminProfile } from "@/lib/auth";
import { getNotificationsDashboard } from "@/lib/notifications";
import { redirect } from "next/navigation";

export default async function PortalLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
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
