import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import {
  isContactNumber,
  normalizeContactNumber,
  sanitizeContactDraft,
} from "./contact-number.mjs";
import { parseDatabaseDecimal } from "./field-validation.mjs";

test("accepts and normalizes local and Philippine international numbers", () => {
  assert.equal(normalizeContactNumber("09171234567", { required: true }), "09171234567");
  assert.equal(normalizeContactNumber("0917 123 4567", { required: true }), "09171234567");
  assert.equal(normalizeContactNumber("+639171234567", { required: true }), "09171234567");
  assert.equal(normalizeContactNumber("639171234567", { required: true }), "09171234567");
});

test("rejects letters, wrong lengths, and optional blanks when required", () => {
  for (const value of ["0917ABC4567", "091712345678", "0917123456"]) {
    assert.throws(() => normalizeContactNumber(value, { required: true }));
    assert.equal(isContactNumber(value), false);
  }
  assert.throws(() => normalizeContactNumber("", { required: true }));
});

test("preserves optional blank and legacy sentinel behavior", () => {
  assert.equal(normalizeContactNumber(""), null);
  assert.throws(() => normalizeContactNumber("Not provided"));
  assert.equal(normalizeContactNumber("Not provided", { allowLegacy: true }), "Not provided");
  assert.equal(normalizeContactNumber("  not provided ", { allowLegacy: true }), "Not provided");
});

test("sanitizes drafts to digits and the local eleven-digit limit", () => {
  assert.equal(sanitizeContactDraft("09a17-123-456789"), "09171234567");
  assert.equal(sanitizeContactDraft("+639171234567"), "09171234567");
});

test("database migration preserves optional and legacy values and normalizes +63", async () => {
  const migration = await readFile(
    resolve(process.cwd(), "../supabase/migrations/20261001100000_contact_number_guards.sql"),
    "utf8",
  );
  assert.match(migration, /if trimmed_value = '' then\s+return null;/i);
  assert.match(migration, /lower\(trimmed_value\) = 'not provided'/i);
  assert.match(migration, /return '0' \|\| substring\(digits from 3\)/i);
  assert.match(migration, /new_value is not distinct from old_value/i);
  assert.match(migration, /contact_number_guard_sales_orders[\s\S]*?'required'/i);
});

test("database numeric parser accepts whole and decimal values within numeric(12,2)", () => {
  assert.equal(parseDatabaseDecimal("15", "Value"), 15);
  assert.equal(parseDatabaseDecimal("15.25", "Value"), 15.25);
  assert.equal(parseDatabaseDecimal("9999999999.99", "Value"), 9999999999.99);
  for (const value of ["", "1e3", "0x20", "10000000000", "1.234"]) {
    assert.throws(() => parseDatabaseDecimal(value, "Value"));
  }
});

test("customer link migration canonicalizes existing +63 customer identities", async () => {
  const migration = await readFile(
    resolve(process.cwd(), "../supabase/migrations/20261002100000_link_normalized_sale_customers.sql"),
    "utf8",
  );
  assert.match(migration, /create or replace function public\.canonical_customer_contact/i);
  assert.match(migration, /public\.canonical_customer_contact\(c\.contact_number\)[\s\S]*public\.canonical_customer_contact\(new\.customer_contact\)/i);
  assert.match(migration, /create or replace function public\.link_sales_order_customer/i);
});
