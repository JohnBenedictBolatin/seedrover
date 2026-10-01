const LEGACY_CONTACT = "not provided";
const LOCAL_PATTERN = /^[0-9]{11}$/;
const FORMATTED_PHONE_PATTERN = /^\+?[0-9\s().-]+$/;

/** Normalize a submitted local number or Philippine +63 number. */
export function normalizeContactNumber(value, { required = false, allowLegacy = false } = {}) {
  const raw = String(value ?? "").trim();
  if (!raw) {
    if (required) throw new Error("Enter an 11-digit contact number.");
    return null;
  }

  if (allowLegacy && raw.toLowerCase() === LEGACY_CONTACT) return "Not provided";
  if (!FORMATTED_PHONE_PATTERN.test(raw)) {
    throw new Error("Contact number must contain exactly 11 digits.");
  }

  const digits = raw.replace(/\D/g, "");
  if ((raw.startsWith("+63") || (!raw.startsWith("+") && digits.startsWith("63"))) && digits.length === 12) {
    return `0${digits.slice(2)}`;
  }
  if (LOCAL_PATTERN.test(digits) && digits === raw) return digits;
  if (LOCAL_PATTERN.test(digits) && /^[0-9\s().-]+$/.test(raw)) return digits;

  throw new Error("Contact number must contain exactly 11 digits.");
}

/** Keep a live contact field numeric and within its 11-digit entry limit. */
export function sanitizeContactDraft(value) {
  const raw = String(value ?? "");
  if (FORMATTED_PHONE_PATTERN.test(raw)) {
    try {
      const normalized = normalizeContactNumber(raw);
      if (normalized) return normalized;
    } catch {
      // Partial entry is allowed while the user is typing.
    }
  }
  const digits = raw.replace(/\D/g, "");
  if (digits.startsWith("63") && digits.length === 12) return `0${digits.slice(2)}`;
  return digits.slice(0, 11);
}

export function isContactNumber(value, { allowLegacy = false } = {}) {
  try {
    normalizeContactNumber(value, { required: true, allowLegacy });
    return true;
  } catch {
    return false;
  }
}
