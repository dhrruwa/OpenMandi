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

-- 3) (Optional) seed an admin so KYC/disputes can be moderated:
--    update public.users set role = 'admin' where email = 'you@yourco.com';

-- ── After running this, also do these in the dashboard / server ──
-- • Authentication → Providers → Email → turn "Confirm email" ON.
-- • Authentication → Attack Protection → enable CAPTCHA (Turnstile) +
--   leaked-password protection; raise minimum password length.
-- • Deploy the server/ service over TLS; set SUPABASE_SERVICE_ROLE_KEY,
--   RAZORPAY_*, KYC_*, and DATA_ENC_KEY there (never in the apps).
-- • Wire the real KYC provider so /kyc/aadhaar/verify sets kyc_status.
-- • Rotate the database password (Settings → Database → Reset password).
