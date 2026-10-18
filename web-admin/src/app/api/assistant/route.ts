import { NextResponse } from "next/server";
import { getCurrentAdminProfile } from "@/lib/auth";
import { askRovie, type AssistantChatMessage } from "@/lib/assistant";

const maxQuestionLength = 2000;
const maxHistoryMessageLength = 4000;

export async function POST(request: Request) {
  const requestId = crypto.randomUUID();
  const profile = await getCurrentAdminProfile();

  if (!profile) {
    return NextResponse.json(
      { status: "error", code: "sign_in_required", retryable: false, requestId },
      { status: 401 },
    );
  }

  const body = await request.json().catch(() => null);
  const question = typeof body?.question === "string" ? body.question.trim() : "";
  const history = Array.isArray(body?.history)
    ? body.history.filter(isAssistantMessage).slice(-10)
    : [];

  if (!question) {
    return NextResponse.json(
      { status: "error", code: "invalid_question", retryable: false, requestId },
      { status: 400 },
    );
  }

  if (question.length > maxQuestionLength) {
    return NextResponse.json(
      { status: "error", code: "question_too_long", retryable: false, requestId },
      { status: 400 },
    );
  }

  const result = await askRovie({ history, question });
  const status = result.status === "error"
    ? result.code === "rate_limited" ? 429
      : result.code === "permission_denied" ? 403
        : result.code === "sign_in_required" ? 401
          : result.code === "invalid_question" || result.code === "question_too_long" ? 400
            : result.code === "request_timeout" ? 504 : 503
    : 200;
  return NextResponse.json(result, { status });
}

function isAssistantMessage(value: unknown): value is AssistantChatMessage {
  if (!value || typeof value !== "object") {
    return false;
  }

  const message = value as Record<string, unknown>;

  return (
    (message.role === "user" || message.role === "assistant") &&
    typeof message.content === "string" &&
    message.content.trim().length > 0 &&
    message.content.length <= maxHistoryMessageLength
  );
}
