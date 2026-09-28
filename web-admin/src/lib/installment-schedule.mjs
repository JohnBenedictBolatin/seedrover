/**
 * Splits the balance after the initial collection into the remaining periods.
 * Any leftover centavos are assigned to the earliest periods.
 * @param {number} saleTotal
 * @param {number} initialPayment
 * @param {number} totalPayments
 * @returns {number[]}
 */
export function futureInstallmentAmounts(saleTotal, initialPayment, totalPayments) {
  if (!Number.isFinite(saleTotal) || saleTotal <= 0) {
    throw new RangeError("Sale total must be greater than zero.");
  }
  if (!Number.isFinite(initialPayment) || initialPayment <= 0 || initialPayment >= saleTotal) {
    throw new RangeError("Initial payment must be greater than zero and below the sale total.");
  }
  if (!Number.isInteger(totalPayments) || totalPayments < 2 || totalPayments > 120) {
    throw new RangeError("Total payments must be between 2 and 120.");
  }

  const balanceCents = Math.round((saleTotal - initialPayment) * 100);
  const futureCount = totalPayments - 1;
  if (futureCount > balanceCents) {
    throw new RangeError("There are too many payments for the remaining balance.");
  }
  const baseCents = Math.floor(balanceCents / futureCount);
  const extraCents = balanceCents % futureCount;
  return Array.from({ length: futureCount }, (_, index) =>
    (baseCents + (index < extraCents ? 1 : 0)) / 100,
  );
}
