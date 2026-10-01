export function manilaDate(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function daysUntilManilaDate(date: string, today = manilaDate()) {
  return Math.round((Date.parse(`${date}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / 86_400_000);
}

export function displayDate(date: string) {
  return new Date(`${date}T00:00:00Z`).toLocaleDateString("en-PH", { timeZone: "UTC", day: "numeric", month: "short", year: "numeric" });
}
