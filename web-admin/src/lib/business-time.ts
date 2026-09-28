const BUSINESS_TIME_ZONE = "Asia/Manila";

function manilaDateParts(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: BUSINESS_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

export function startOfBusinessDay(now = new Date()) {
  const { year, month, day } = manilaDateParts(now);
  return new Date(`${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}T00:00:00+08:00`);
}

export function startOfBusinessMonth(now = new Date()) {
  const { year, month } = manilaDateParts(now);
  return new Date(`${year}-${String(month).padStart(2, "0")}-01T00:00:00+08:00`);
}

export function startOfNextBusinessMonth(now = new Date()) {
  const { year, month } = manilaDateParts(now);
  const next = new Date(Date.UTC(year, month, 1));
  return new Date(
    `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, "0")}-01T00:00:00+08:00`,
  );
}
