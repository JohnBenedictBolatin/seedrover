import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");
  if (!url || !anonKey || !serviceKey || !authorization) return json({ error: "Service is not configured." }, 500);

  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const adminClient = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "Unauthorized." }, 401);

  const { data: caller } = await adminClient
    .from("profiles")
    .select("id, is_active, roles(role_name)")
    .eq("id", user.id)
    .single();
  const role = Array.isArray(caller?.roles) ? caller?.roles[0]?.role_name : caller?.roles?.role_name;
  if (!caller?.is_active || role !== "System Administrator") return json({ error: "Administrator access required." }, 403);

  const body = await request.json().catch(() => null);
  const fullName = String(body?.full_name ?? "").trim();
  const username = String(body?.username ?? "").trim().toLowerCase();
  const email = String(body?.email ?? "").trim().toLowerCase();
  const password = String(body?.temporary_password ?? "");
  const contactNumber = String(body?.contact_number ?? "").trim();
  const roleName = String(body?.role_name ?? "").trim();
  if (!fullName || !email || password.length < 8 || !/^[a-z0-9_]{3,32}$/.test(username)) return json({ error: "Invalid user details." }, 400);

  const { data: selectedRole } = await adminClient.from("roles").select("id, role_name").eq("role_name", roleName).single();
  if (!selectedRole) return json({ error: "Role not found." }, 400);

  const { data: created, error: authError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { username, full_name: fullName, contact_number: contactNumber },
  });
  if (authError || !created.user) return json({ error: authError?.message ?? "Unable to create user." }, 400);

  const { error: profileError } = await adminClient.from("profiles").upsert({
    id: created.user.id,
    username,
    email,
    full_name: fullName,
    contact_number: contactNumber,
    role_id: selectedRole.id,
    is_active: true,
  });
  if (profileError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    return json({ error: profileError.message }, 400);
  }

  await adminClient.from("activity_logs").insert({ user_id: user.id, activity: "User Created", description: `${fullName} was created as ${roleName}.`, module: "Users" });
  return json({ success: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
