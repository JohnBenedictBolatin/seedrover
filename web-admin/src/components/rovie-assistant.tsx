"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
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
  const listRef = useRef<HTMLDivElement>(null);
  const historyLoadedRef = useRef(false);

  useEffect(() => {
    if (!historyLoadedRef.current) {
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

  async function sendQuestion(rawQuestion: string) {
    const question = rawQuestion.trim();

    if (!question || sending) {
      return;
    }

    const nextMessages: RovieMessage[] = [...messages, { role: "user", content: question }];
    setMessages(nextMessages);
    setInput("");
    setSending(true);
    setNotice(null);

    try {
      const response = await fetch("/api/assistant", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          question,
          history: nextMessages.slice(-10),
        }),
      });
      const data = await response.json().catch(() => null);

      if (!response.ok) {
        throw new Error(data?.error ?? "Rovie could not answer right now.");
      }

      setMessages([
        ...nextMessages,
        {
          role: "assistant",
          content: data?.answer ?? "I could not prepare an answer right now.",
        },
      ]);

      if (data?.fallback && data?.detail) {
        setNotice(`Using local fallback. Detail: ${data.detail}`);
      }
    } catch (error) {
      setMessages([
        ...nextMessages,
        {
          role: "assistant",
          content:
            "I had trouble connecting, but I can still help once the assistant service is available.",
        },
      ]);
      setNotice(error instanceof Error ? error.message : "Rovie request failed.");
    } finally {
      setSending(false);
    }
  }

  async function sendMessage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await sendQuestion(input);
  }

  function openAssistant() {
    if (!historyLoadedRef.current) {
      setMessages([welcomeMessage, ...readStoredMessages(storageKey)]);
      historyLoadedRef.current = true;
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
        <img alt="" src="/mascots/assistant.png" />
        <span>Ask Rovie</span>
      </button>

      {open ? (
        <div className={styles.chatDock}>
          <section aria-label="Rovie assistant" className={styles.modal} role="dialog">
            <header className={styles.header}>
              <div className={styles.titleGroup}>
                <span className={styles.avatar}>
                  <img alt="Rovie mascot" src="/mascots/assistant.png" />
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
                    <img alt="" className={styles.messageMascot} src="/mascots/assistant.png" />
                  ) : null}
                  <p>{renderAssistantContent(message.content)}</p>
                </article>
              ))}
              {sending ? (
                <article className={styles.message} data-role="assistant">
                  <img alt="" className={styles.messageMascot} src="/mascots/thinking.png" />
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

            {notice ? <div className={styles.notice}>{notice}</div> : null}

            <form className={styles.form} onSubmit={sendMessage}>
              <input
                aria-label="Ask Rovie"
                maxLength={2000}
                placeholder="Ask Rovie about sales, stock, crops..."
                value={input}
                onChange={(event) => setInput(event.target.value)}
              />
              <button disabled={sending || !input.trim()} type="submit">
                {sending ? <Loader2 className={styles.spin} size={17} /> : <Send size={17} />}
              </button>
            </form>
          </section>
        </div>
      ) : null}
    </>
  );
}
