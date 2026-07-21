"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseAdminClient } from "@/lib/supabase/admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CreateUserState = {
  message: string;
  success: boolean;
};

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

export async function createUserAction(
  _state: CreateUserState,
  formData: FormData,
): Promise<CreateUserState> {
  let adminProfile;

  try {
    adminProfile = await requireAdminRole(["System Administrator"]);
  } catch (error) {
    return {
      message:
        error instanceof Error
          ? error.message
          : "Only system administrators can create users.",
      success: false,
    };
  }

  const fullName = text(formData, "full_name");
  const username = normalizeUsername(text(formData, "username"));
  const email = text(formData, "email").toLowerCase();
  const password = String(formData.get("temporary_password") ?? "");
  const contactNumber = text(formData, "contact_number");
  const roleId = text(formData, "role_id");
  const isActive = text(formData, "is_active", "true") === "true";
  const accessNote = text(formData, "access_note");

  if (!fullName || !username || !email || !password || !roleId) {
    return { message: "Complete all required account fields.", success: false };
  }

  if (!/^[a-z0-9_]{3,32}$/.test(username)) {
    return {
      message:
        "Username must be 3-32 characters and use lowercase letters, numbers, or underscores only.",
      success: false,
    };
  }

  if (password.length < 8) {
    return {
      message: "Temporary password must be at least 8 characters.",
      success: false,
    };
  }

  const supabase = await createSupabaseServerClient();
  const adminSupabase = createSupabaseAdminClient();

  if (!supabase || !adminSupabase) {
    return {
      message:
        "Secure user creation is not configured. Add SUPABASE_SERVICE_ROLE_KEY to the server environment.",
      success: false,
    };
  }

  const [
    { data: role },
    { data: existingUsername },
    { data: existingEmail },
  ] = await Promise.all([
    supabase.from("roles").select("id, role_name").eq("id", roleId).single(),
    supabase
      .from("profiles")
      .select("id")
      .eq("username", username)
      .maybeSingle(),
    supabase
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle(),
  ]);

  if (!role) {
    return { message: "Selected role was not found.", success: false };
  }

  if (existingUsername || existingEmail) {
    return {
      message: "A user with that username or email already exists.",
      success: false,
    };
  }

  const { data: createdAuthUser, error: createError } =
    await adminSupabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        contact_number: contactNumber,
        full_name: fullName,
        username,
      },
    });

  if (createError || !createdAuthUser.user) {
    return {
      message: createError?.message ?? "Unable to create the auth user.",
      success: false,
    };
  }

  const userId = createdAuthUser.user.id;
  const { error: profileError } = await adminSupabase.from("profiles").insert({
    id: userId,
    username,
    email,
    full_name: fullName,
    role_id: role.id,
    is_active: isActive,
  });

  if (profileError) {
    await adminSupabase.auth.admin.deleteUser(userId);

    return {
      message: profileError.message,
      success: false,
    };
  }

  await supabase.from("activity_logs").insert({
    user_id: adminProfile.id,
    activity: "User Created",
    description: `${fullName} was created as ${role.role_name}.${accessNote ? ` Note: ${accessNote}` : ""}`,
    module: "Users",
  });

  revalidatePath("/users");

  return {
    message: `${fullName} account created. Share the temporary password securely and ask them to change it after signing in.`,
    success: true,
  };
}

export async function updateUserAction(formData: FormData) {
  const profile = await requireAdminRole(["System Administrator"]);

  const userId = String(formData.get("user_id") ?? "");
  const fullName = String(formData.get("full_name") ?? "").trim();
  const roleId = String(formData.get("role_id") ?? "");
  const isActive = String(formData.get("is_active") ?? "false") === "true";

  if (!userId || !fullName || !roleId) {
    throw new Error("Complete all required user profile fields.");
  }

  if (userId === profile.id && !isActive) {
    throw new Error("You cannot deactivate your own administrator account.");
  }

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const [{ data: selectedRole }, { data: targetUser }, { count: activeAdminCount }] =
    await Promise.all([
      supabase.from("roles").select("id, role_name").eq("id", roleId).single(),
      supabase
        .from("profiles")
        .select("id, full_name, roles(role_name)")
        .eq("id", userId)
        .single<{
          id: string;
          full_name: string;
          roles: { role_name: string } | { role_name: string }[] | null;
        }>(),
      supabase
        .from("profiles")
        .select("id, roles!inner(role_name)", { count: "exact", head: true })
        .eq("is_active", true)
        .eq("roles.role_name", "System Administrator"),
    ]);

  if (!selectedRole || !targetUser) {
    throw new Error("Selected user or role was not found.");
  }

  const targetRole = Array.isArray(targetUser.roles)
    ? targetUser.roles[0]
    : targetUser.roles;
  const targetIsSystemAdmin = targetRole?.role_name === "System Administrator";
  const willRemainSystemAdmin =
    selectedRole.role_name === "System Administrator" && isActive;

  if (targetIsSystemAdmin && !willRemainSystemAdmin && (activeAdminCount ?? 0) <= 1) {
    throw new Error(
      "At least one active System Administrator must remain in the system.",
    );
  }

  const { error: updateError } = await supabase
    .from("profiles")
    .update({
      full_name: fullName,
      role_id: roleId,
      is_active: isActive,
    })
    .eq("id", userId);

  if (updateError) {
    throw new Error(updateError.message);
  }

  await supabase.from("activity_logs").insert({
    user_id: profile.id,
    activity: "User Updated",
    description: `${fullName} profile updated from the web admin. Role: ${selectedRole.role_name}. Status: ${isActive ? "Active" : "Inactive"}.`,
    module: "Users",
  });

  revalidatePath("/users");
}
