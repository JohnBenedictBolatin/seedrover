import assert from "node:assert/strict";
import test from "node:test";
import { inventoryTransactionNote } from "./inventory-remarks.mjs";

test("opening and historical batches do not display system labels as farmer notes", () => {
  assert.equal(inventoryTransactionNote({ type: "OPENING", source: "batch", remarks: "Opening stock" }), "");
  assert.equal(inventoryTransactionNote({ type: "HISTORICAL", source: "batch", remarks: "Existing stock; receipt history unavailable" }), "");
});

test("manual receipts show the entered note without the source or default text", () => {
  assert.equal(inventoryTransactionNote({ type: "IN", source: "manual", remarks: "Greenhouse Sorting\nInventory updated." }), "");
  assert.equal(inventoryTransactionNote({ type: "IN", source: "manual", remarks: "Source: Greenhouse Sorting\nCounted and weighed at receiving." }), "Counted and weighed at receiving.");
});

test("manual issues and adjustments extract notes after their reason", () => {
  assert.equal(inventoryTransactionNote({ type: "OUT", source: "manual", remarks: "Staff Allocation - Inventory updated." }), "");
  assert.equal(inventoryTransactionNote({ type: "OUT", source: "manual", remarks: "Staff Allocation - For the morning market." }), "For the morning market.");
  assert.equal(inventoryTransactionNote({ type: "ADJUSTMENT", source: "manual", remarks: "Spoilage - Removed damaged produce." }), "Removed damaged produce.");
});

test("sales are not presented as farmer-entered movement notes", () => {
  assert.equal(inventoryTransactionNote({ type: "OUT", source: "sale", remarks: "Sale recorded: PHP 250.00" }), "");
});
