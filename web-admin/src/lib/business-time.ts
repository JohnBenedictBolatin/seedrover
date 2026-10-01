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

function manilaMidnight(year: number, month: number, day: number) {
  return new Date(
    `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}T00:00:00+08:00`,
  );
}

export function businessDateKey(now = new Date()) {
  const { year, month, day } = manilaDateParts(now);
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export function startOfBusinessDay(now = new Date()) {
  const { year, month, day } = manilaDateParts(now);
  return manilaMidnight(year, month, day);
}

export function startOfBusinessMonth(now = new Date()) {
  const { year, month } = manilaDateParts(now);
  return manilaMidnight(year, month, 1);
}

export function startOfBusinessYear(now = new Date()) {
  const { year } = manilaDateParts(now);
  return manilaMidnight(year, 1, 1);
}

export function startOfBusinessWeek(now = new Date()) {
  const { year, month, day } = manilaDateParts(now);
  const date = new Date(Date.UTC(year, month - 1, day));
  const daysSinceMonday = (date.getUTCDay() + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday);
  return manilaMidnight(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
}

export function startOfNextBusinessMonth(now = new Date()) {
  const { year, month } = manilaDateParts(now);
  const next = new Date(Date.UTC(year, month, 1));
  return new Date(
    `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, "0")}-01T00:00:00+08:00`,
  );
}
