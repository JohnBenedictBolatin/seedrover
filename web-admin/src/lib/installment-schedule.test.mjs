import assert from "node:assert/strict";
import test from "node:test";
import { futureInstallmentAmounts } from "./installment-schedule.mjs";

test("counts the initial payment as payment one and divides the balance exactly", () => {
  const future = futureInstallmentAmounts(10_000, 2_000, 4);
  assert.deepEqual(future, [2666.67, 2666.67, 2666.66]);
  assert.equal(future.reduce((sum, amount) => sum + amount, 2_000), 10_000);
});

test("assigns extra cents to the earliest future payments", () => {
  assert.deepEqual(futureInstallmentAmounts(100, 1, 4), [33, 33, 33]);
  assert.deepEqual(futureInstallmentAmounts(100, 1.01, 4), [33, 33, 32.99]);
});

test("requires a positive initial payment and 2 to 120 total payments", () => {
  assert.throws(() => futureInstallmentAmounts(100, 0, 4), /Initial payment/);
  assert.throws(() => futureInstallmentAmounts(100, 100, 4), /Initial payment/);
  assert.throws(() => futureInstallmentAmounts(100, 10, 1), /between 2 and 120/);
  assert.throws(() => futureInstallmentAmounts(100, 10, 121), /between 2 and 120/);
  assert.throws(() => futureInstallmentAmounts(1, 0.99, 3), /too many payments/);
});
