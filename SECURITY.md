# OpenMandi — Security & Compliance

Security is a first-class requirement. This documents the controls in place and
the Aadhaar / DPDP compliance approach.

## Authentication
- Supabase Auth: email OTP (Phase 1) + optional phone OTP. Short-lived access
  tokens with refresh rotation; PKCE flow on the clients.
- A transaction requires a **verified** account (`users.kyc_status = 'verified'`),
  enforced in RLS (`is_kyc_verified()` on listing/order/buy-request inserts).
- OTP delivery & throttling are handled by Supabase Auth (rate limits, single-use,
  short expiry). The custom `otp_codes` table pattern (hashed, single-use, 10-min
  expiry, lockout) is reserved for any server-issued OTPs.

## Access control — Row Level Security
- **RLS is enabled on every table** (`0002_rls.sql`); default-deny, explicit
  least-privilege policies. Users read/write only their own rows; thread/offer/
  message/order access is restricted to participants; admins via `is_admin()`.
- **Reviews** are insertable only when the related `orders.status = 'completed'`
  (enforced by both a trigger and RLS).
- **Privilege-escalation guards** (triggers): users cannot change their own
  `role`, `kyc_status`, `email_verified`, or rating; KYC verification booleans and
  provider tokens are server/admin-only.
- **Order totals are recomputed server-side** on every insert/update — client
  amounts are ignored.
- The **anon/publishable key** is the only key in the apps (safe; RLS protects
  data). The **service-role / secret key** lives only in the server `.env`.
- A safe `profiles_public` view exposes only name + rating for marketplace
  display; the `users` table (phone/email/location) is never world-readable.
- **Function EXECUTE grants are least-privilege** (`0014_security_hardening.sql`):
  internal `SECURITY DEFINER` helpers (`notify`, `audit`, `recalc_user_rating`,
  `dev_autoverify_kyc`) are **not** callable by clients (server/admin only) —
  they still run inside other definer functions as the owner. The trade RPCs
  (`make_offer`, `accept_offer`, `counter_offer`, `respond_to_requirement`,
  order lifecycle) are granted to **authenticated** only (no `anon`/`PUBLIC`),
  with `auth.uid()` ownership checks inside each.

## Payments & escrow
- Razorpay order amounts are read from `orders.total_amount` (server-computed),
  never trusted from the client.
- Webhook signatures are verified with a constant-time HMAC compare.
- Escrow transitions (`held → released / refunded`) are **service-role only**
  (no client RLS write policy on `payments`) and are audit-logged.

## File security
- `listing-photos`: public read, owner-scoped writes (`<uid>/...`), MIME + size
  limited. (Listing photos are intentionally public marketplace content.)
- `kyc-docs`: **private** bucket. Never public. Accessed only via short-lived
  signed URLs; rows readable by owner or admin.
- `chat-voice`: currently a **public** bucket (demo). **Hardening TODO** before
  production: make it private and serve voice notes via short-lived signed URLs
  (or a participant-scoped SELECT policy) so conversations aren't URL-readable.

## Sensitive data / Aadhaar — compliance-critical
- We **do not call UIDAI directly**. KYC goes through a UIDAI-licensed provider /
  AUA-KUA aggregator (Setu, Cashfree, Sandbox.co.in, Signzy, IDfy, Digio) or
  DigiLocker, abstracted behind `KycProvider` (`server/src/providers/kyc.ts`).
- We **never store the full Aadhaar or PAN** — only the last 4 digits (masked
  display) + the provider's verification reference token + a `verified` boolean.
- Bank details are stored as **server-encrypted ciphertext** (`bank_account_enc`);
  app-level/KMS encryption keyed by `DATA_ENC_KEY`. Aadhaar/PAN/bank/OTP values
  are never logged.
- Explicit **consent** is captured (`consent_at`) before KYC.
- DPDP Act 2023 + Aadhaar Act: data minimization, purpose limitation, right to
  deletion (cascade on user delete), and a published privacy policy.

## Application security
- Input validation with **zod** on every endpoint; parameterized access via the
  Supabase client (no string-built SQL).
- **helmet** security headers; **CORS allowlist** enforced on the server
  (`CORS_ORIGINS` env — no wildcard; defaults to localhost dev only); HTTPS/TLS
  + HSTS in production.
- **Rate limiting** globally and tighter on `/kyc` (and auth/OTP via Supabase).
- IDOR prevented by always checking ownership server-side (RLS + explicit checks),
  never trusting client-supplied IDs.

## Operations
- Secrets only in env / secret manager (`.env` git-ignored; `.env.example`
  documents the shape). Least-privilege keys.
- **Audit logging** of sensitive actions (KYC, payments, escrow, disputes, admin,
  role changes) in `audit_logs`, admin-readable only.
- Dependency/vulnerability scanning belongs in CI (`npm audit`, Dart `pub`).

## Hardening applied
- **anon role is locked out of all data** (`0008_lock_anon.sql`): an extracted
  publishable key reads nothing without authenticating; RLS gates authenticated
  users. Auth/sign-up is unaffected.
- **Least-privilege function grants** (`0014_security_hardening.sql`): client-
  callable internal helpers and the KYC-bypass RPC are revoked from `PUBLIC`/
  `anon`/`authenticated` (see Access control above).
- **Secrets are git-ignored**: `.env*`, `openmandi.env.json`, `*.jks`,
  `key.properties`, keystores/certs (`.gitignore`). The repo holds no live keys.

## Auth (current dev state)
- `REQUIRE_LOGIN` defaults to **false** so a demo account auto-logs-in (no login
  wall) during development. This is **not** production-safe — build with
  `--dart-define REQUIRE_LOGIN=true` to enforce real auth before release.

## Go-live: one script + dashboard toggles
- Run `supabase/production_hardening.sql`: removes the demo backdoors (email
  auto-confirm trigger, `dev_autoverify_kyc`) **and the demo accounts**.
- **Rotate every credential that was ever shared in chat/logs**: Settings →
  Database → reset password; Settings → API → roll the **publishable + secret**
  keys, then update `openmandi.env.json` (publishable) and the server `.env`
  (secret).
- Build the apps with `REQUIRE_LOGIN=true`.
- Make the `chat-voice` bucket private + signed URLs (File security TODO above).
- Dashboard (cannot be scripted): re-enable **Confirm email**; enable **Attack
  Protection** (CAPTCHA + leaked-password); raise min password length. Deploy
  `server/` over TLS with `CORS_ORIGINS` + secret keys set.

## Demo vs production
- `dev_autoverify_kyc()` (RPC) auto-verifies KYC for the **demo only** so the
  marketplace loop is walkable without provider keys. In production this is
  removed and replaced by the real provider response via the Express service
  (`/kyc/aadhaar/verify`, service role).
