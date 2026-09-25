"use client";

import { useState, type ReactNode } from "react";
import { Check, ChevronDown } from "lucide-react";
import styles from "@/app/(portal)/crops/page.module.css";

type ThemedSelectProps = {
  defaultValue?: string;
  icon?: ReactNode;
  label: string;
  name?: string;
  onChange?: (value: string) => void;
  options: string[];
  placeholder?: string;
  required?: boolean;
  value?: string;
  variant?: "toolbar" | "form";
};

export function ThemedSelect({
  defaultValue,
  icon,
  label,
  name,
  onChange,
  options,
  placeholder,
  required = false,
  value,
  variant = "form",
}: ThemedSelectProps) {
  const [open, setOpen] = useState(false);
  const [internalValue, setInternalValue] = useState(defaultValue ?? options[0] ?? "");
  const selectedValue = value ?? internalValue;

  function handleSelect(nextValue: string) {
    setInternalValue(nextValue);
    onChange?.(nextValue);
    setOpen(false);
  }

  return (
    <div
      className={`${styles.themedSelect} ${variant === "toolbar" ? styles.themedSelectToolbar : styles.themedSelectForm}`}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setOpen(false);
      }}
    >
      {name ? <input name={name} type="hidden" value={selectedValue} /> : null}
      {variant === "form" ? <span className={styles.themedSelectLabel}>{label}{required ? <span aria-hidden="true" className={styles.requiredMarker}>*</span> : null}</span> : null}
      <button aria-expanded={open} className={styles.themedSelectButton} type="button" onClick={() => setOpen((current) => !current)}>
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        {variant === "toolbar" ? <span className={styles.themedSelectLabel}>{label}</span> : null}
        <span className={styles.themedSelectValue}>{selectedValue || placeholder || "No stage change"}</span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? <div className={styles.themedSelectMenu}>
        {options.map((option) => {
          const selected = option === selectedValue;
          return (
            <button
              className={styles.themedSelectOption}
              data-selected={selected ? "true" : "false"}
              key={option}
              type="button"
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => handleSelect(option)}
            >
              <span>{option || "No stage change"}</span>
              {selected ? <Check size={15} /> : null}
            </button>
          );
        })}
      </div> : null}
    </div>
  );
}
