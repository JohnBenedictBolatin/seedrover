const DATABASE_DECIMAL_PATTERN = /^(?:\d{1,10}(?:\.\d{0,2})?|\.\d{1,2})$/;

export function parseDatabaseDecimal(value, label) {
  const raw = String(value ?? "").trim();
  if (!DATABASE_DECIMAL_PATTERN.test(raw)) {
    throw new Error(`${label} must be a number with up to two decimal places.`);
  }
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) throw new Error(`${label} must be a valid number.`);
  return parsed;
}

export function isDatabaseDecimal(value) {
  return DATABASE_DECIMAL_PATTERN.test(String(value ?? "").trim());
}
