# OpenMandi — Flutter apps

Two apps over one shared design system, mirroring the single-backend spec
(farmer and dealer roles trading the same produce lifecycle).

```
mobile/
├── packages/
│   └── openmandi_ui/        # shared: theme (OKLCH→sRGB), models, mock data, widgets
└── apps/
    ├── farmer/              # list produce · live mandi price · escrow wallet
    └── dealer/              # discover verified farmers · offer · buy requirements
```

The palette, type (Hanken Grotesk), spacing and components are authored once in
`openmandi_ui` and consumed by both apps, so they stay on-brand. See `../DESIGN.md`
and `../PRODUCT.md` for the strategy.

## Run

```bash
# from mobile/
flutter pub get -C packages/openmandi_ui

cd apps/farmer && flutter pub get && flutter run     # farmer app
cd apps/dealer && flutter pub get && flutter run     # dealer app
```

Targets enabled: web, android, ios. For web: `flutter run -d chrome`.

## Verify

```bash
flutter analyze        # clean in all three packages
flutter build web      # both apps compile to JS
```

## Screens

**Farmer** — Home (escrow wallet, live mandi price strip, your listings, activity)
and a 6-step *List produce* flow (crop → quantity → quality+organic → photos →
price-with-mandi-context → review+escrow → success).

**Dealer** — Discover (search, filter chips, seller-attributed listing feed) →
Listing detail (specs, verified seller, mandi context, escrow note) → *Make offer*
sheet with live total. Plus Requirements (reverse marketplace) and Orders/Chats/
Profile shells.
