# Shared workflow parity checklist

The canonical labels, field rules, option lists, and intentional differences are in `contracts/shared-workflows.json`.

| Workflow | Required parity |
|---|---|
| Crop care | Date/time, notes, activity inputs, observation choice, transplant destination, growth stage, photo limits, harvest/closure review. |
| Inventory item | Name, category, quantity/unit, minimum, costs/prices, location, photo, persisted item notes. |
| Inventory movement | Receive/issue labels, identical source/reason options, required explicit choice, remarks, before/after balances. |
| Ordinary sale | One item, quantity, price/total, customer structured name/contact, payment/reference rules, timestamp, notes. |
| User account | Structured names, username, email/contact, role, active state, generated/custom temporary credential result. |
| Shared status/feedback | Readable equivalent statuses, validation meaning, action labels, confirmations, and new activity messages. |

| Cross-platform difference | Classification |
|---|---|
| Web keep-signed-in / mobile remember-username | Intentional; labels describe distinct behavior. |
| Web multi-item orders, discounts, installments | Intentional web-only capability. |
| Web Rover monitoring / mobile Rover control | Intentional platform capability difference. |
| Web automatic sale time / mobile selected sale date and time | Intentional; shown explicitly in summaries and history. |
| Legacy anonymous sales and unsplit user names | Preserved historical data, not a new-entry parity exception. |

Update this checklist whenever shared workflows change. `node scripts/generate_shared_workflows.mjs --check` verifies generated platform constants match the contract.
