import { createSupabaseServerClient } from "@/lib/supabase/server";

export type UserRole = {
  id: string;
  roleName: string;
};

export type AdminUser = {
  id: string;
  employeeId: string;
  username: string;
  email: string;
  fullName: string;
  roleName: string;
  isActive: boolean;
  createdAt: string;
};

export type UsersSummary = {
  totalUsers: number;
  activeUsers: number;
  inactiveUsers: number;
  administrators: number;
};

type UserRow = {
  id: string;
  username: string;
  email: string;
  full_name: string;
  is_active: boolean;
  created_at: string;
  roles: { role_name: string } | { role_name: string }[] | null;
};

type RoleRow = {
  id: string;
  role_name: string;
};

function roleName(row: UserRow) {
  const role = Array.isArray(row.roles) ? row.roles[0] : row.roles;
  return role?.role_name ?? "Farm Staff";
}

export async function getUsersDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      users: [],
      roles: [],
      summary: null,
      error: "Supabase is not configured.",
    };
  }

  const [{ data: userRows, error: usersError }, { data: roleRows }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("id, username, email, full_name, is_active, created_at, roles(role_name)")
        .order("created_at", { ascending: false })
        .returns<UserRow[]>(),
      supabase
        .from("roles")
        .select("id, role_name")
        .order("role_name", { ascending: true })
        .returns<RoleRow[]>(),
    ]);

  if (usersError) {
    return {
      users: [],
      roles: [],
      summary: null,
      error: usersError.message,
    };
  }

  const users = (userRows ?? []).map<AdminUser>((row) => ({
    id: row.id,
    employeeId: `EMP-${row.id.slice(0, 8).toUpperCase()}`,
    username: row.username,
    email: row.email,
    fullName: row.full_name,
    roleName: roleName(row),
    isActive: row.is_active,
    createdAt: row.created_at,
  }));

  const summary: UsersSummary = {
    totalUsers: users.length,
    activeUsers: users.filter((user) => user.isActive).length,
    inactiveUsers: users.filter((user) => !user.isActive).length,
    administrators: users.filter((user) => user.roleName === "System Administrator")
      .length,
  };

  return {
    users,
    roles: (roleRows ?? []).map<UserRole>((row) => ({
      id: row.id,
      roleName: row.role_name,
    })),
    summary,
    error: null,
  };
}
