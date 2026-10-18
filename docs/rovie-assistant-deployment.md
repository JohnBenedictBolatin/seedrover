# Rovie assistant deployment

Rovie's web and mobile clients call the same authenticated `assistant` Edge
Function. The function builds operational context from caller-scoped reads and
ignores client-supplied `context` fields.

## Release order

1. Review and apply `20261023100000_assistant_rate_limit_rpc.sql` to the target
database. It adds a service-role-only atomic counter using the existing
`rate_limit_buckets` table.
2. Configure the Edge Function secrets `GEMINI_API_KEY` and, optionally,
`GEMINI_MODEL`. Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` to Edge Functions. Never put these values in a
client environment file or log output.
3. Deploy the updated `assistant` function with JWT verification enabled.
4. Release the web and mobile clients. Both show readable error states and
retry the existing question without adding another chat turn.

Do not reconcile target migration history by marking older migrations reverted.
Compare the canonical root migrations with the target first. The known remote
migration-history mismatch must be resolved before applying this forward
migration to production.

## Expected responses

Successful replies retain the `answer` field and include `status` and a request
reference. Failures include a safe `code`, `retryable`, and request reference;
provider messages, tokens, question text, and farm records are not returned in
diagnostics. Provider failures after a permitted lookup may return a short
answer built from those verified records.

Verify the reported follow-up with an authorized inventory user: ask "my recent
sales", then "banana", then "last week". Confirm the personal-sales scope,
Manila date range, and returned item quantities against that account's
completed sales. Also verify a planting-only account receives a permission
message for sales and can still ask for crop or rover information it may view.
