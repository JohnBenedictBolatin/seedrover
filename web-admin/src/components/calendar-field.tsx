"use client";

import { useCallback, useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { DayPicker } from "react-day-picker";
import styles from "./calendar-field.module.css";

type CalendarFieldProps = {
  className?: string;
  defaultValue?: string;
  disabled?: boolean;
  includeTime?: boolean;
  label: string;
  name?: string;
  onChange?: (value: string) => void;
  required?: boolean;
  value?: string;
};

type PopoverPosition = { left: number; top: number };

function parseDateValue(value: string, includeTime: boolean) {
  if (!value) return undefined;

  if (includeTime) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? undefined : parsed;
  }

  const [year, month, day] = value.split("-").map(Number);
  if (!year || !month || !day) return undefined;
  const parsed = new Date(year, month - 1, day, 12, 0, 0, 0);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

function toDateValue(date: Date) {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, "0"),
    String(date.getDate()).padStart(2, "0"),
  ].join("-");
}

function toDateTimeValue(date: Date) {
  return `${toDateValue(date)}T${String(date.getHours()).padStart(2, "0")}:${String(
    date.getMinutes(),
  ).padStart(2, "0")}`;
}

export function CalendarField({
  className,
  defaultValue = "",
  disabled = false,
  includeTime = false,
  label,
  name,
  onChange,
  required = false,
  value,
}: CalendarFieldProps) {
  const [internalValue, setInternalValue] = useState(defaultValue);
  const [open, setOpen] = useState(false);
  const [invalid, setInvalid] = useState(false);
  const [position, setPosition] = useState<PopoverPosition | null>(null);
  const fieldId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const popoverRef = useRef<HTMLDivElement>(null);
  const currentValue = value ?? internalValue;
  const selectedDate = parseDateValue(currentValue, includeTime);
  const visibleDate = selectedDate ?? new Date();
  const timeValue = `${String(visibleDate.getHours()).padStart(2, "0")}:${String(
    visibleDate.getMinutes(),
  ).padStart(2, "0")}`;

  const setValue = useCallback((nextValue: string) => {
    if (value === undefined) setInternalValue(nextValue);
    setInvalid(false);
    onChange?.(nextValue);
  }, [onChange, value]);

  const updatePosition = useCallback(() => {
    const trigger = triggerRef.current;
    if (!trigger) return;

    const rect = trigger.getBoundingClientRect();
    const popoverWidth = Math.min(320, window.innerWidth - 16);
    const measuredHeight = popoverRef.current?.offsetHeight ?? (includeTime ? 430 : 350);
    const roomBelow = window.innerHeight - rect.bottom;
    const top = roomBelow >= measuredHeight + 12
      ? rect.bottom + 8
      : Math.max(8, rect.top - measuredHeight - 8);
    const left = Math.min(
      Math.max(8, rect.left),
      Math.max(8, window.innerWidth - popoverWidth - 8),
    );

    setPosition({ left, top });
  }, [includeTime]);

  useEffect(() => {
    if (!open) return;

    updatePosition();
    const frame = window.requestAnimationFrame(updatePosition);
    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node;
      if (!rootRef.current?.contains(target) && !popoverRef.current?.contains(target)) {
        setOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        triggerRef.current?.focus();
      }
    };

    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    window.addEventListener("resize", updatePosition);
    window.addEventListener("scroll", updatePosition, true);

    return () => {
      window.cancelAnimationFrame(frame);
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("resize", updatePosition);
      window.removeEventListener("scroll", updatePosition, true);
    };
  }, [open, updatePosition]);

  useEffect(() => {
    const form = rootRef.current?.closest("form");
    if (!form || !required) return;

    const validate = (event: SubmitEvent) => {
      if (currentValue) return;
      event.preventDefault();
      event.stopPropagation();
      setInvalid(true);
      setOpen(true);
      window.requestAnimationFrame(() => triggerRef.current?.focus());
    };

    form.addEventListener("submit", validate, true);
    return () => form.removeEventListener("submit", validate, true);
  }, [currentValue, required]);

  function handleDateSelect(nextDate: Date | undefined) {
    if (!nextDate) return;

    if (includeTime) {
      const updated = new Date(visibleDate);
      updated.setFullYear(nextDate.getFullYear(), nextDate.getMonth(), nextDate.getDate());
      setValue(toDateTimeValue(updated));
      return;
    }

    setValue(toDateValue(nextDate));
    setOpen(false);
    triggerRef.current?.focus();
  }

  function handleTimeChange(nextTime: string) {
    const [hours, minutes] = nextTime.split(":").map(Number);
    const updated = new Date(visibleDate);
    updated.setHours(hours || 0, minutes || 0, 0, 0);
    setValue(toDateTimeValue(updated));
  }

  const displayLabel = currentValue
    ? new Intl.DateTimeFormat("en-PH", includeTime
      ? { month: "long", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" }
      : { month: "long", day: "numeric", year: "numeric" }).format(visibleDate)
    : includeTime ? "Choose date and time" : "Choose a date";

  return (
    <div className={`${styles.calendarField}${className ? ` ${className}` : ""}`} ref={rootRef}>
      <span className={styles.fieldLabel} id={`${fieldId}-label`}>
        {label}{required ? <b aria-hidden="true"> *</b> : null}
      </span>
      {name ? <input name={name} type="hidden" value={currentValue} /> : null}
      <button
        aria-expanded={open}
        aria-haspopup="dialog"
        aria-labelledby={`${fieldId}-label ${fieldId}-value`}
        className={styles.calendarTrigger}
        data-invalid={invalid ? "true" : "false"}
        disabled={disabled}
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
        <CalendarDays size={17} />
        <span data-empty={currentValue ? "false" : "true"} id={`${fieldId}-value`}>{displayLabel}</span>
      </button>
      {open && typeof document !== "undefined" ? createPortal(
        <div
          aria-label={`Choose ${label.toLowerCase()}`}
          className={styles.calendarPopover}
          ref={popoverRef}
          role="dialog"
          style={position ? { left: position.left, top: position.top } : { visibility: "hidden" }}
        >
          <div className={styles.calendarShell}>
            <DayPicker
              className={styles.calendarRoot}
              classNames={{
                months: styles.calendarMonths,
                month: styles.calendarMonth,
                nav: styles.calendarNav,
                button_previous: styles.calendarNavButton,
                button_next: styles.calendarNavButton,
                month_caption: styles.calendarCaption,
                caption_label: styles.calendarCaptionLabel,
                weekdays: styles.calendarWeekdays,
                weekday: styles.calendarWeekday,
                week: styles.calendarWeek,
                day: styles.calendarDay,
                today: styles.calendarToday,
                selected: styles.calendarSelected,
                outside: styles.calendarOutside,
                chevron: styles.calendarChevron,
              }}
              components={{
                Chevron: ({ orientation, className: chevronClassName, ...props }) =>
                  orientation === "left"
                    ? <ChevronLeft className={chevronClassName} size={16} {...props} />
                    : <ChevronRight className={chevronClassName} size={16} {...props} />,
              }}
              mode="single"
              selected={selectedDate}
              showOutsideDays
              onSelect={handleDateSelect}
            />
            {includeTime ? (
              <label className={styles.calendarTimeRow}>
                <span>Time</span>
                <input
                  className={styles.calendarTimeInput}
                  type="time"
                  value={timeValue}
                  onChange={(event) => handleTimeChange(event.target.value)}
                />
              </label>
            ) : null}
            <div className={styles.calendarActions}>
              {!required && currentValue ? (
                <button className={styles.calendarClearButton} type="button" onClick={() => { setValue(""); setOpen(false); }}>
                  Clear
                </button>
              ) : <span />}
              <button className={styles.calendarActionButton} type="button" onClick={() => setOpen(false)}>
                Done
              </button>
            </div>
          </div>
        </div>,
        document.body,
      ) : null}
    </div>
  );
}
