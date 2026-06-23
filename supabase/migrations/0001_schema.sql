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
