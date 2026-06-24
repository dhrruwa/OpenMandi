# OpenMandi — Flutter apps

Two apps over one shared design system, mirroring the single-backend spec
(farmer and dealer roles trading the same produce lifecycle).

```
mobile/
├── packages/
│   └── openmandi_ui/        # shared: theme/tokens, models, store, backend client, widgets
└── apps/
    ├── farmer/              # list produce · live mandi price · offers · payments
    └── dealer/              # discover · offer/counter · buy requirements · map view
```

The palette, type (Hanken Grotesk), spacing, elevation and components are authored
once in `openmandi_ui` and consumed by both apps, so they stay on-brand. See
`../DESIGN.md` (→ "Implemented (Flutter)") and `../PRODUCT.md` for the strategy.

## Run

```bash
# demo mode (in-memory, no backend)
cd apps/farmer && flutter pub get && flutter run
cd apps/dealer && flutter pub get && flutter run

# live mode (Supabase) — see ../BACKEND_SETUP.md
flutter run --dart-define-from-file=../../openmandi.env.json
# enforce real auth (default is a paused/demo auto-login):
#   add  --dart-define=REQUIRE_LOGIN=true
```

Targets: android, ios, web (`flutter run -d chrome`). Release APK:
`flutter build apk --release --dart-define-from-file=../../openmandi.env.json`.

## Verify

```bash
flutter analyze        # clean in all three packages
```

## Screens

**Farmer** — Home (live mandi price strip, your listings, buyer requirements,
activity) · *List produce* flow (crop → quantity → quality+organic → **map-pin
location** → photos → price-with-mandi-context → review) · My listing (stats +
incoming offers, accept/delete) · Buyer requirements (respond / reverse-offer) ·
Orders, Chats (text + voice + in-chat offers/counters), Payments, Profile.

**Dealer** — Discover (search, filter chips, listing feed + **map view**) →
Listing detail (specs, seller, mandi context, escrow note) → *Make offer* /
counter sheet with live total · Requirements (post + delete) · Orders, Chats,
Payments, Profile.

Both apps share the order lifecycle (pay into escrow → dispatch → confirm
delivery), real ratings on completed orders, and notifications.
