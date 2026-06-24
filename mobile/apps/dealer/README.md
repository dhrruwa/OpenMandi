# OpenMandi — Dealer app

The dealer-facing Flutter app: discover verified farmers' produce (list + map
view), make offers and counter-offers in chat, post buy-requirements, fund
orders through escrow, chat (text + voice), and rate completed trades.

Built on the shared **`openmandi_ui`** package (design system, models, store,
Supabase client). See [`../../README.md`](../../README.md) and
[`../../../BACKEND_SETUP.md`](../../../BACKEND_SETUP.md).

## Run
```bash
flutter pub get
flutter run                                              # demo mode (no backend)
flutter run --dart-define-from-file=../../openmandi.env.json   # live (Supabase)
```
Release APK:
```bash
flutter build apk --release --dart-define-from-file=../../openmandi.env.json
```
Add `--dart-define=REQUIRE_LOGIN=true` to enforce real auth (default is a paused
demo auto-login).
