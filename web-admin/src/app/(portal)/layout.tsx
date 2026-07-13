import { AppShell } from "@/components/app-shell";
import { getCurrentAdminProfile } from "@/lib/auth";
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

  return <AppShell profile={profile}>{children}</AppShell>;
}
