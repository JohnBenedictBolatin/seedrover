import type { ChangeEvent, InputHTMLAttributes, KeyboardEvent, ClipboardEvent } from "react";
import { normalizeContactNumber, sanitizeContactDraft } from "@/lib/contact-number.mjs";
import { sharedWorkflowRules } from "@/lib/shared-workflow-terms";

const MAX_DECIMAL_INTEGER_DIGITS = 10;
const MAX_DECIMAL_PLACES = 2;

function normalizeDecimal(value: string) {
  const numeric = value.replace(/[^0-9.]/g, "");
  const [integer = "", ...fractionParts] = numeric.split(".");
  const fraction = fractionParts.join("").slice(0, MAX_DECIMAL_PLACES);
  const limitedInteger = integer.slice(0, MAX_DECIMAL_INTEGER_DIGITS);
  return fractionParts.length > 0 ? `${limitedInteger}.${fraction}` : limitedInteger;
}

export function NumericInput(props: InputHTMLAttributes<HTMLInputElement>) {
  const { onChange, onKeyDown, onPaste, value, defaultValue, ...inputProps } = props;

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    const input = event.currentTarget;
    const normalized = normalizeDecimal(input.value);
    if (input.value !== normalized) input.value = normalized;
    onChange?.(event);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (["e", "E", "+", "-"].includes(event.key)) event.preventDefault();
    onKeyDown?.(event);
  }

  function handlePaste(event: ClipboardEvent<HTMLInputElement>) {
    const pasted = event.clipboardData.getData("text").trim();
    if (!/^\d*(?:\.\d*)?$/.test(pasted)) event.preventDefault();
    onPaste?.(event);
  }

  return (
    <input
      {...inputProps}
      type="number"
      inputMode="decimal"
      value={value == null ? value : normalizeDecimal(String(value))}
      defaultValue={defaultValue == null ? defaultValue : normalizeDecimal(String(defaultValue))}
      onChange={handleChange}
      onKeyDown={handleKeyDown}
      onPaste={handlePaste}
    />
  );
}

function displayContact(value: string) {
  try {
    return normalizeContactNumber(value, { allowLegacy: true }) ?? "";
  } catch {
    return sanitizeContactDraft(value);
  }
}

export function ContactNumberInput(props: InputHTMLAttributes<HTMLInputElement>) {
  const { onChange, onKeyDown, onPaste, value, defaultValue, ...inputProps } = props;

  function handleChange(event: ChangeEvent<HTMLInputElement>) {
    const input = event.currentTarget;
    const normalized = sanitizeContactDraft(input.value);
    if (input.value !== normalized) input.value = normalized;
    onChange?.(event);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (!event.ctrlKey && !event.metaKey && !event.altKey && event.key.length === 1 && !/\d/.test(event.key)) event.preventDefault();
    onKeyDown?.(event);
  }

  function handlePaste(event: ClipboardEvent<HTMLInputElement>) {
    const pasted = event.clipboardData.getData("text").trim();
    event.preventDefault();
    const input = event.currentTarget;
    const start = input.selectionStart ?? input.value.length;
    const end = input.selectionEnd ?? start;
    let nextValue: string;
    try {
      const normalizedPaste = normalizeContactNumber(pasted, { required: true });
      nextValue = sanitizeContactDraft(
        `${input.value.slice(0, start)}${normalizedPaste}${input.value.slice(end)}`,
      );
    } catch {
      onPaste?.(event);
      return;
    }
    input.value = nextValue;
    input.setSelectionRange(nextValue.length, nextValue.length);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    onPaste?.(event);
  }

  return (
    <input
      {...inputProps}
      type="tel"
      inputMode="numeric"
      maxLength={sharedWorkflowRules.contactNumberDigits}
      minLength={sharedWorkflowRules.contactNumberDigits}
      pattern={sharedWorkflowRules.contactNumberPattern}
      value={value == null ? value : displayContact(String(value))}
      defaultValue={defaultValue == null ? defaultValue : displayContact(String(defaultValue))}
      onChange={handleChange}
      onKeyDown={handleKeyDown}
      onPaste={handlePaste}
    />
  );
}
