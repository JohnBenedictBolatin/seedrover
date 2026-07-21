"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import { Loader2, Send, X } from "lucide-react";
import styles from "./rovie-assistant.module.css";

type RovieMessage = {
  role: "user" | "assistant";
  content: string;
};

const welcomeMessage: RovieMessage = {
  role: "assistant",
  content:
    "Hi, I'm Rovie. I can help with SeedRover sales, inventory, crops, rover status, and farm operations from the web console.",
};

export function RovieAssistant() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<RovieMessage[]>([welcomeMessage]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    listRef.current?.scrollTo({
      top: listRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages, open]);

  async function sendMessage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const question = input.trim();

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
          history: nextMessages,
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

  return (
    <>
      <button
        aria-expanded={open}
        aria-label="Open Rovie assistant"
        className={styles.floatingButton}
        title="Ask Rovie"
        type="button"
        onClick={() => setOpen(true)}
      >
        <img alt="" src="/mascot/rovie-assistant.png" />
        <span>Ask Rovie</span>
      </button>

      {open ? (
        <div className={styles.chatDock}>
          <section aria-label="Rovie assistant" className={styles.modal} role="dialog">
            <header className={styles.header}>
              <div className={styles.titleGroup}>
                <span className={styles.avatar}>
                  <img alt="Rovie mascot" src="/mascot/rovie-assistant.png" />
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
                    <img alt="" className={styles.messageMascot} src="/mascot/rovie-assistant.png" />
                  ) : null}
                  <p>{message.content}</p>
                </article>
              ))}
              {sending ? (
                <article className={styles.message} data-role="assistant">
                  <img alt="" className={styles.messageMascot} src="/mascot/rovie-thinking.png" />
                  <p className={styles.typing}>
                    <Loader2 size={15} />
                    Rovie is checking farm data...
                  </p>
                </article>
              ) : null}
            </div>

            {notice ? <div className={styles.notice}>{notice}</div> : null}

            <form className={styles.form} onSubmit={sendMessage}>
              <input
                aria-label="Ask Rovie"
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
