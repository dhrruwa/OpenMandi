-- ============================================================
-- OpenMandi — PRODUCTION HARDENING. Run this MANUALLY when you go live.
-- It is intentionally NOT in migrations/ so it never auto-applies during
-- demo/testing. It removes the two demo backdoors. After running it, sign-up
-- requires real email confirmation and KYC must be done by a real provider.
--
-- Run:  supabase db execute --file supabase/production_hardening.sql
--   (or paste into the SQL Editor)
-- ============================================================

-- 1) Remove the email auto-confirm backdoor → real email verification applies.
drop trigger if exists trg_auto_confirm on auth.users;
drop function if exists public.auto_confirm_email();

-- 2) Remove the self-serve KYC backdoor → only the server (service role) or an
--    admin may set kyc_status, after a real Aadhaar/GST check.
drop function if exists public.dev_autoverify_kyc();

-- 3) Delete the demo accounts (well-known credentials — a backdoor in prod).
--    Cascades to public.users via the FK.
delete from auth.users
 where email in ('demo_farmer@example.com', 'demo_dealer@example.com');

-- 4) (Optional) seed an admin so KYC/disputes can be moderated:
--    update public.users set role = 'admin' where email = 'you@yourco.com';

-- NOTE: client RPC / internal-function EXECUTE grants are already locked down
-- by migrations/0014_security_hardening.sql (applied automatically).

-- ── After running this, also do these in the dashboard / server ──
-- • ROTATE every credential that was ever shared in chat/logs:
--     - Settings → Database → Reset password (DB password).
--     - Settings → API → roll the publishable AND secret keys, then update
--       mobile/openmandi.env.json (publishable) and the server .env (secret).
-- • Build the apps with --dart-define REQUIRE_LOGIN=true so the demo
--   auto-login is disabled and real auth is enforced.
-- • Authentication → Providers → Email → turn "Confirm email" ON.
-- • Authentication → Attack Protection → enable CAPTCHA (Turnstile) +
--   leaked-password protection; raise minimum password length.
-- • Deploy the server/ service over TLS; set SUPABASE_SECRET_KEY,
--   RAZORPAY_*, KYC_*, DATA_ENC_KEY and CORS_ORIGINS there (never in the apps).
-- • Wire the real KYC provider so /kyc/aadhaar/verify sets kyc_status.
