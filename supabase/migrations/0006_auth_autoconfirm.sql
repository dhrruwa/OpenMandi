-- ============================================================
-- Auto-confirm email on signup at the DB level, so password sign-in works
-- without the GoTrue "Confirm email" dashboard toggle (no OTP email needed).
-- For production with real email verification, drop this trigger and turn
-- "Confirm email" back on in Authentication settings.
-- ============================================================

create or replace function public.auto_confirm_email()
returns trigger language plpgsql security definer as $$
begin
  if new.email_confirmed_at is null then
    new.email_confirmed_at := now();
  end if;
  return new;
end $$;

drop trigger if exists trg_auto_confirm on auth.users;
create trigger trg_auto_confirm before insert on auth.users
  for each row execute function public.auto_confirm_email();
