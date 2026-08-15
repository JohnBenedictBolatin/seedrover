import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);
  const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
  if ((request.headers.get("authorization") ?? "") !== `Bearer ${serviceKey}`) {
    return json({ error: "Unauthorized." }, 401);
  }

  try {
    const payload = await request.json() as Json;
    const notification = (payload.record ?? payload) as Json;
    const recipientId = String(notification.recipient_id ?? "");
    if (!recipientId) return json({ error: "Missing recipient." }, 400);
    const admin = createClient(required("SUPABASE_URL"), serviceKey);
    const { data: tokens, error } = await admin.from("push_device_tokens")
      .select("id,token").eq("profile_id", recipientId).eq("is_active", true);
    if (error) throw error;
    if (!tokens?.length) return json({ status: "no-active-devices" });

    const credential = JSON.parse(required("FCM_SERVICE_ACCOUNT_JSON")) as Json;
    const accessToken = await googleAccessToken(credential);
    const projectId = String(credential.project_id);
    const results = [];
    for (const device of tokens) {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: {
          token: device.token,
          notification: { title: String(notification.title ?? "SeedRover"), body: String(notification.message ?? "") },
          data: { deep_link: String(notification.action_route ?? "/notifications"), route: String(notification.action_route ?? "/notifications"), notification_id: String(notification.id ?? "") },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
        } }),
      });
      const body = await response.json().catch(() => ({}));
      if (response.status === 404 || response.status === 400) {
        await admin.from("push_device_tokens").update({ is_active: false }).eq("id", device.id);
      }
      results.push({ tokenId: device.id, status: response.status, body });
    }
    return json({ status: "processed", results });
  } catch (error) {
    console.error("push-notification failed", error);
    return json({ error: error instanceof Error ? error.message : "Push failed." }, 500);
  }
});

async function googleAccessToken(credential: Json) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: credential.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(String(credential.private_key)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput));
  const assertion = `${signingInput}.${base64UrlBytes(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const body = await response.json() as Json;
  if (!response.ok || !body.access_token) throw new Error("Unable to authorize Firebase Cloud Messaging.");
  return String(body.access_token);
}

function pemBytes(pem: string) {
  const content = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  return Uint8Array.from(atob(content), (char) => char.charCodeAt(0));
}
function base64Url(value: string) { return base64UrlBytes(new TextEncoder().encode(value)); }
function base64UrlBytes(value: Uint8Array) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
function required(name: string) { const value = Deno.env.get(name); if (!value) throw new Error(`Missing ${name}`); return value; }
function json(body: Json, status = 200) { return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }); }
