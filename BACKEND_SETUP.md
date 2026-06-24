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
listing photos, private KYC, chat voice), triggers, and the trade RPCs
(`make_offer`, `accept_offer`, `counter_offer`, `respond_to_requirement`,
order lifecycle). Migration `0014_security_hardening.sql` locks internal helper
functions to server/admin only — see SECURITY.md.

### Enable email OTP
Supabase dashboard → Authentication → Providers → Email → enable **Email OTP**
(disable "Confirm email" link-only if you want 6-digit codes). Configure SMTP
(Auth → SMTP) or use the built-in dev mailer for testing.

## 3. Run the apps in live mode
Put your credentials in `mobile/openmandi.env.json` (git-ignored — never commit):
```json
{
  "SUPABASE_URL": "https://YOUR.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_...",
  "GOOGLE_MAPS_API_KEY": ""
}
```
`SUPABASE_ANON_KEY` is the **publishable** key (`sb_publishable_...`) — safe on the
client; RLS protects the data. `GOOGLE_MAPS_API_KEY` can stay empty: maps use free
OpenStreetMap/CARTO tiles + Nominatim, no Google key needed.

Then run / build with the file:
```bash
cd mobile/apps/farmer
flutter run --dart-define-from-file=../../openmandi.env.json
# release build:
flutter build apk --release --dart-define-from-file=../../openmandi.env.json
```
(Same for `apps/dealer`.) With the file set, the apps switch to **live mode**:
listings, search, realtime chat/offers, **counter-offers**, buy-requirements,
orders + lifecycle, reviews — shared between both apps and persisted. Without it
they stay in demo mode.

### Auth is paused by default
For development, `REQUIRE_LOGIN` defaults to **false**: a demo account auto-logs-in
so there's no login wall. To enforce real auth (and require email OTP / KYC), add
`--dart-define=REQUIRE_LOGIN=true` to the run/build command.

Walk the loop: a **farmer** lists produce → a **dealer** discovers + makes an offer
(or counter) → farmer accepts → order → pay → dispatch → confirm → review. Or:
dealer posts a **buy requirement** → farmer responds with a price → order.

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
