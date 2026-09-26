# Web action feedback coverage

Use this checklist when changing a consequential web action. Each mutation must
report only after the server confirms the result. Errors remain dismissible and
must not be styled as success.

| Area and entry point | Confirmation | Success message |
| --- | --- | --- |
| Inventory create/edit | Yes for opening stock, quantity, unit, unit cost, or selling price changes; routine details save directly. | “Inventory item added/updated.” |
| Inventory stock in/out | Yes, with item, quantity, unit, and reason. | “Stock quantity added/deducted.” |
| Inventory delete | Yes, danger tone. | “Inventory item deleted.” |
| Sales receipt | Yes, with total and stock deduction summary. | “Receipt {receipt number} recorded.” |
| Sale void | Yes, with receipt, stock restoration, and editable reason. | “Sale voided and inventory restored.” |
| Discount release | Yes, with recipient and discount code. | “Discount {code} released.” |
| Installment payment | Yes, with customer, period, amount, and payment method. | “Installment payment recorded.” |
| Crop edit | No. The updated crop details are shown after save. | None for a routine edit; failures remain actionable. |
| Crop care and harvest/cancellation | No extra confirmation before recording routine care; harvest/cancellation requires confirmation. | Keep action-specific feedback for recorded care and harvest/cancellation outcomes. |
| Crop harvest/cancellation | Yes, with batch, weight/destination or cancellation reason. | Harvest receipt plus “{weight} kg harvested from {batch} and added to {destination} inventory.”; cancellation states no inventory was added. |
| Farm cost create/delete | Yes. | “Farm cost saved/removed.” |
| User create | Yes. | Server result; failures use error tone. |
| User role/status change | Yes. Name-only edits save directly. | No generic profile-update toast; the updated row is the confirmation. |
| Notification read/unread | No. | No success toast; the read state updates in place. |
| Notification delete | Yes, danger tone. | “Notification deleted.” |
| Sign in/out | Sign out only. | No success notice after redirect. Sign-out failures remain visible. |
| Password reset/update | Confirm password replacement only. | Show the result inline; errors remain actionable. |
| Sales/customer export | No. Preserve filters and export filename. | No success toast after download starts; show actionable download errors. |
| Report/receipt print | No. | No success toast when the browser print dialog opens; keep print/load errors. |

Shared notifications appear at the lower right and use sentence case. Success
and informational notices dismiss after five seconds and have no close button;
warning and error notices remain dismissible. Shared confirmation dialogs use a
clear action title, consequence text, Cancel, and an explicit action label.
Preserve user-entered form data when a confirmation is cancelled or a server
action fails.
