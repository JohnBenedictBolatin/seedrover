export function normalizeContactNumber(
  value: unknown,
  options?: { required?: boolean; allowLegacy?: boolean },
): string | null;
export function sanitizeContactDraft(value: unknown): string;
export function isContactNumber(
  value: unknown,
  options?: { allowLegacy?: boolean },
): boolean;
