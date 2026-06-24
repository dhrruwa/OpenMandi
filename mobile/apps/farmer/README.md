# OpenMandi — Farmer app

The farmer-facing Flutter app: list produce against live mandi prices, receive
and accept/counter dealer offers, respond to buyer requirements, track orders
through the escrow lifecycle, chat (text + voice), and get rated.

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
