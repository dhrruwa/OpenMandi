# OpenMandi

A farmer ↔ dealer agricultural marketplace for India — OLX-style for crops.
Farmers list produce against live mandi prices; dealers discover, negotiate,
order, and pay; the whole trade runs its lifecycle (discover → negotiate →
order → pay → deliver → rate) directly between the two parties, no middleman.

## Repository layout

```
OpenMandi/
├── mobile/
│   ├── packages/openmandi_ui/   # shared design system, models, store, backend client
│   └── apps/
│       ├── farmer/              # Flutter app — list produce, accept offers, get paid
│       └── dealer/              # Flutter app — discover, offer, post buy-requirements
├── server/                      # Hono + @supabase/server (Phase 2: eKYC, Razorpay escrow)
├── supabase/
│   ├── migrations/              # schema, RLS, RPCs, storage, hardening (0001–0014)
│   ├── seed.sql                 # crops + demo data
│   └── production_hardening.sql # run manually at go-live (removes demo backdoors)
├── PRODUCT.md   DESIGN.md   BACKEND_SETUP.md   SECURITY.md
```

## Stack
- **Flutter** (Dart) — two apps over one shared `openmandi_ui` package.
- **Supabase** — Postgres + Auth + Storage + Realtime. RLS on every table,
  `SECURITY DEFINER` RPCs for trade actions.
- **Hono / `@supabase/server`** (Node) — server-side admin/KYC/payments (Phase 2).
- **Free maps** — `flutter_map` + OpenStreetMap/CARTO tiles + Nominatim geocoding
  + local haversine distance. No Google Maps key, no billing.

## Features (built)
- Listings with photos + optional **map-pinned location**; live mandi price board.
- Dealer **discover** (search/filter, list + **map view**) → listing detail → **make offer**.
- **Negotiation in chat**: offers, **counter-offers** (either side), accept-once.
- **Buy requirements**: dealers post; farmers browse and **respond / reverse-offer**.
- **Orders + lifecycle**: pay into escrow → dispatch → confirm delivery (escrow sim).
- **Ratings & reviews** on completed orders (real, no fakes).
- **Chat** with text + WhatsApp-style **voice messages**; notifications; multilingual UI.
- **Payments section** (wallet, escrow, transactions, payment methods — UI only, no live gateway).

## Quick start
The apps run in **offline demo mode** with no backend (in-memory data). To run the
real shared backend and build the apps, see **[BACKEND_SETUP.md](BACKEND_SETUP.md)**.

```bash
# demo mode (no backend needed)
cd mobile/apps/farmer && flutter run
cd mobile/apps/dealer && flutter run
```

## Status / notes
- **Auth is currently paused** for development: a demo account auto-logs-in so the
  app is walkable without a login screen. Build with `--dart-define REQUIRE_LOGIN=true`
  to enforce real auth. See SECURITY.md.
- Before going live, run `supabase/production_hardening.sql` and **rotate all keys**
  (see SECURITY.md → "Go-live").

## Docs
- **[PRODUCT.md](PRODUCT.md)** — users, purpose, brand, principles.
- **[DESIGN.md](DESIGN.md)** — visual system (color, type, spacing, motion, elevation).
- **[BACKEND_SETUP.md](BACKEND_SETUP.md)** — provision Supabase + run live.
- **[SECURITY.md](SECURITY.md)** — controls, RLS, hardening, Aadhaar/DPDP compliance.
