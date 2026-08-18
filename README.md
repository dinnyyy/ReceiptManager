# Receipt Vault (working title - app has no final name yet)

A native iPhone app that preserves proof of purchase - receipts, invoices and
photos - and connects each purchase to why it matters: tax, warranty,
insurance or asset records. Built for Australian sole traders and small
(1–5 person) equipment-owning businesses.

> Scan once. Keep the proof for everything.

See [`CLAUDE.md`](CLAUDE.md) for the full product plan, architecture,
decisions and build progress. Source research is in [`docs/`](docs).

## Status

Early build. Not yet installable on a device - see the progress checklist
in `CLAUDE.md` for what's implemented.

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

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. From the repo root: `xcodegen generate`
3. Open `ReceiptVault.xcodeproj` and run on an iPhone 15+ simulator (see
   `project.yml` for the minimum deployment target).
4. Backend: install the [Supabase CLI](https://supabase.com/docs/guides/cli),
   run `supabase start`, then `supabase db reset` to apply
   `supabase/migrations/`.

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
