-- ============================================================
-- OpenMandi — Row Level Security. Default-deny on every table;
-- explicit policies grant the minimum. service_role bypasses RLS
-- (server only); SECURITY DEFINER functions bypass it intentionally.
-- ============================================================

-- ---------- guard triggers (column-level protection RLS can't do) ----------

-- users: a normal user may edit their profile but NOT escalate role,
-- flip kyc_status, or self-verify email/phone. Only admins/service can.
create or replace function public.guard_users_update()
returns trigger language plpgsql as $$
begin
  -- only restrict authenticated end-users; server/trigger context (uid null),
  -- admins, and SECURITY DEFINER RPCs (bypass flag) may set protected fields.
  if auth.uid() is not null and not public.is_admin()
     and coalesce(current_setting('app.bypass_guard', true), '') <> 'on' then
    if new.role <> old.role
       or new.kyc_status <> old.kyc_status
       or new.email_verified <> old.email_verified
       or new.phone_verified <> old.phone_verified
       or new.avg_rating <> old.avg_rating
       or new.rating_count <> old.rating_count then
      raise exception 'not allowed to modify protected fields';
    end if;
  end if;
  return new;
end $$;
create trigger trg_guard_users before update on public.users
  for each row execute function public.guard_users_update();

-- profiles: verification booleans + provider tokens are server/admin-only.
create or replace function public.guard_farmer_profile()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'UPDATE') and auth.uid() is not null and not public.is_admin() then
    if new.aadhaar_verified <> old.aadhaar_verified
       or new.pan_verified <> old.pan_verified
       or coalesce(new.aadhaar_ref_token,'') <> coalesce(old.aadhaar_ref_token,'')
       or coalesce(new.kyc_provider_ref,'') <> coalesce(old.kyc_provider_ref,'') then
      raise exception 'verification fields are server-controlled';
    end if;
  end if;
  return new;
end $$;
create trigger trg_guard_farmer_profile before update on public.farmer_profiles
  for each row execute function public.guard_farmer_profile();

create or replace function public.guard_dealer_profile()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'UPDATE') and auth.uid() is not null and not public.is_admin() then
    if new.aadhaar_verified <> old.aadhaar_verified
       or new.gst_verified <> old.gst_verified then
      raise exception 'verification fields are server-controlled';
    end if;
  end if;
  return new;
end $$;
create trigger trg_guard_dealer_profile before update on public.dealer_profiles
  for each row execute function public.guard_dealer_profile();

-- orders: total is ALWAYS recomputed server-side; client value is ignored.
create or replace function public.compute_order_total()
returns trigger language plpgsql as $$
declare q numeric;
begin
  q := case new.unit
         when 'kg' then new.quantity / 100.0
         when 'quintal' then new.quantity
         when 'ton' then new.quantity * 10.0
       end;
  new.total_amount := round(new.final_price * q);
  return new;
end $$;
create trigger trg_orders_total before insert or update on public.orders
  for each row execute function public.compute_order_total();

-- ---------- enable RLS ----------
alter table public.users            enable row level security;
alter table public.farmer_profiles  enable row level security;
alter table public.dealer_profiles  enable row level security;
alter table public.crops            enable row level security;
alter table public.listings         enable row level security;
alter table public.buy_requests     enable row level security;
alter table public.threads          enable row level security;
alter table public.offers           enable row level security;
alter table public.messages         enable row level security;
alter table public.orders           enable row level security;
alter table public.payments         enable row level security;
alter table public.reviews          enable row level security;
alter table public.disputes         enable row level security;
alter table public.price_records    enable row level security;
alter table public.saved_searches   enable row level security;
alter table public.notifications    enable row level security;
alter table public.audit_logs       enable row level security;

-- ---------- users ----------
create policy users_select_self on public.users for select
  using (id = auth.uid() or public.is_admin());
create policy users_update_self on public.users for update
  using (id = auth.uid()) with check (id = auth.uid());

-- safe, world-readable projection for marketplace display (name + rating only)
create view public.profiles_public
  with (security_invoker = false) as
  select id, full_name, role, avg_rating, rating_count, kyc_status,
         (kyc_status = 'verified') as verified
  from public.users;
grant select on public.profiles_public to anon, authenticated;

-- ---------- profiles ----------
create policy farmer_profile_rw on public.farmer_profiles for all
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());
create policy dealer_profile_rw on public.dealer_profiles for all
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());

-- ---------- crops (master data) ----------
create policy crops_read on public.crops for select using (true);
create policy crops_admin_write on public.crops for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- listings ----------
create policy listings_read on public.listings for select
  using (status <> 'withdrawn' or farmer_id = auth.uid() or public.is_admin());
