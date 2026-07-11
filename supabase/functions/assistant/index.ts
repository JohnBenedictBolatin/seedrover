import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

const systemInstruction = `
You are Rovie, the friendly SeedRover assistant.

Scope:
- Answer questions about the SeedRover app, rover workflows, crop monitoring,
  stocks/inventory, notifications, profile/user management, and planting.
- Answer general planting questions for small farm use, especially calamansi,
  peanut, and sitaw.
- Keep answers practical, concise, and friendly.
- When app context is provided, answer data-specific questions from that
  context and say "Based on the current app data" when useful.
- Do not call current app context "live Supabase data" unless the context says
  it came from Supabase.

SeedRover app facts:
- Main modules: Dashboard, Rover Control, Crops, Stocks, Notifications, Profile.
- Rover Control includes movement, camera placeholder, soil check, planting start,
  emergency stop, battery, seed level, Wi-Fi, Bluetooth, camera, and sensors.
- Planting should follow the simplified process: check soil first, then start
  planting only if soil is suitable.
- Users cannot use rover movement during planting unless emergency stop is used.
- Crops tracks rover-planted crop records, crop details, growth stage,
  estimated harvest, and maintenance history.
- Stocks tracks harvested produce inventory, stock in, stock out, adjustments,
  and transaction history.
- Farm Analytics summarizes crop planting, stock-out/sales movement, top sold
  items, and observed monthly trends from current app data.
- Current sales status should be answered from
  context.farmAnalytics.currentSalesStatus when available. It can summarize
  stock-out/sales transaction count, total quantity moved, latest sale movement,
  recent sales, and top sold item even when long-term trend data is limited.

Safety:
- Do not claim to control hardware.
- Do not invent live sensor values or database records.
- For high-risk agricultural chemical, pesticide, or safety questions, advise
  checking local guidance and product labels.
`;

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");

  if (!apiKey) {
    return json({ error: "Missing GEMINI_API_KEY secret." }, 500);
  }

  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite";
  const body = await request.json().catch(() => null);
  const question = typeof body?.question === "string" ? body.question.trim() : "";
  const history = Array.isArray(body?.history) ? body.history : [];
  const appContext = sanitizeContext(body?.context);

  if (!question) {
    return json({ error: "Question is required." }, 400);
  }

  const contents = normalizeHistory(history);

  if (contents.length === 0 || lastUserText(contents) !== question) {
    contents.push({
      role: "user",
      parts: [{ text: question }],
    });
  }

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: buildSystemInstruction(appContext) }],
        },
        contents,
        generationConfig: {
          temperature: 0.35,
          maxOutputTokens: 550,
        },
      }),
    },
  );

  const geminiJson = await geminiResponse.json().catch(() => null);

  if (!geminiResponse.ok) {
    console.error("Gemini request failed", {
      status: geminiResponse.status,
      details: geminiJson?.error?.message ?? "No details returned.",
    });

    return json(
      {
        error: "Gemini request failed.",
        details: geminiJson?.error?.message ?? "No details returned.",
      },
      502,
    );
  }

  const answer = geminiJson?.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part.text ?? "")
    ?.join("")
    ?.trim();

  if (!answer) {
    console.error("Gemini returned an empty answer", geminiJson);

    return json({ error: "Gemini returned an empty answer." }, 502);
  }

  return json({ answer });
});

function buildSystemInstruction(appContext: unknown) {
  if (!appContext) {
    return systemInstruction;
  }

  return `${systemInstruction}

Current app data context:
${JSON.stringify(appContext, null, 2)}

Rules for current app data:
- Use this context to answer questions about crop watering, crop status,
  stock restocking, stock quantity, rover status, recent activities, and farm
  analytics.
- Use context.farmAnalytics for questions about best months or times to sell,
  top products, crop planting trends, sales seasonality, and inventory movement.
- For "current sales status" or "sales right now" questions, use
  context.farmAnalytics.currentSalesStatus first. Do not answer that trends
  cannot be determined unless the user specifically asks for trends or
  seasonality.
- When suggesting the best time of year to sell, base the answer on observed
  stock-out/sales data first. If data is limited, say confidence is low and
  frame the suggestion as an early signal.
- If a record is not present in the context, say it is not available in the
  current app data.
- Keep dates readable.
- Do not invent records that are not present in the context.
`;
}

function sanitizeContext(context: unknown) {
  if (!context || typeof context !== "object") {
    return null;
  }

  const value = context as Record<string, unknown>;

  return {
    source: value.source,
    note: value.note,
    generatedAt: value.generatedAt,
    rover: value.rover,
    crops: Array.isArray(value.crops) ? value.crops.slice(0, 12) : [],
    stocks: Array.isArray(value.stocks) ? value.stocks.slice(0, 12) : [],
    farmAnalytics:
      value.farmAnalytics && typeof value.farmAnalytics === "object"
        ? value.farmAnalytics
        : {},
    recentActivities: Array.isArray(value.recentActivities)
      ? value.recentActivities.slice(0, 8)
      : [],
  };
}

function normalizeHistory(history: unknown[]) {
  const messages = history
    .filter((item): item is ChatMessage => {
      if (!item || typeof item !== "object") {
        return false;
      }

      const message = item as Record<string, unknown>;

      return (
        (message.role === "user" || message.role === "assistant") &&
        typeof message.content === "string" &&
        message.content.trim().length > 0
      );
    })
    .slice(-10);

  while (messages.length > 0 && messages[0].role !== "user") {
    messages.shift();
  }

  const normalized: Array<{ role: "user" | "model"; parts: Array<{ text: string }> }> = [];

  for (const message of messages) {
    const role = message.role === "assistant" ? "model" : "user";
    const text = message.content.trim();
    const last = normalized[normalized.length - 1];

    if (last?.role === role) {
      last.parts[0].text = `${last.parts[0].text}\n\n${text}`;
      continue;
    }

    normalized.push({
      role,
      parts: [{ text }],
    });
  }

  return normalized;
}

function lastUserText(
  contents: Array<{ role: string; parts: Array<{ text: string }> }>,
) {
  for (let index = contents.length - 1; index >= 0; index--) {
    if (contents[index].role === "user") {
      return contents[index].parts[0]?.text ?? "";
    }
  }

  return "";
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
