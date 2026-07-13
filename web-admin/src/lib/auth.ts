import { createSupabaseServerClient } from "@/lib/supabase/server";

export const adminRoles = [
  "System Administrator",
  "Farm Planting Manager",
  "Farm Inventory Manager",
] as const;

export type AdminRole = (typeof adminRoles)[number];

export type AdminProfile = {
  id: string;
  username: string;
  email: string;
  fullName: string;
  roleName: AdminRole;
  isActive: boolean;
};

type ProfileRow = {
  id: string;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  roles: { role_name: string } | { role_name: string }[] | null;
};

function roleFromRow(row: ProfileRow) {
  const roles = Array.isArray(row.roles) ? row.roles[0] : row.roles;
  return roles?.role_name ?? "";
}

export function isAdminRole(roleName: string): roleName is AdminRole {
  return adminRoles.some((role) => role === roleName);
}

export async function getCurrentAdminProfile(): Promise<AdminProfile | null> {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return null;
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return null;
  }

  const { data, error } = await supabase
    .from("profiles")
    .select("id, username, email, full_name, is_active, roles(role_name)")
    .eq("id", user.id)
    .single<ProfileRow>();

  if (error || !data || !data.is_active) {
    return null;
  }

  const roleName = roleFromRow(data);

  if (!isAdminRole(roleName)) {
    return null;
  }

  return {
    id: data.id,
    username: data.username,
    email: data.email,
    fullName: data.full_name,
    roleName,
    isActive: data.is_active,
  };
}
