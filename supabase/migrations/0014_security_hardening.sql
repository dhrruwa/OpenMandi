-- Security hardening: internal SECURITY DEFINER helpers must not be callable
-- directly by clients (they run inside other definer functions as the owner,
-- so revoking client EXECUTE does not break internal calls).
--
-- Before: dev_autoverify_kyc / notify / audit / recalc_user_rating were
-- EXECUTE-able by PUBLIC + authenticated → any logged-in user could
-- self-verify KYC or write notifications/audit rows for arbitrary users.
revoke execute on function public.dev_autoverify_kyc() from public, anon, authenticated;
revoke execute on function public.notify(uuid, notif_type, text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.audit(text, text, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.recalc_user_rating() from public, anon, authenticated;

-- Client RPCs: authenticated only (drop the blanket PUBLIC/anon grant; the
-- in-function auth.uid() checks already reject anon, this is defence in depth).
revoke execute on function public.make_offer(uuid, integer, numeric) from public, anon;
revoke execute on function public.accept_offer(uuid) from public, anon;
revoke execute on function public.advance_order(uuid) from public, anon;
revoke execute on function public.complete_order(uuid) from public, anon;
revoke execute on function public.counter_offer(uuid, integer, numeric) from public, anon;
revoke execute on function public.respond_to_requirement(uuid) from public, anon;
