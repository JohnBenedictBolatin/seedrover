import { createClient } from "npm:@supabase/supabase-js@2";
import { connectAsync } from "npm:mqtt@5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, 405);
  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const url = required("SUPABASE_URL");
    const anon = required("SUPABASE_ANON_KEY");
    const serviceRole = required("SUPABASE_SERVICE_ROLE_KEY");
    const userClient = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return reply({ error: "Authentication required." }, 401);

    const body = await request.json().catch(() => null);
    const roverId = typeof body?.rover_id === "string" ? body.rover_id : "seedrover-01";
    if (body?.command !== "PING") return reply({ error: "Phase 1 only permits PING." }, 400);
    const { data: lease, error: leaseError } = await userClient.rpc("acquire_rover_control_lease", {
      target_rover_id: roverId, lease_seconds: 30,
    });
    if (leaseError || !lease || lease.owner_id !== user.id) {
      return reply({ error: leaseError?.message ?? "Control lease required." }, 409);
    }

    const admin = createClient(url, serviceRole);
    const expiresAt = new Date(Date.now() + 15_000).toISOString();
    const { data: command, error } = await admin.from("robot_commands").insert({
      rover_id: roverId, command: "PING", payload: {}, issued_by: user.id,
      status: "Pending", expires_at: expiresAt,
    }).select("id, correlation_id, created_at, expires_at").single();
    if (error) throw error;

    const mqtt = await connectAsync(required("MQTT_URL"), {
      username: required("MQTT_USERNAME"), password: required("MQTT_PASSWORD"),
      protocolVersion: 5, connectTimeout: 8_000, reconnectPeriod: 0,
    });
    const message = JSON.stringify({
      command_id: command.correlation_id, command: "PING",
      timestamp: Date.now(), expires_at: command.expires_at, payload: {},
    });
    await mqtt.publishAsync(`seedrover/v1/${roverId}/commands`, message, { qos: 1, retain: false });
    await mqtt.endAsync();
    await admin.from("robot_commands").update({ status: "Sent" }).eq("id", command.id);
    return reply({ command_id: command.correlation_id, status: "Sent", created_at: command.created_at });
  } catch (error) {
    console.error("rover-command failed", error instanceof Error ? error.message : error);
    return reply({ error: "Unable to send rover command." }, 500);
  }
});

function required(name: string) { const value = Deno.env.get(name); if (!value) throw new Error(`Missing ${name}`); return value; }
function reply(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

