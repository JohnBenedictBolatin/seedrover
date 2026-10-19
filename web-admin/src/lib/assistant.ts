import { createSupabaseServerClient } from "@/lib/supabase/server";
import { FunctionsHttpError } from "@supabase/supabase-js";

export type AssistantChatMessage = {
  role: "user" | "assistant";
  content: string;
};

export type AssistantResult = {
  status: "answered" | "error";
  answer?: string;
  code?: string;
  retryable?: boolean;
  requestId?: string;
  notice?: string;
};

export async function askRovie({
  history,
  question,
}: {
  history: AssistantChatMessage[];
  question: string;
}): Promise<AssistantResult> {
  const requestId = crypto.randomUUID();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { status: "error", code: "service_unavailable", retryable: true, requestId };

  try {
    const { data, error } = await supabase.functions.invoke("assistant", {
      body: { question, history },
    });
    if (error) {
      let status = 0;
      let payload: Record<string, unknown> | null = null;
      if (error instanceof FunctionsHttpError) {
        status = error.context.status;
        payload = await error.context.clone().json().catch(() => null);
      }
      const code = typeof payload?.code === "string" ? payload.code : status === 401 ? "sign_in_required"
        : status === 403 ? "permission_denied"
        : status === 429 ? "rate_limited"
        : status === 504 ? "request_timeout"
        : status === 400 ? "invalid_question"
        : "service_unavailable";
      return {
        status: "error",
        code,
        retryable: payload?.retryable === true || status === 0 || status >= 500,
        requestId: typeof payload?.requestId === "string" ? payload.requestId : requestId,
      };
    }
    const answer = typeof data?.answer === "string" ? data.answer.trim() : "";
    if (!answer) return { status: "error", code: "empty_response", retryable: true, requestId };
    return {
      status: "answered",
      answer,
      requestId: typeof data.requestId === "string" ? data.requestId : requestId,
      notice: typeof data.notice === "string" ? data.notice : undefined,
    };
  } catch {
    return { status: "error", code: "service_unavailable", retryable: true, requestId };
  }
}
