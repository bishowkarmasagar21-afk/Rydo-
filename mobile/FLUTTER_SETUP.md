# Flutter workspace setup

This repository is a Flutter monorepo:

- `packages/rryd_core` — shared Supabase bootstrap, auth, profile model, language preferences and theme.
- `apps/passenger` — Passenger app source.
- `apps/driver` — Driver app source.

## SDK

Use Flutter stable with Dart 3.11 or newer and Flutter 3.41 or newer.

## Local commands

From the repository root:

```bash
cd packages/rryd_core
flutter pub get
flutter test
flutter analyze

cd ../../apps/passenger
flutter pub get
flutter analyze

cd ../driver
flutter pub get
flutter analyze
```

## Supabase runtime configuration

The apps expect build-time values. Do not add credentials to source code.

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

The publishable key may be used in a client application when RLS is correctly configured. A secret/service-role key must never be included in a mobile app or GitHub Actions build.

Before enabling login, confirm that the active Supabase project URL matches the production project used by the existing website. Configure both custom callback URLs in Supabase Auth URL Configuration:

- `com.rryd.passenger://auth-callback`
- `com.rryd.driver://auth-callback`

Native Android/iOS platform folders, callback intent handling, permissions and signed release settings are generated/configured in the platform-build milestone. This source-only milestone is checked by the GitHub Actions analyzer and tests; it is not an installable APK yet.
