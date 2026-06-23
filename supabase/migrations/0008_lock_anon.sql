-- Harden: the apps authenticate before any data access, so the anon role
-- needs none. Even if the publishable key is extracted from a shipped APK, an
-- unauthenticated caller can read nothing; authenticated users remain gated by
-- RLS. Auth/sign-up endpoints (GoTrue) are unaffected by these grants.
revoke select on all tables in schema public from anon;
revoke select on public.profiles_public from anon;
revoke execute on all functions in schema public from anon;
