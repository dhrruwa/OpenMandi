-- OpenMandi — full backend apply. Paste into Supabase SQL Editor and Run.
-- (migrations 0001-0004 + seed, in order)

-- ============================================================
-- migrations/0001_schema.sql
-- ============================================================
-- ============================================================
-- OpenMandi — schema (tables, enums, indexes, helper fns, triggers)
-- Security: RLS is enabled here and policed in 0002_rls.sql.
-- ============================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid
create extension if not exists "citext";         -- case-insensitive email

-- ---------- enums ----------
create type user_role           as enum ('farmer', 'dealer', 'admin');
create type kyc_status          as enum ('none', 'pending', 'verified', 'rejected');
create type quality_grade       as enum ('A', 'B', 'C');
create type produce_unit        as enum ('kg', 'quintal', 'ton');
create type listing_status      as enum ('live', 'offers', 'sold', 'withdrawn');
create type dealer_type         as enum ('local', 'exporter', 'company');
create type offer_status        as enum ('pending', 'countered', 'accepted', 'declined');
create type order_status        as enum ('offer','counter','accepted','confirmed','in_transit','delivered','completed','cancelled');
create type escrow_status       as enum ('none', 'held', 'released', 'refunded');
create type message_type        as enum ('text', 'image', 'offer', 'system');
create type dispute_status      as enum ('open', 'under_review', 'resolved_release', 'resolved_refund');
create type notif_type          as enum ('offer','order','payout','message','price','system','dispute');

-- ---------- updated_at helper ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ============================================================
-- users (mirrors auth.users; id = auth uid)
-- ============================================================
create table public.users (
  id                 uuid primary key references auth.users(id) on delete cascade,
  role               user_role   not null default 'farmer',
  full_name          text        not null default '',
  phone              text,
  email              citext,
  email_verified     boolean     not null default false,
  phone_verified     boolean     not null default false,
  preferred_language text        not null default 'en',
  lat                double precision,
  lng                double precision,
  kyc_status         kyc_status  not null default 'none',
  avg_rating         numeric(2,1) not null default 0,
  rating_count       int          not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create trigger trg_users_updated before update on public.users
  for each row execute function public.set_updated_at();

-- role lookup that bypasses RLS (SECURITY DEFINER) so policies can call it
-- without recursive RLS evaluation on the users table.
create or replace function public.auth_role()
returns user_role language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.users where id = auth.uid()), false)
$$;

create or replace function public.is_kyc_verified()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select kyc_status = 'verified' from public.users where id = auth.uid()), false)
$$;

-- auto-create the public.users row when an auth user signs up; role/name come
-- from sign-up metadata (raw_user_meta_data).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email, full_name, role, email_verified)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'farmer'),
    new.email_confirmed_at is not null
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- keep email_verified in sync when Supabase confirms the email
create or replace function public.handle_user_confirmed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.email_confirmed_at is not null then
    update public.users set email_verified = true where id = new.id;
  end if;
  return new;
end $$;

create trigger trg_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_confirmed();

