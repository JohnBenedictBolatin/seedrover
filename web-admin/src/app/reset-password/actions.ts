"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { writeActivityLog } from "@/lib/activity-log";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const recoveryCookieName = "seedrover-password-recovery";

export type PasswordUpdateState = {
  message: string;
};

export async function updateRecoveredPasswordAction(
  _previousState: PasswordUpdateState,
  formData: FormData,
): Promise<PasswordUpdateState> {
  const password = String(formData.get("password") ?? "");
  const confirmation = String(formData.get("confirmation") ?? "");

  if (password.length < 8) {
    return { message: "Password must be at least 8 characters." };
  }

  if (password !== confirmation) {
    return { message: "Passwords do not match." };
  }

  const cookieStore = await cookies();
  if (cookieStore.get(recoveryCookieName)?.value !== "1") {
    return {
      message: "This recovery link is no longer valid. Request a new one.",
    };
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return { message: "Password recovery is not configured." };
  }

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    cookieStore.delete(recoveryCookieName);
    return {
      message: "This recovery link is no longer valid. Request a new one.",
    };
  }

  const { error } = await supabase.auth.updateUser({ password });
  if (error) {
    return { message: error.message };
  }

  await writeActivityLog(supabase, {
    userId: user.id,
    activity: "Password changed",
    description: "The user changed their password using account recovery.",
    module: "Authentication",
  });

  await supabase.auth.signOut();
  cookieStore.delete(recoveryCookieName);

  redirect("/login?passwordUpdated=1");
}
