"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Image from "next/image";
import {
  ClipboardCheck,
  CircleHelp,
  Loader2,
  Send,
  Sprout,
  X,
} from "lucide-react";
import styles from "./rovie-assistant.module.css";

type RovieMessage = {
  role: "user" | "assistant";
  content: string;
};

function renderAssistantContent(content: string) {
  return content.split(/(\*\*[\s\S]*?\*\*)/g).map((part, index) => {
    const isBold = part.startsWith("**") && part.endsWith("**");

    return isBold ? (
      <strong key={`${part}-${index}`}>{part.slice(2, -2)}</strong>
    ) : (
      <span key={`${part}-${index}`}>{part}</span>
    );
  });
}

const welcomeMessage: RovieMessage = {
  role: "assistant",
  content:
    "Hi, I'm Rovie. I can help with SeedRover sales, inventory, crops, rover status, and farm operations from the web console.",
};

const suggestions = [
  { label: "How do I start planting?", icon: Sprout },
  { label: "What should I check before planting?", icon: ClipboardCheck },
  { label: "Why is rover control locked?", icon: CircleHelp },
];

const maxStoredMessages = 20;

function isStoredMessage(value: unknown): value is RovieMessage {
  if (!value || typeof value !== "object") {
    return false;
  }

  const message = value as Record<string, unknown>;

  return (
    (message.role === "user" || message.role === "assistant") &&
    typeof message.content === "string" &&
    message.content.trim().length > 0 &&
    message.content.length <= 4000
  );
}

function readStoredMessages(storageKey: string) {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const saved = window.localStorage.getItem(storageKey);
    const parsed = saved ? JSON.parse(saved) : [];

    return Array.isArray(parsed)
      ? parsed.filter(isStoredMessage).slice(-maxStoredMessages)
      : [];
  } catch {
    return [];
  }
}