-- ============================================================
-- profiles (1:1 with users, role-specific). Sensitive columns hold
-- only masked values + provider tokens, or server-encrypted ciphertext.
-- Full Aadhaar / PAN / raw bank numbers are NEVER stored.
-- ============================================================
create table public.farmer_profiles (
  user_id          uuid primary key references public.users(id) on delete cascade,
  pan_last4        text,
  pan_verified     boolean not null default false,
  aadhaar_last4    text,
  aadhaar_ref_token text,                -- licensed-provider reference, not the number
  aadhaar_verified boolean not null default false,
  kyc_provider_ref text,
  bank_account_enc text,                 -- server-encrypted ciphertext (never plaintext)
  upi_id           text,
  farm_location    text,
  consent_at       timestamptz,          -- explicit KYC consent (DPDP)
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create trigger trg_farmer_profiles_updated before update on public.farmer_profiles
  for each row execute function public.set_updated_at();

create table public.dealer_profiles (
  user_id          uuid primary key references public.users(id) on delete cascade,
  gst_number       text,
  gst_verified     boolean not null default false,
  aadhaar_last4    text,
  aadhaar_ref_token text,
  aadhaar_verified boolean not null default false,
  business_type    dealer_type not null default 'local',
  business_name    text,
  experience_years int not null default 0,
  has_own_transport boolean not null default false,
  consent_at       timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create trigger trg_dealer_profiles_updated before update on public.dealer_profiles
  for each row execute function public.set_updated_at();

-- ============================================================
-- crops (master data; admin-managed, world-readable)
-- ============================================================
create table public.crops (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,
  names_i18n   jsonb not null default '{}'::jsonb,
  emoji        text not null default '🌱',
  category     text,
  default_unit produce_unit not null default 'quintal',
  created_at   timestamptz not null default now()
);

-- ============================================================
-- listings
-- ============================================================
create table public.listings (
  id               uuid primary key default gen_random_uuid(),
  farmer_id        uuid not null references public.users(id) on delete cascade,
  crop_id          uuid not null references public.crops(id),
  quantity         numeric(12,2) not null check (quantity > 0),
  unit             produce_unit not null,
  quality_grade    quality_grade not null,
  is_organic       boolean not null default false,
  harvest_date     date,
  availability_date date,
  expected_price   int not null check (expected_price >= 0),   -- ₹/quintal
  market_price     int not null default 0,
  photos           text[] not null default '{}',
  lat              double precision,
  lng              double precision,
  location_label   text,
  status           listing_status not null default 'live',
  views            int not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_listings_status on public.listings(status);
create index idx_listings_crop on public.listings(crop_id);
create index idx_listings_farmer on public.listings(farmer_id);
create trigger trg_listings_updated before update on public.listings
  for each row execute function public.set_updated_at();

-- ============================================================
-- buy_requests (reverse marketplace)
-- ============================================================
create table public.buy_requests (
  id          uuid primary key default gen_random_uuid(),
  dealer_id   uuid not null references public.users(id) on delete cascade,
  crop_id     uuid not null references public.crops(id),
  quantity    numeric(12,2) not null check (quantity > 0),
  unit        produce_unit not null,
  price_min   int not null check (price_min >= 0),
  price_max   int not null check (price_max >= price_min),
  needed_by   date,
  lat         double precision,
  lng         double precision,
  location_label text,
  status      text not null default 'open',
  responses   int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger trg_buy_requests_updated before update on public.buy_requests
  for each row execute function public.set_updated_at();

-- ============================================================
-- threads + messages + offers (negotiation)
-- ============================================================
create table public.threads (
  id             uuid primary key default gen_random_uuid(),
  listing_id     uuid references public.listings(id) on delete set null,
  buy_request_id uuid references public.buy_requests(id) on delete set null,
  farmer_id      uuid not null references public.users(id) on delete cascade,
  dealer_id      uuid not null references public.users(id) on delete cascade,
  crop_label     text not null default '',
  emoji          text not null default '🌱',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (listing_id, farmer_id, dealer_id)
);
create index idx_threads_farmer on public.threads(farmer_id);
create index idx_threads_dealer on public.threads(dealer_id);
create trigger trg_threads_updated before update on public.threads
  for each row execute function public.set_updated_at();

create table public.offers (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.threads(id) on delete cascade,
  listing_id  uuid references public.listings(id) on delete set null,
  from_user   uuid not null references public.users(id) on delete cascade,
  price       int not null check (price >= 0),
  quantity    numeric(12,2) not null check (quantity > 0),
  unit        produce_unit not null,
  status      offer_status not null default 'pending',
  created_at  timestamptz not null default now()
);
create index idx_offers_thread on public.offers(thread_id);

create table public.messages (
  id             uuid primary key default gen_random_uuid(),
  thread_id      uuid not null references public.threads(id) on delete cascade,
  sender_id      uuid not null references public.users(id) on delete cascade,
  type           message_type not null default 'text',
  body           text,
  attachment_url text,
  offer_id       uuid references public.offers(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index idx_messages_thread on public.messages(thread_id, created_at);

-- ============================================================
-- orders + payments
-- ============================================================
create table public.orders (
  id               uuid primary key default gen_random_uuid(),
  listing_id       uuid references public.listings(id) on delete set null,
  farmer_id        uuid not null references public.users(id) on delete cascade,
  dealer_id        uuid not null references public.users(id) on delete cascade,
  crop_label       text not null default '',
  emoji            text not null default '🌱',
  final_price      int not null check (final_price >= 0),     -- ₹/quintal
  quantity         numeric(12,2) not null check (quantity > 0),
  unit             produce_unit not null,
  total_amount     int not null check (total_amount >= 0),    -- server-computed only
  status           order_status not null default 'accepted',
  logistics_option text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_orders_farmer on public.orders(farmer_id);
create index idx_orders_dealer on public.orders(dealer_id);
create trigger trg_orders_updated before update on public.orders
  for each row execute function public.set_updated_at();

create table public.payments (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders(id) on delete cascade,
  amount        int not null check (amount >= 0),
  method        text,
  gateway_ref   text,
  escrow_status escrow_status not null default 'none',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger trg_payments_updated before update on public.payments
  for each row execute function public.set_updated_at();

-- ============================================================
-- reviews (only after order completed — enforced by trigger + RLS)
-- ============================================================
create table public.reviews (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references public.orders(id) on delete cascade,
  from_user  uuid not null references public.users(id) on delete cascade,
  to_user    uuid not null references public.users(id) on delete cascade,
  rating     int not null check (rating between 1 and 5),
  comment    text,
  created_at timestamptz not null default now(),
  unique (order_id, from_user)
);

create or replace function public.enforce_review_completed()
returns trigger language plpgsql as $$
begin
  if not exists (select 1 from public.orders o where o.id = new.order_id and o.status = 'completed') then
    raise exception 'reviews are only allowed after the order is completed';
  end if;
  return new;
end $$;
create trigger trg_reviews_completed before insert on public.reviews
  for each row execute function public.enforce_review_completed();

-- maintain avg rating on the rated user
create or replace function public.recalc_user_rating()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.users u set
    avg_rating = coalesce((select round(avg(rating)::numeric, 1) from public.reviews where to_user = u.id), 0),
    rating_count = (select count(*) from public.reviews where to_user = u.id)
  where u.id = new.to_user;
  return new;
end $$;
create trigger trg_reviews_recalc after insert on public.reviews
  for each row execute function public.recalc_user_rating();

-- ============================================================
-- disputes
-- ============================================================
create table public.disputes (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references public.orders(id) on delete cascade,
  raised_by  uuid not null references public.users(id) on delete cascade,
  reason     text not null,
  status     dispute_status not null default 'open',
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_disputes_updated before update on public.disputes
  for each row execute function public.set_updated_at();

-- ============================================================
-- price_records (mandi prices) — world-readable, server-written
-- ============================================================
create table public.price_records (
  id          uuid primary key default gen_random_uuid(),
  crop_id     uuid not null references public.crops(id) on delete cascade,
  market      text not null,
  price_min   int,
  price_max   int,
  price_modal int not null,
  date        date not null,
  source      text not null default 'agmarknet',
  created_at  timestamptz not null default now(),
  unique (crop_id, market, date)
);
create index idx_price_crop_date on public.price_records(crop_id, date desc);

-- ============================================================
-- saved_searches, notifications, audit_logs
-- ============================================================
create table public.saved_searches (
  id         uuid primary key default gen_random_uuid(),
  dealer_id  uuid not null references public.users(id) on delete cascade,
  label      text not null default '',
  filters    jsonb not null default '{}'::jsonb,
  alerts_on  boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  type       notif_type not null,
  title      text not null,
  body       text not null default '',
  payload    jsonb not null default '{}'::jsonb,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notif_user on public.notifications(user_id, created_at desc);

-- audit log — append-only; written by SECURITY DEFINER fns / service role
create table public.audit_logs (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid references public.users(id) on delete set null,
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  ip         text,
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index idx_audit_entity on public.audit_logs(entity, entity_id);

-- ============================================================
-- migrations/0002_rls.sql
-- ============================================================
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
  if not public.is_admin() then
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
  if (tg_op = 'UPDATE') and not public.is_admin() then
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
  if (tg_op = 'UPDATE') and not public.is_admin() then
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

-- ============================================================
-- migrations/0003_storage.sql
-- ============================================================
-- ============================================================
-- OpenMandi — storage buckets + policies.
--   listing-photos : public read, owner-scoped write (path = <uid>/...)
--   kyc-docs       : PRIVATE. Never public. Access only via short-lived
--                    signed URLs; rows readable by owner or admin.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('listing-photos', 'listing-photos', true,  5242880,
     array['image/jpeg','image/png','image/webp']),
  ('kyc-docs',       'kyc-docs',       false, 8388608,
     array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

-- ---------- listing-photos ----------
create policy "listing photos are public" on storage.objects
  for select using (bucket_id = 'listing-photos');

create policy "users upload own listing photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-photos'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users manage own listing photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'listing-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users delete own listing photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- kyc-docs (private) ----------
create policy "owner reads own kyc docs" on storage.objects
  for select to authenticated
  using (bucket_id = 'kyc-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

create policy "owner uploads own kyc docs" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'kyc-docs'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner replaces own kyc docs" on storage.objects
  for update to authenticated
  using (bucket_id = 'kyc-docs'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================
-- migrations/0004_functions.sql
-- ============================================================
-- ============================================================
-- OpenMandi — RPCs for atomic, server-side trade actions. All are
-- SECURITY DEFINER (bypass RLS) and re-check ownership with auth.uid().
-- ============================================================

-- helper: write an audit row (definer)
create or replace function public.audit(p_action text, p_entity text, p_entity_id uuid, p_meta jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.audit_logs(actor_id, action, entity, entity_id, metadata)
  values (auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_meta,'{}'::jsonb));
$$;

create or replace function public.notify(p_user uuid, p_type notif_type, p_title text, p_body text, p_payload jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, type, title, body, payload)
  values (p_user, p_type, p_title, p_body, coalesce(p_payload,'{}'::jsonb));
$$;

-- DEMO ONLY: auto-verify the caller's KYC. In production this is replaced by
-- the licensed Aadhaar/GST provider response handled by the Express service
-- (service role), which sets kyc_status after a real eKYC check.
create or replace function public.dev_autoverify_kyc()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.users set kyc_status = 'verified' where id = auth.uid();
  perform public.audit('kyc.autoverify(demo)', 'users', auth.uid());
end $$;

-- DEALER: make an offer on a listing. Creates or reuses a thread, an offer, and
-- an offer message. Does NOT create an order — the farmer accepts first.
create or replace function public.make_offer(p_listing uuid, p_price int, p_qty numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_farmer uuid; v_crop text; v_emoji text; v_unit produce_unit; v_thread uuid; v_offer uuid;
begin
  if not public.is_kyc_verified() then raise exception 'KYC not verified'; end if;

  select l.farmer_id, c.name, c.emoji, l.unit
    into v_farmer, v_crop, v_emoji, v_unit
  from public.listings l join public.crops c on c.id = l.crop_id
  where l.id = p_listing;
  if v_farmer is null then raise exception 'listing not found'; end if;
  if v_farmer = auth.uid() then raise exception 'cannot offer on your own listing'; end if;

  select id into v_thread from public.threads
    where listing_id = p_listing and farmer_id = v_farmer and dealer_id = auth.uid();
  if v_thread is null then
    insert into public.threads(listing_id, farmer_id, dealer_id, crop_label, emoji)
    values (p_listing, v_farmer, auth.uid(), v_crop, v_emoji) returning id into v_thread;
  end if;

  insert into public.offers(thread_id, listing_id, from_user, price, quantity, unit)
  values (v_thread, p_listing, auth.uid(), p_price, p_qty, v_unit) returning id into v_offer;

  insert into public.messages(thread_id, sender_id, type, offer_id)
  values (v_thread, auth.uid(), 'offer', v_offer);

  update public.listings set status = 'offers', offers = offers + 1 where id = p_listing;

  perform public.notify(v_farmer, 'offer', 'New offer on your ' || v_crop,
                        '₹' || p_price || '/qtl', jsonb_build_object('thread', v_thread));
  perform public.audit('offer.create', 'offers', v_offer);
  return v_thread;
end $$;

-- FARMER: accept an offer → declines siblings, marks listing sold, creates the order.
create or replace function public.accept_offer(p_offer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_thread uuid; v_listing uuid; v_farmer uuid; v_dealer uuid;
  v_price int; v_qty numeric; v_unit produce_unit; v_crop text; v_emoji text; v_order uuid;
begin
  select o.thread_id, o.listing_id, o.price, o.quantity, o.unit,
         t.farmer_id, t.dealer_id, t.crop_label, t.emoji
    into v_thread, v_listing, v_price, v_qty, v_unit, v_farmer, v_dealer, v_crop, v_emoji
  from public.offers o join public.threads t on t.id = o.thread_id
  where o.id = p_offer;
  if v_farmer is null then raise exception 'offer not found'; end if;
  if v_farmer <> auth.uid() then raise exception 'only the listing owner can accept'; end if;

  update public.offers set status = 'accepted' where id = p_offer;
  update public.offers set status = 'declined'
    where thread_id = v_thread and id <> p_offer and status = 'pending';
  if v_listing is not null then
    update public.listings set status = 'sold' where id = v_listing;
  end if;

  insert into public.orders(listing_id, farmer_id, dealer_id, crop_label, emoji,
                            final_price, quantity, unit, total_amount, status)
  values (v_listing, v_farmer, v_dealer, v_crop, v_emoji, v_price, v_qty, v_unit, 0, 'accepted')
  returning id into v_order;

  perform public.notify(v_dealer, 'order', 'Offer accepted', 'Pay into escrow to confirm',
                        jsonb_build_object('order', v_order));
  perform public.audit('offer.accept', 'orders', v_order);
  return v_order;
end $$;

-- order lifecycle (participant-checked). Real escrow money moves in Phase 2
-- via the Express service + Razorpay; here we advance the contract status.
create or replace function public.advance_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_status order_status; v_f uuid; v_d uuid;
begin
  select status, farmer_id, dealer_id into v_status, v_f, v_d from public.orders where id = p_order;
  if v_f is null then raise exception 'order not found'; end if;
  if auth.uid() not in (v_f, v_d) and not public.is_admin() then raise exception 'forbidden'; end if;

  update public.orders set status = case v_status
      when 'accepted'   then 'confirmed'
      when 'confirmed'  then 'in_transit'
      when 'in_transit' then 'delivered'
      else v_status end
  where id = p_order;
  perform public.audit('order.advance', 'orders', p_order, jsonb_build_object('from', v_status));
end $$;

create or replace function public.complete_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_f uuid; v_d uuid;
begin
  select farmer_id, dealer_id into v_f, v_d from public.orders where id = p_order;
  if v_f is null then raise exception 'order not found'; end if;
  if auth.uid() not in (v_f, v_d) and not public.is_admin() then raise exception 'forbidden'; end if;

  update public.orders set status = 'completed' where id = p_order and status = 'delivered';
  perform public.notify(v_f, 'payout', 'Order completed', 'Escrow released to your wallet',
                        jsonb_build_object('order', p_order));
  perform public.audit('order.complete', 'orders', p_order);
end $$;

grant execute on function
  public.dev_autoverify_kyc(), public.make_offer(uuid,int,numeric),
  public.accept_offer(uuid), public.advance_order(uuid), public.complete_order(uuid)
to authenticated;

-- ============================================================
-- seed.sql
-- ============================================================
-- ============================================================
-- OpenMandi — seed (master data + recent mandi prices).
-- Users are created via real sign-up (email OTP), so no auth.users are
-- seeded here. After signing up one farmer + one dealer you can walk the
-- full loop against this master data.
-- ============================================================

insert into public.crops (name, emoji, category, default_unit, names_i18n) values
  ('Tomato',  '🍅', 'vegetable', 'quintal', '{"hi":"टमाटर","kn":"ಟೊಮ್ಯಾಟೊ"}'),
  ('Onion',   '🧅', 'vegetable', 'quintal', '{"hi":"प्याज","kn":"ಈರುಳ್ಳಿ"}'),
  ('Potato',  '🥔', 'vegetable', 'quintal', '{"hi":"आलू","kn":"ಆಲೂಗಡ್ಡೆ"}'),
  ('Brinjal', '🍆', 'vegetable', 'quintal', '{"hi":"बैंगन","kn":"ಬದನೆಕಾಯಿ"}'),
  ('Chilli',  '🌶️', 'vegetable', 'quintal', '{"hi":"मिर्च","kn":"ಮೆಣಸಿನಕಾಯಿ"}'),
  ('Carrot',  '🥕', 'vegetable', 'quintal', '{"hi":"गाजर","kn":"ಕ್ಯಾರೆಟ್"}'),
  ('Cabbage', '🥬', 'vegetable', 'quintal', '{"hi":"पत्तागोभी","kn":"ಎಲೆಕೋಸು"}'),
  ('Okra',    '🫛', 'vegetable', 'quintal', '{"hi":"भिंडी","kn":"ಬೆಂಡೆಕಾಯಿ"}')
on conflict (name) do nothing;

-- recent mandi prices (Kolar APMC) for the trend charts
insert into public.price_records (crop_id, market, price_min, price_max, price_modal, date, source)
select c.id, 'Kolar APMC', p.modal - 150, p.modal + 200, p.modal, current_date, 'agmarknet'
from public.crops c
join (values
  ('Tomato', 2400), ('Onion', 1850), ('Potato', 1320), ('Brinjal', 2100),
  ('Chilli', 9800), ('Carrot', 1700), ('Cabbage', 980), ('Okra', 3200)
) as p(name, modal) on p.name = c.name
on conflict (crop_id, market, date) do nothing;

