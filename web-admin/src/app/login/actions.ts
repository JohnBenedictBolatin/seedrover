"use server";

import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { isAdminRole } from "@/lib/auth";

export type LoginState = {
  message: string;
};

async function resolveEmailForUsername(username: string) {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      supabase: null,
      email: null,
      message: "Supabase is not configured for the web admin yet.",
    };
  }

  const { data: email, error } = await supabase.rpc("get_email_by_username", {
    requested_username: username,
  });

  if (error || typeof email !== "string" || !email) {
    return {
      supabase,
      email: null,
      message: "Username not found or the account is inactive.",
    };
  }

  return {
    supabase,
    email,
    message: "",
  };
}

export async function signInAction(
  _state: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const username = String(formData.get("username") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  let signedIn = false;

  if (!username) {
    return { message: "Enter your username." };
  }

  if (!password) {
    return { message: "Enter your password." };
  }

  const { supabase, email, message } = await resolveEmailForUsername(username);

  if (!supabase || !email) {
    return { message };
  }

  try {
    const { data: authData, error: signInError } =
      await supabase.auth.signInWithPassword({
        email,
        password,
      });

    if (signInError || !authData.user) {
      return { message: "Incorrect password. Please try again." };
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("username, roles(role_name)")
      .eq("id", authData.user.id)
      .single<{
        username: string;
        roles: { role_name: string } | { role_name: string }[] | null;
      }>();

    const roleRow = Array.isArray(profile?.roles)
      ? profile?.roles[0]
      : profile?.roles;
    const roleName = roleRow?.role_name ?? "";

    if (profileError || !isAdminRole(roleName)) {
      await supabase.auth.signOut();
      return { message: "This web console is only for admins and farm managers." };
    }

    await supabase.from("activity_logs").insert({
      user_id: authData.user.id,
      activity: "Web Login",
      description: `${profile.username} signed in to the web admin.`,
      module: "Authentication",
    });

    signedIn = true;
  } catch {
    return { message: "Unable to sign in right now. Please try again." };
  }

  if (signedIn) {
    redirect("/dashboard");
  }

  return { message: "Unable to sign in right now. Please try again." };
}

export async function forgotPasswordAction(username: string) {
  const normalizedUsername = username.trim();

  if (!normalizedUsername) {
    return "Enter your username first.";
  }

  const { supabase, email, message } = await resolveEmailForUsername(
    normalizedUsername,
  );

  if (!supabase || !email) {
    return message;
  }

  try {
    await supabase.auth.resetPasswordForEmail(email);
    return "Password reset email sent.";
  } catch {
    return "Unable to send reset email right now. Please try again.";
  }
}