export function RovieAssistant({ profileId }: { profileId: string }) {
  const [open, setOpen] = useState(false);
  const storageKey = `seedrover-rovie-history:${profileId}`;
  const [messages, setMessages] = useState<RovieMessage[]>([welcomeMessage]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [failedQuestion, setFailedQuestion] = useState<string | null>(null);
  const [slow, setSlow] = useState(false);
  const listRef = useRef<HTMLDivElement>(null);
  const historyLoadedRef = useRef(false);
  const loadedStorageKeyRef = useRef<string | null>(null);
  const activeStorageKeyRef = useRef(storageKey);
  const requestControllerRef = useRef<AbortController | null>(null);
  useEffect(() => () => requestControllerRef.current?.abort(), []);

  useEffect(() => {
    if (!historyLoadedRef.current || loadedStorageKeyRef.current !== storageKey) {
      return;
    }

    try {
      window.localStorage.setItem(
        storageKey,
        JSON.stringify(
          messages
            .filter((message) => message !== welcomeMessage)
            .slice(-maxStoredMessages),
        ),
      );
    } catch {
      // The assistant still works when browser storage is unavailable.
    }
  }, [messages, storageKey]);

  useEffect(() => {
    if (!open) {
      return;
    }

    listRef.current?.scrollTo({
      top: listRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages, open]);

  function friendlyError(code?: string) {
    switch (code) {
      case "sign_in_required": return "Your session ended. Sign in again to ask Rovie.";
      case "account_inactive": return "This account is inactive. Ask an administrator for help.";
      case "permission_denied": return "Your account does not have access to that information.";
      case "rate_limited": return "Rovie is receiving too many requests. Please wait a moment, then retry.";
      case "request_timeout": return "Rovie is taking too long to respond. Your question is saved; retry when ready.";
      case "invalid_question": return "Please check your question and try again.";
      case "question_too_long": return "Please keep questions under 2,000 characters.";
      case "farm_data_unavailable": return "Farm information could not be loaded. Your question is saved; try again.";
      default: return "Rovie is temporarily unavailable. Your question is saved; try again.";
    }
  }

  async function sendQuestion(rawQuestion: string, retry = false) {
    const question = rawQuestion.trim();

    if (!question || sending) {
      return;
    }

    const nextMessages: RovieMessage[] = retry
      ? messages
      : [...messages, { role: "user", content: question }];
    if (!retry) setMessages(nextMessages);
    setSending(true);
    setNotice(null);
    setSlow(false);
    const slowTimer = window.setTimeout(() => setSlow(true), 10_000);
    const controller = new AbortController();
    requestControllerRef.current = controller;
    const timeout = window.setTimeout(() => controller.abort(), 30_000);

    try {
      const response = await fetch("/api/assistant", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          question,
          history: nextMessages.slice(-10),
        }),
        signal: controller.signal,
      });
      const data = await response.json().catch(() => null);
      if (activeStorageKeyRef.current !== storageKey) return;

      if (!response.ok) {
        setNotice(`${friendlyError(data?.code)}${data?.requestId ? ` (Ref: ${data.requestId})` : ""}`);
        setFailedQuestion(data?.retryable ? question : null);
        return;
      }

      if (data?.status === "error" || typeof data?.answer !== "string" || !data.answer.trim()) {
        setNotice(`${friendlyError(data?.code)}${data?.requestId ? ` (Ref: ${data.requestId})` : ""}`);
        setFailedQuestion(data?.retryable ? question : null);
        return;
      }

      setMessages([
        ...nextMessages,
        {
          role: "assistant",
          content: data.answer,
        },
      ]);
      setFailedQuestion(null);
      setInput("");
      if (data?.notice) setNotice(data.notice);
    } catch {
      if (activeStorageKeyRef.current !== storageKey) return;
      setNotice(controller.signal.aborted
        ? "Rovie is taking too long to respond. Your question is saved; retry when ready."
        : "Could not connect to Rovie. Check your connection and retry.");
      setFailedQuestion(question);
    } finally {
      window.clearTimeout(timeout);
      window.clearTimeout(slowTimer);
      if (requestControllerRef.current === controller) {
        requestControllerRef.current = null;
        setSending(false);
        setSlow(false);
      }
    }
  }

  async function sendMessage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await sendQuestion(input);
  }

  function openAssistant() {
    if (!historyLoadedRef.current || loadedStorageKeyRef.current !== storageKey) {
      setMessages([welcomeMessage, ...readStoredMessages(storageKey)]);
      historyLoadedRef.current = true;
      loadedStorageKeyRef.current = storageKey;
    }

    setOpen(true);
  }

  return (
    <>
      <button
        aria-expanded={open}
        aria-label="Open Rovie assistant"
        className={styles.floatingButton}
        title="Ask Rovie"
        type="button"
        onClick={openAssistant}
      >
        <Image alt="" height={50} src="/mascots/assistant.png" width={50} />
        <span>Ask Rovie</span>
      </button>

      {open ? (
        <div className={styles.chatDock}>
          <section aria-label="Rovie assistant" className={styles.modal} role="dialog">
            <header className={styles.header}>
              <div className={styles.titleGroup}>
                <span className={styles.avatar}>
                  <Image alt="Rovie mascot" height={54} src="/mascots/assistant.png" width={54} />
                </span>
                <div>
                  <p>SeedRover assistant</p>
                  <h2>Rovie</h2>
                </div>
              </div>
              <button aria-label="Close Rovie" type="button" onClick={() => setOpen(false)}>
                <X size={18} />
              </button>
            </header>

            <div className={styles.messages} ref={listRef}>
              {messages.map((message, index) => (
                <article className={styles.message} data-role={message.role} key={`${message.role}-${index}`}>
                  {message.role === "assistant" ? (
                    <Image alt="" className={styles.messageMascot} height={34} src="/mascots/assistant.png" width={34} />
                  ) : null}
                  <p>{renderAssistantContent(message.content)}</p>
                </article>
              ))}
              {sending ? (
                <article className={styles.message} data-role="assistant">
                  <Image alt="" className={styles.messageMascot} height={34} src="/mascots/thinking.png" width={34} />
                  <p className={styles.typing}>
                    <Loader2 size={15} />
                    Rovie is preparing an answer...
                  </p>
                </article>
              ) : null}
            </div>

            {messages.length === 1 && !sending ? (
              <div aria-label="Suggested questions" className={styles.suggestions}>
                <span>Try asking:</span>
                <div>
                  {suggestions.map(({ label, icon: Icon }) => (
                    <button key={label} type="button" onClick={() => void sendQuestion(label)}>
                      <Icon aria-hidden="true" size={16} />
                      <span>{label}</span>
                    </button>
                  ))}
                </div>
              </div>
            ) : null}

            {slow && sending ? <div aria-live="polite" className={styles.slowNotice}>This is taking longer than usual. Please wait.</div> : null}
            {notice ? (
              <div className={styles.notice} role="status">
                <span>{notice}</span>
                {failedQuestion && !sending ? <button type="button" onClick={() => void sendQuestion(failedQuestion, true)}>Retry</button> : null}
              </div>
            ) : null}

            <form className={styles.form} onSubmit={sendMessage}>
              <input
                aria-label="Ask Rovie"
                disabled={sending || Boolean(failedQuestion)}
                maxLength={2000}
                placeholder="Ask Rovie about sales, stock, crops..."
                value={input}
                onChange={(event) => setInput(event.target.value)}
              />
              <button disabled={sending || Boolean(failedQuestion) || !input.trim()} type="submit">
                {sending ? <Loader2 className={styles.spin} size={17} /> : <Send size={17} />}
              </button>
            </form>
          </section>
        </div>
      ) : null}
    </>
  );
}
