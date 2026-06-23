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
  data). The **service-role key** lives only in the Express server.
- A safe `profiles_public` view exposes only name + rating for marketplace
  display; the `users` table (phone/email/location) is never world-readable.

## Payments & escrow
- Razorpay order amounts are read from `orders.total_amount` (server-computed),
  never trusted from the client.
- Webhook signatures are verified with a constant-time HMAC compare.
- Escrow transitions (`held → released / refunded`) are **service-role only**
  (no client RLS write policy on `payments`) and are audit-logged.

## File security
- `listing-photos`: public read, owner-scoped writes (`<uid>/...`), MIME + size
  limited.
- `kyc-docs`: **private** bucket. Never public. Accessed only via short-lived
  signed URLs; rows readable by owner or admin.

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
- **helmet** security headers; strict **CORS allowlist**; HTTPS/TLS + HSTS in
  production.
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
- **anon role is locked out of all data** (migration `0008_lock_anon.sql`): an
  extracted publishable key reads nothing without authenticating; RLS gates
  authenticated users. Auth/sign-up is unaffected.

## Go-live: one script + dashboard toggles
- Run `supabase/production_hardening.sql` to remove the two demo backdoors
  (email auto-confirm trigger + `dev_autoverify_kyc`).
- Dashboard (cannot be scripted): re-enable **Confirm email**; enable **Attack
  Protection** (CAPTCHA + leaked-password); raise min password length; **rotate
  the DB password**. Deploy `server/` over TLS with the secret keys.

## Demo vs production
- `dev_autoverify_kyc()` (RPC) auto-verifies KYC for the **demo only** so the
  marketplace loop is walkable without provider keys. In production this is
  removed and replaced by the real provider response via the Express service
  (`/kyc/aadhaar/verify`, service role).
