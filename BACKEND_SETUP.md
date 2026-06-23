# OpenMandi — Backend setup (go live)

The apps run in **offline demo mode** by default (in-memory data — nothing
breaks without a backend). To run the real, persistent, shared backend:

## 1. Create a Supabase project (free)
1. Go to https://supabase.com → New project. Pick a region near your users.
2. Project Settings → API → copy the **Project URL** and the **anon/publishable**
   key (the public one). Settings → API → copy the **service_role** key (secret).

## 2. Push the schema + security
```bash
cd OpenMandi
supabase link --project-ref <your-project-ref>   # asks for the DB password
supabase db push                                  # applies migrations/*.sql
supabase db execute --file supabase/seed.sql      # crops + mandi prices
```
This creates every table, **RLS on all of them**, storage buckets (public
listing photos, private KYC), triggers, and the trade RPCs.

### Enable email OTP
Supabase dashboard → Authentication → Providers → Email → enable **Email OTP**
(disable "Confirm email" link-only if you want 6-digit codes). Configure SMTP
(Auth → SMTP) or use the built-in dev mailer for testing.

## 3. Run the apps in live mode
Pass your credentials as dart-defines (no secrets in source):
```bash
cd mobile/apps/farmer
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...anon...

cd ../dealer
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...anon...
```
With the defines set, the apps switch to **live mode**: real email-OTP sign-up,
KYC, listings, search, realtime chat/offers, orders + lifecycle, reviews — shared
between both apps and persisted. Without them, they stay in demo mode.

Walk the loop: sign up a **farmer** (one browser) and a **dealer** (another) →
farmer lists produce → dealer discovers + makes an offer → farmer accepts → order
→ lifecycle → review.

## 4. (Phase 2) The secure Express service
Needed only for real Aadhaar/GST eKYC, Razorpay escrow, and the mandi-price cron.
```bash
cd server
cp .env.example .env        # fill SUPABASE_*, RAZORPAY_*, KYC_*, DATAGOV_*
npm install
npm run dev                 # http://localhost:8787
```
Then set `--dart-define=API_BASE_URL=http://localhost:8787` on the apps to route
KYC/payments through it. Sandbox provider keys are fine for a demo; the masking +
encryption rules hold even in sandbox.

See **SECURITY.md** for the full controls + Aadhaar/DPDP compliance approach.

## What needs YOUR accounts (cannot be created for you)
- Supabase project (URL + anon + service-role keys)
- Razorpay test keys (payments/escrow)
- A UIDAI-licensed KYC provider's sandbox creds (Aadhaar/GST)
- data.gov.in API key (live mandi prices)
- An SMTP sender for OTP emails (or Supabase dev mailer for testing)
