import { NextResponse } from "next/server";
import { getCurrentAdminProfile } from "@/lib/auth";
import { askRovie, type AssistantChatMessage } from "@/lib/assistant";
import { checkRateLimit, rateLimitResponse } from "@/lib/rate-limit";

export async function POST(request: Request) {
  const rateLimit = await checkRateLimit({
    limit: 20,
    namespace: "rovie-assistant",
    windowMs: 60 * 1000,
  });

  if (rateLimit.limited) {
    return rateLimitResponse(
      "Rovie is receiving too many requests. Please wait a moment before asking again.",
      rateLimit,
    );
  }

  const profile = await getCurrentAdminProfile();

  if (!profile) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const question = typeof body?.question === "string" ? body.question.trim() : "";
  const history = Array.isArray(body?.history)
    ? body.history.filter(isAssistantMessage).slice(-10)
    : [];

  if (!question) {
    return NextResponse.json({ error: "Question is required." }, { status: 400 });
  }

  const result = await askRovie({ history, profile, question });

  return NextResponse.json(result);
}

function isAssistantMessage(value: unknown): value is AssistantChatMessage {
  if (!value || typeof value !== "object") {
    return false;
  }

  const message = value as Record<string, unknown>;

  return (
    (message.role === "user" || message.role === "assistant") &&
    typeof message.content === "string" &&
    message.content.trim().length > 0
  );
}
