"use server";

import { cookies } from "next/headers";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const recoveryCookieName = "seedrover-password-recovery";

export type PasswordUpdateState = {
  message: string;
  success: boolean;
};

export async function updateRecoveredPasswordAction(
  _previousState: PasswordUpdateState,
  formData: FormData,
): Promise<PasswordUpdateState> {
  const password = String(formData.get("password") ?? "");
  const confirmation = String(formData.get("confirmation") ?? "");

  if (password.length < 8) {
    return { message: "Password must be at least 8 characters.", success: false };
  }

  if (password !== confirmation) {
    return { message: "Passwords do not match.", success: false };
  }

  const cookieStore = await cookies();
  if (cookieStore.get(recoveryCookieName)?.value !== "1") {
    return {
      message: "This recovery link is no longer valid. Request a new one.",
      success: false,
    };
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return { message: "Password recovery is not configured.", success: false };
  }

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    cookieStore.delete(recoveryCookieName);
    return {
      message: "This recovery link is no longer valid. Request a new one.",
      success: false,
    };
  }

  const { error } = await supabase.auth.updateUser({ password });
  if (error) {
    return { message: error.message, success: false };
  }

  await supabase.auth.signOut();
  cookieStore.delete(recoveryCookieName);

  return { message: "Password updated. You can now sign in.", success: true };
}
