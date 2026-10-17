const defaultMovementNotes = new Set([
  "Stock added.",
  "Stock received.",
  "Stock issued.",
  "Stock adjusted.",
  "Harvest recorded.",
  "Inventory updated.",
]);

function removeDefaultNote(value) {
  const note = value.trim();
  return defaultMovementNotes.has(note) ? "" : note;
}

function textAfterSeparator(value) {
  const separator = value.indexOf(" - ");
  return separator < 0 ? null : value.slice(separator + 3).trim();
}

/** Returns only the farmer-entered note from legacy combined movement remarks. */
export function inventoryTransactionNote({ type, source, remarks }) {
  const text = String(remarks ?? "").trim();
  const normalizedSource = String(source ?? "").toLowerCase();
  const normalizedType = String(type ?? "").toUpperCase();

  if (
    !text ||
    normalizedType === "OPENING" ||
    normalizedType === "HISTORICAL" ||
    normalizedSource === "sale" ||
    normalizedSource === "void_sale"
  ) {
    return "";
  }

  const lines = text.split(/\r?\n/).map((line) => line.trim());
  const firstLine = lines[0];
  if (normalizedSource === "manual" && lines.length > 1) {
    return removeDefaultNote(lines.slice(1).join("\n"));
  }

  const prefixedReason = /^(source|reason):\s*/i.exec(firstLine);
  if (prefixedReason) {
    return removeDefaultNote(lines.length > 1
      ? lines.slice(1).join("\n")
      : "");
  }

  if (normalizedType === "OUT" || normalizedType === "ADJUSTMENT") {
    const note = textAfterSeparator(text);
    if (note !== null) {
      const reason = text.slice(0, text.indexOf(" - ")).trim();
      return note === reason ? "" : removeDefaultNote(note);
    }
  }

  return removeDefaultNote(text);
}
