# Single active account session

SeedRover uses Supabase Auth for both the mobile app and the Vercel web admin.
Supabase allows multiple active sessions per account by default. To limit an
account to its most recently signed-in device, enable **Single session per user**
in the Supabase project's **Authentication → Sessions** settings.

This is a Supabase project setting; changing Vercel or the application code alone
does not enforce a single session. Supabase currently makes this setting
available on Pro plans and above.

After it is enabled, the most recently signed-in session remains active. Existing
sessions are ended when they next refresh their access token, so the previous
device may remain usable until its current access token expires. The app then
shows a sign-in message explaining that the session ended, including when this
happens in the mobile app.

This policy intentionally treats the latest sign-in as authoritative. Users who
need simultaneous use on multiple devices should use separate accounts.