create policy listings_insert on public.listings for insert
  with check (farmer_id = auth.uid() and public.is_kyc_verified());
create policy listings_update on public.listings for update
  using (farmer_id = auth.uid() or public.is_admin())
  with check (farmer_id = auth.uid() or public.is_admin());
create policy listings_delete on public.listings for delete
  using (farmer_id = auth.uid() or public.is_admin());

-- ---------- buy_requests ----------
create policy buyreq_read on public.buy_requests for select using (true);
create policy buyreq_insert on public.buy_requests for insert
  with check (dealer_id = auth.uid() and public.is_kyc_verified());
create policy buyreq_update on public.buy_requests for update
  using (dealer_id = auth.uid() or public.is_admin())
  with check (dealer_id = auth.uid() or public.is_admin());
create policy buyreq_delete on public.buy_requests for delete
  using (dealer_id = auth.uid() or public.is_admin());

-- ---------- threads ----------
create policy threads_select on public.threads for select
  using (farmer_id = auth.uid() or dealer_id = auth.uid() or public.is_admin());
create policy threads_insert on public.threads for insert
  with check (auth.uid() in (farmer_id, dealer_id));
create policy threads_update on public.threads for update
  using (auth.uid() in (farmer_id, dealer_id));

-- ---------- offers (must be a thread participant) ----------
create policy offers_select on public.offers for select
  using (exists (select 1 from public.threads t
                 where t.id = thread_id
                 and (t.farmer_id = auth.uid() or t.dealer_id = auth.uid() or public.is_admin())));
create policy offers_insert on public.offers for insert
  with check (from_user = auth.uid()
              and exists (select 1 from public.threads t
                          where t.id = thread_id and auth.uid() in (t.farmer_id, t.dealer_id)));
create policy offers_update on public.offers for update
  using (exists (select 1 from public.threads t
                 where t.id = thread_id and auth.uid() in (t.farmer_id, t.dealer_id)));

-- ---------- messages ----------
create policy messages_select on public.messages for select
  using (exists (select 1 from public.threads t
                 where t.id = thread_id
                 and (t.farmer_id = auth.uid() or t.dealer_id = auth.uid() or public.is_admin())));
create policy messages_insert on public.messages for insert
  with check (sender_id = auth.uid()
              and exists (select 1 from public.threads t
                          where t.id = thread_id and auth.uid() in (t.farmer_id, t.dealer_id)));

-- ---------- orders ----------
create policy orders_select on public.orders for select
  using (farmer_id = auth.uid() or dealer_id = auth.uid() or public.is_admin());
create policy orders_insert on public.orders for insert
  with check (auth.uid() in (farmer_id, dealer_id) and public.is_kyc_verified());
create policy orders_update on public.orders for update
  using (auth.uid() in (farmer_id, dealer_id) or public.is_admin())
  with check (auth.uid() in (farmer_id, dealer_id) or public.is_admin());

-- ---------- payments (escrow): readable by participants, written by server only ----------
create policy payments_select on public.payments for select
  using (exists (select 1 from public.orders o
                 where o.id = order_id
                 and (o.farmer_id = auth.uid() or o.dealer_id = auth.uid() or public.is_admin())));
-- no insert/update policy → only service_role (Express) may write escrow rows.

-- ---------- reviews ----------
create policy reviews_read on public.reviews for select using (true);
create policy reviews_insert on public.reviews for insert
  with check (from_user = auth.uid());   -- trigger enforces order completed

-- ---------- disputes ----------
create policy disputes_select on public.disputes for select
  using (public.is_admin()
         or exists (select 1 from public.orders o
                    where o.id = order_id and auth.uid() in (o.farmer_id, o.dealer_id)));
create policy disputes_insert on public.disputes for insert
  with check (raised_by = auth.uid()
              and exists (select 1 from public.orders o
                          where o.id = order_id and auth.uid() in (o.farmer_id, o.dealer_id)));
create policy disputes_admin_update on public.disputes for update
  using (public.is_admin()) with check (public.is_admin());

-- ---------- price_records (read-all, server-written) ----------
create policy prices_read on public.price_records for select using (true);

-- ---------- saved_searches ----------
create policy saved_rw on public.saved_searches for all
  using (dealer_id = auth.uid()) with check (dealer_id = auth.uid());

-- ---------- notifications (read/ack own; created by server/triggers) ----------
create policy notif_select on public.notifications for select
  using (user_id = auth.uid());
create policy notif_update on public.notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- audit_logs: admin read only; written by server/definer ----------
create policy audit_admin_read on public.audit_logs for select
  using (public.is_admin());

-- ---------- grants (RLS still gates rows; these expose tables to PostgREST) ----------
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to anon, authenticated;
