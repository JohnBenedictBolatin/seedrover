"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition, type FormEvent } from "react";
import { reverseInstallmentPaymentAction } from "@/app/(portal)/customers/payments-actions";
import { useActionFeedback } from "@/components/action-feedback";
import styles from "@/app/(portal)/sales/[id]/page.module.css";

export function InstallmentPaymentReceiptActions({
  paymentId,
  saleId,
  canReverse,
  reversed,
}: {
  paymentId: string;
  saleId: string;
  canReverse: boolean;
  reversed: boolean;
}) {
  const [reason, setReason] = useState("");
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const { notify } = useActionFeedback();

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      try {
        const result = await reverseInstallmentPaymentAction(formData);
        setReason("");
        router.refresh();
        notify({ tone: "success", text: `Payment reversed (${result.reversal_id}).` });
      } catch (error) {
        notify({ tone: "error", text: error instanceof Error ? error.message : "Unable to reverse the payment." });
      }
    });
  }

  if (!canReverse || reversed) return null;
  return (
    <form className={styles.remarks} onSubmit={handleSubmit}>
      <label htmlFor="payment-reversal-reason">Reverse this payment</label>
      <input name="collection_id" type="hidden" value={paymentId} />
      <input name="sales_order_id" type="hidden" value={saleId} />
      <textarea id="payment-reversal-reason" name="reason" minLength={3} required rows={3} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Explain why this collection needs to be reversed" />
      <button disabled={pending} type="submit">{pending ? "Reversing…" : "Reverse payment"}</button>
    </form>
  );
}
