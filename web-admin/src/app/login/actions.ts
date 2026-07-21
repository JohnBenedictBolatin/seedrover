"use server";

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { isAdminRole } from "@/lib/auth";
import { checkRateLimit, formatRetryAfter } from "@/lib/rate-limit";

export type LoginState = {
  message: string;
};

const genericLoginError = "Invalid username or password.";
const genericResetMessage =
  "If that username exists, a password reset email will be sent.";

async function resolveEmailForUsername(
  username: string,
  rememberSession?: boolean,
) {
  const supabase = await createSupabaseServerClient({ rememberSession });

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
      message: genericLoginError,
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
  const rememberSession = formData.get("rememberMe") === "true";
  let signedIn = false;

  if (!username) {
    return { message: "Enter your username." };
  }

  if (!password) {
    return { message: "Enter your password." };
  }

  const loginLimit = await checkRateLimit({
    identifierParts: [username.toLowerCase()],
    limit: 5,
    namespace: "login",
    windowMs: 15 * 60 * 1000,
  });

  if (loginLimit.limited) {
    return {
      message: `Too many login attempts. Please wait ${formatRetryAfter(
        loginLimit.retryAfterSeconds,
      )} before trying again.`,
    };
  }

  const { supabase, email, message } = await resolveEmailForUsername(
    username,
    rememberSession,
  );

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
      return { message: genericLoginError };
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
      return { message: genericLoginError };
    }

    await supabase.from("activity_logs").insert({
      user_id: authData.user.id,
      activity: "Web Login",
      description: `${profile.username} signed in to the web admin.`,
      module: "Authentication",
    });

    const cookieStore = await cookies();
    cookieStore.set("seedrover-remember", rememberSession ? "1" : "0", {
      httpOnly: true,
      maxAge: rememberSession ? 60 * 60 * 24 * 365 : undefined,
      path: "/",
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
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

  const resetLimit = await checkRateLimit({
    identifierParts: [normalizedUsername.toLowerCase()],
    limit: 3,
    namespace: "password-reset",
    windowMs: 15 * 60 * 1000,
  });

  if (resetLimit.limited) {
    return `Too many password reset requests. Please wait ${formatRetryAfter(
      resetLimit.retryAfterSeconds,
    )} before trying again.`;
  }

  const { supabase, email } = await resolveEmailForUsername(normalizedUsername);

  if (!supabase || !email) {
    return genericResetMessage;
  }

  try {
    await supabase.auth.resetPasswordForEmail(email);
    return genericResetMessage;
  } catch {
    return "Unable to send reset email right now. Please try again.";
  }
}
