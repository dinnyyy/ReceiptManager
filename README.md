# Receipt Vault (working title - app has no final name yet)

A native iPhone app that preserves proof of purchase - receipts, invoices and
photos - and connects each purchase to why it matters: tax, warranty,
insurance or asset records. Built for Australian sole traders and small
(1–5 person) equipment-owning businesses.

> Scan once. Keep the proof for everything.

See [`CLAUDE.md`](CLAUDE.md) for the full product plan, architecture,
decisions and build progress. Source research is in [`docs/`](docs).

## Status

The full V1 MVP feature set described in `docs/ios-mvp-specification.docx`
is implemented in source: auth (Sign in with Apple + email OTP), capture
(camera/photo/file/manual), on-device OCR + Review, local-first
SwiftData persistence with a syncing outbox, Home/Vault/Purchase
Detail/Items screens, warranty reminders, Tax/Warranty/Insurance/Generic
Proof Pack export (PDF + CSV), StoreKit 2 subscriptions with a paywall,
and Settings/account deletion. See `CLAUDE.md`'s progress checklist for
the exact state and what's still a placeholder (app name/branding, prices,
legal text, app icon).

**Not yet done**: a real Xcode build. This was developed in a Linux
sandbox with no Swift toolchain (see `CLAUDE.md` section 4) - the first
`xcodegen generate` + build on a Mac is the first real compiler check the
Swift code has had, and will likely need small fixes.

## Stack

- **iOS**: SwiftUI, VisionKit (document scanning), Vision (on-device OCR),
  SwiftData (local cache/outbox), StoreKit 2, UserNotifications, PDFKit.
- **Backend**: Supabase (Postgres + Auth + Storage), Row Level Security on
  every table, no service-role key ever ships in the app.
- **Core logic**: `Packages/ReceiptVaultCore` is a plain-Foundation Swift
  package (financial-year math, receipt field parsing, CSV/export
  formatting, sync state machine) kept independent of UIKit/SwiftUI so it's
  portable and easy to unit test.

## Repository layout

```
App/                    App entry point, environment, router
Core/                   Service layer (Auth, Backend, OCR, Storage, Sync, ...)
Features/               Screens, grouped by feature (Home, Capture, Vault, ...)
Models/                 Domain models, DTOs, SwiftData persistence models
Packages/ReceiptVaultCore/  Pure-Swift business logic + unit tests
Resources/              Assets, localized strings
Tests/                  XCTest unit / integration / UI test targets
supabase/               SQL migrations, RLS policies, seed data, RLS tests
docs/                   Source research & specification documents
```

## Getting started (on a Mac with Xcode)

**Fastest path to just look at the app**: `ReceiptVaultApp.swift` currently
points at `AppEnvironment.localOnly()`, which skips sign-in and Supabase
entirely - capture/OCR/Review/Vault/Items/Export all work for real against
an on-disk local database. `Config/Secrets.xcconfig` ships with safe
placeholder values (`AppEnvironment.localOnly()` never reads them), so you
can go straight to step 1 below with no backend setup at all. Switch to
`.live()` (see the comment at the top of that file) once you want real
auth/backup/sync.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. From the repo root: `xcodegen generate`
3. Open `ReceiptVault.xcodeproj` and run on an iPhone 15+ simulator (see
   `project.yml` for the minimum deployment target). Fix whatever the
   compiler flags first - see "Not yet done" above.

**Only if you're switching to `.live()`** for real auth/backup/sync:

4. Edit `Config/Secrets.xcconfig` with a real Supabase project's URL and
   anon key (the anon key is safe to ship - RLS protects every table).
5. Install the [Supabase CLI](https://supabase.com/docs/guides/cli),
   run `supabase start`, then `supabase db reset` to apply
   `supabase/migrations/`. Deploy `supabase/functions/delete-account` with
   `supabase functions deploy delete-account` for account deletion to work.

## Testing

- **Swift unit tests**: `Packages/ReceiptVaultCore` and `Tests/Unit` - run
  via Xcode/`swift test`. This dev environment has no Swift toolchain, so
  these have not been executed here; see `CLAUDE.md` for what has and
  hasn't been verified.
- **Database/RLS tests**: `supabase/tests/*.sql`, runnable against any
  Postgres instance - `scripts/db_test.sh` runs them locally and was used
  during development.

## License

Proprietary - all rights reserved (placeholder until a license is decided).
