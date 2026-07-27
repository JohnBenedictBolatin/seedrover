import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const supplied = request.headers.get("x-device-secret") ?? "";
  const expected = Deno.env.get("ROVER_DEVICE_SECRET") ?? "";
  if (!expected || supplied.length !== expected.length || !constantTimeEqual(supplied, expected)) {
    return json({ error: "Invalid device credentials." }, 401);
  }
  const body = await request.json().catch(() => null);
  const roverId = typeof body?.rover_id === "string" ? body.rover_id : "seedrover-01";
  const admin = createClient(required("SUPABASE_URL"), required("SUPABASE_SERVICE_ROLE_KEY"));
  if (body?.type === "heartbeat") {
    const { error } = await admin.from("robot_status").update({
      rover_status: "Online", wifi_connected: true, last_updated: new Date().toISOString(),
    }).eq("is_active", true);
    if (error) return json({ error: "Heartbeat update failed." }, 500);
    return json({ status: "success", rover_id: roverId });
  }
  if (body?.type === "ack") {
    const statuses: Record<string, string> = {
      success: "Success", failed: "Failed", invalid_command: "Invalid Command",
      busy: "Busy", disconnected: "Disconnected",
    };
    const status = statuses[String(body.status)] ?? "Failed";
    const { data, error } = await admin.from("robot_commands").update({
      status, acknowledged_at: new Date().toISOString(), executed_at: status === "Success" ? new Date().toISOString() : null,
      failure_details: status === "Success" ? null : String(body.message ?? "Device rejected command."),
    }).eq("rover_id", roverId).eq("correlation_id", body.command_id).gt("expires_at", new Date().toISOString())
      .select("created_at").maybeSingle();
    if (error || !data) return json({ error: "Unknown or expired command." }, 409);
    return json({ status: "success", round_trip_ms: Date.now() - new Date(data.created_at).getTime() });
  }
  return json({ error: "Invalid event type." }, 400);
});

function constantTimeEqual(a: string, b: string) { let value = 0; for (let i = 0; i < a.length; i++) value |= a.charCodeAt(i) ^ b.charCodeAt(i); return value === 0; }
function required(name: string) { const value = Deno.env.get(name); if (!value) throw new Error(`Missing ${name}`); return value; }
function json(body: Record<string, unknown>, status = 200) { return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }); }
