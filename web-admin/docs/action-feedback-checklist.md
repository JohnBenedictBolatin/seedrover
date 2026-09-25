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
| Crop edit and routine care | No. | “Crop record updated.” or an action-specific saved message. |
| Crop harvest/cancellation | Yes, with batch, weight/destination or cancellation reason. | Harvest receipt plus “{weight} kg harvested from {batch} and added to {destination} inventory.”; cancellation states no inventory was added. |
| Farm cost create/delete | Yes. | “Farm cost saved/removed.” |
| User create | Yes. | Server result; failures use error tone. |
| User role/status change | Yes. Name-only edits save directly. | “User profile updated.” |
| Notification read/unread | No. | “Notification marked as read/unread.” |
| Notification delete | Yes, danger tone. | “Notification deleted.” |
| Sign in/out | Sign out only. | One-time “You are signed in/out.” notice after redirect. |
| Password reset/update | Confirm password replacement only. | Generic reset outcome; password update reports success/error. |
| Sales/customer export | No. Preserve filters and export filename. | “Export ready.” or an actionable download error. |
| Report/receipt print | No. | “Print dialog requested.”; report load failures state that printing did not happen. |

Shared notifications appear at the lower right, use sentence case, and dismiss
success/info messages after five seconds. Errors remain until dismissed. Shared
confirmation dialogs use a clear action title, consequence text, Cancel, and an
explicit action label. Preserve user-entered form data when a confirmation is
cancelled or a server action fails.
