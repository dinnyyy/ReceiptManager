# CLAUDE.md - Receipt Vault (working title)

This file is the onboarding doc for any future session (human or Claude)
picking this project back up. Read this before touching code.

## 1. What we're building

A **native iPhone app** that lets Australian sole traders and 1–5 person
equipment-owning microbusinesses (tradies, photographers, IT contractors,
creative studios) scan or import a receipt/invoice once and keep the proof
for every reason it might matter later: **tax, warranty, insurance, or
asset records** - without re-filing the same purchase multiple times.

Core promise: **"Scan once. Keep the proof for everything."**

Full source documents are in `docs/`:
- `docs/viability-research.docx` - market/competitor research and strategic
  reasoning (read this for *why*).
- `docs/ios-mvp-specification.docx` - the buildable technical spec (read
  this for *what*, screen by screen).

### Why this shape, not a generic receipt scanner

The viability research is explicit: **basic receipt-OCR-and-store is a
commodity.** ATO myDeductions and H&R Block ReceiptHub already do it for
free; Instant Receipts, Crunchr, Dext, Xero/Hubdoc and Expensify already
compete on Australian expense capture. Building "another receipt scanner"
scored the *worst* of every option the research evaluated.

The gap that scored highest (7/10, the report's top recommendation) sits
**between** two mature app categories:

- Accounting/expense apps understand *the expense*.
- Inventory/warranty apps (Itemtopia, Asset Inventory Vault, additem.to)
  understand *the item*.
- **This app understands that they're the same purchase.**

So the central object is not a receipt - it's a **Purchase**, which can
simultaneously be tagged Tax + Warranty + Insurance + Asset, and can
optionally link to an **Item** carrying brand/model/serial/location/warranty.
One capture, many downstream uses. That's the whole product thesis; don't
let scope creep dilute it into either a full accounting app or a general
home-inventory app (both explicitly rejected by the research).

**Do not build these, even if they seem easy to add:** bank feeds, BAS/tax
calculation or "this is deductible" claims, accounting integrations
(Xero/MYOB/QuickBooks), email inbox crawling, an AI chatbot, enterprise
approval workflows, inventory quantity management, Word/DOCX export,
Android (V1 is iPhone-only). Full non-goals list: spec section 2.2.

### Primary persona

Australian sole trader / 1–5 person business that buys physical equipment
and dislikes admin-heavy software. Their purchases naturally span several
purposes at once (a drill is simultaneously an expense, an asset, a
warrantied item, and potentially an insurance claim), which is why the
multi-purpose data model matters more for this persona than for someone
just saving supermarket receipts.

### Language rules (from the research - don't undo this positioning)

Never market: "AI-powered" as the headline, "automatically tax deductible",
"ATO compliant" (unless legally verified), "guaranteed" warranty/insurance
claims, "perfect OCR/handwriting". The tone is a quiet, trustworthy vault,
not an AI demo. See spec section 22.1.

## 2. MVP scope (what "phase 1" means here)

Phase 1 = the full V1 MVP defined in the spec's P0 user stories (US-01
through US-13), i.e. everything required for:

```
Capture → Verify → Purpose → Organise → Retrieve → Export
```

P1 items (duplicate-detection warnings, automatic serial-label OCR,
offline *editing*) are explicitly deferrable per spec section 19.1 and are
tracked as post-M7 stretch goals below, not blockers.

One-page acceptance bar (spec section 26): a beta user can scan a real
purchase, trust the saved evidence, find it weeks later, and generate a
useful Proof Pack - without it feeling like accounting software.

## 3. Architecture decisions

| Area | Choice | Why |
|---|---|---|
| UI | SwiftUI | Native, modern, matches spec recommendation |
| Architecture | Feature-based MVVM + service/repository protocols | Keeps OCR/storage/subscription logic testable and swappable, no enterprise ceremony |
| Local persistence | SwiftData | Offline drafts, outbox, fast cold start |
| Document capture | VisionKit (`VNDocumentCameraViewController`) | Native scan UX, multi-page support |
| OCR | Apple Vision (`VNRecognizeTextRequest`), on-device | No cloud dependency/cost for ordinary printed receipts; kept behind `OCRService` so a cloud fallback can be added later (spec 6.2, 6.3) |
| Backend | Supabase (Postgres + Auth + Storage) | Relational purchase/item/warranty model, private object storage, RLS, Swift client support |
| Auth | Sign in with Apple (primary) + Supabase email OTP (secondary) | No password handling |
| Subscriptions | StoreKit 2 - Free + Solo Pro (monthly/annual) | Native entitlement flow; Personal/Small Business tiers stay server-configured, not shipped in V1 UI |
| Exports | PDFKit + CSV (Foundation string generation) | Word/DOCX explicitly out of scope |
| Notifications | `UserNotifications`, local only | Warranty expiry reminders, scheduled on-device |
| Money | `Decimal` in Swift / `numeric(12,2)` in Postgres | **Never `Double` for money** - spec 5.7, 7 |
| Dates | Purchase/warranty dates are date-only; timestamps are UTC | Avoids timezone drift on financial-year boundaries |
| IDs | Client-generated UUIDs for every business object | Enables offline capture + idempotent upsert sync |

### Data model (see `supabase/migrations/`)

`workspaces` (one personal workspace per account in V1) → `purchases` →
`purchase_purposes` (multi-select tax/warranty/insurance/asset/...),
`purchase_items` (many-to-many to `items`), `items` → `warranties`,
`attachments` (private, polymorphic to purchase or item), `folders`
(single, optional hierarchy), `tags` (many-to-many). Every table carries
`workspace_id` and has RLS enforcing workspace membership on
SELECT/INSERT/UPDATE/DELETE. **The client never holds a service-role key.**

### Sync model

Local-first: capture → SwiftData draft (client UUID) → enqueue outbox →
upload attachment (idempotent, deterministic storage path) → upsert
purchase row (client UUID, `updated_at` for now-simple conflict handling -
V1 assumes single active device, last-write-wins is acceptable per spec
9.4). A record's sync state (`localOnly` / `pendingUpload` / `syncing` /
`synced` / `failed`) is always visible in the UI; failure never hides or
deletes the local record.

### Repository layout

See `README.md` for the directory tree. `Packages/ReceiptVaultCore` holds
every algorithm that doesn't need UIKit/SwiftUI/VisionKit (financial-year
math, date parsing, merchant/total/GST candidate scoring, CSV escaping,
duplicate-detection scoring, sync state machine, entitlement rules) so it
can be unit-tested in isolation from the UI layer.

## 4. Development environment notes (important - read before assuming CI/test state)

This project has, at various points, been developed inside a **Linux
container with no Xcode, no iOS Simulator, and no Swift toolchain**
(`download.swift.org` is blocked by the sandbox's network policy - only
npm/PyPI/crates-style registries are reachable). That means Swift/SwiftUI
code written in that environment **could not be compiled or run there**.

What *was* actually verified in that environment, and how:
- **Postgres schema + RLS policies**: real, running `postgresql-16`
  locally. `scripts/db_test.sh` applies every migration to a scratch
  database and runs `supabase/tests/*.sql`, which creates two fake
  `auth.users`, seeds data for each, and asserts (via `SET LOCAL
  request.jwt.claims`, mimicking Supabase's `auth.uid()`) that workspace A
  cannot read/write/delete workspace B's rows. This is genuine test
  execution, not a code review.
- **Tricky parsing/scoring algorithms** (AU financial-year boundary maths,
  receipt date-format parsing, total/GST candidate scoring, CSV escaping):
  prototyped and exercised against edge cases in a throwaway Python
  script before being ported to Swift, specifically because the Swift
  itself could not be executed. The Python prototype is not part of the
  shipped app.
- **Everything else** (SwiftUI views, VisionKit/Vision/SwiftData/StoreKit2
  integration code) was written carefully against known Apple API
  signatures and cross-checked by re-reading, but is **unverified by
  compilation**. Treat first Xcode build on a real Mac as the first real
  compiler check for that code, and expect to fix small signature/typo
  issues.

If you're resuming this project **with real Xcode access**: your first
move should be `xcodegen generate`, open in Xcode, and fix whatever the
compiler finds before adding new features. Update the checklist below
once you've done a real build.

### Graphify

This repo uses [graphify](https://github.com/rhanka/graphify) to keep a
queryable knowledge graph of the codebase. Run `graphify update` after
meaningful commits (already wired into the workflow used to build this
project). Initialize a fresh clone with `npx @sentropic/graphify .`.

## 5. Progress checklist

Update this section as you go. Check items only when actually done, not
aspirationally - the whole point is that a resuming session can trust it.

### Foundation
- [x] Repo scaffolding (dirs, README, this file, .gitignore)
- [x] Graphify initialized
- [x] Supabase migrations: workspaces/purchases/items/attachments/warranties/tags/folders + RLS
- [x] RLS proven with local Postgres cross-workspace negative test (`scripts/db_test.sh`,
      `supabase/tests/001_rls_isolation.sql`, 13/13 assertions passing). This run caught
      and fixed two real bugs: `INSERT ... RETURNING` is subject to the table's SELECT
      RLS policy, not just INSERT's WITH CHECK, so `create_initial_workspace()` was
      failing to create a user's very first workspace/membership pair.
- [x] `create_initial_workspace` RPC (idempotent)
- [x] `search_purchases` RPC (structured + full-text)
- [x] `delete_account_data` RPC (service-role only)
- [x] Storage bucket + RLS policies (`proof-files`, private)
- [x] Seed script (`supabase/seed/seed.sql`)
- [x] ReceiptVaultCore package: domain models (Purchase, Item, Attachment,
      Warranty, DateOnly, enumerations)
- [x] ReceiptVaultCore: AU financial-year helper (+ tests)
- [x] ReceiptVaultCore: receipt date parser (+ tests)
- [x] ReceiptVaultCore: merchant/total/GST field scorer (+ tests)
- [x] ReceiptVaultCore: CSV escaping + Tax CSV builder (+ tests)
- [x] ReceiptVaultCore: duplicate-detection scorer (+ tests)
- [x] ReceiptVaultCore: sync state machine (+ tests)
- [x] ReceiptVaultCore: entitlement gating rules (+ tests)
- [x] ReceiptVaultCore: warranty status + reminder schedule (+ tests)
- [ ] XcodeGen `project.yml` + app entry point/router/environment

### Auth & onboarding
- [x] Onboarding cards (Scan once / Find it later / Proof Packs)
- [x] Sign in with Apple (custom ASAuthorizationController coordinator, spec-clean async AuthService API)
- [x] Supabase email OTP/magic link
- [x] Session restore on launch (never a permanent blank screen)
- [x] Idempotent workspace bootstrap wired to `create_initial_workspace` RPC

### Capture → OCR → Review
- [x] Capture source sheet (camera/photo/file/manual)
- [x] VisionKit document scanner wrapper (`DocumentScannerView`)
- [x] Photo import (SwiftUI `PhotosPicker`)
- [x] File importer (PDF/JPEG/PNG/HEIC via `.fileImporter`)
- [x] Local draft creation (client UUID before any network work - `CaptureDraft`)
- [x] Vision OCR service (`VisionOCRService`: `VNRecognizeTextRequest`, PDF pages rendered via PDFKit first)
- [x] Field parser wired to OCR output with confidence tiers (`ReviewViewModel`)
- [x] Review & Save screen (editable fields, purpose chips, notes, duplicate warning, "add item details" prompt)

### Persistence & sync
- [x] SwiftData models (Purchase/Item/Attachment/Warranty/Folder/Tag/Outbox)
- [x] PurchaseRepository + ItemRepository (local-first, search runs against local cache)
- [x] AttachmentService (stage/upload/fetch, deterministic storage paths, sha256)
- [x] Outbox + retry/backoff (exponential, capped 5min) + network/foreground resume
- [ ] Sync-state UI indicators (wired into screens as each screen is built)

### Retrieval
- [x] Home tab (scan CTA, inbox, recent, warranty-ending-soon, empty state, pull-to-refresh)
- [x] Purchase Detail screen (evidence carousel, edit, add attachment, export, delete with confirmation)
- [x] Vault tab (search debounced, purpose/FY/status filter chips, sort, multi-select + export, no-results reset)
- [x] Items tab (list, detail, linked purchases, "no purchase proof linked" state)
- [x] Item create/edit (brand/model/serial/location/photos, prefill value from linked purchase as a suggestion)
- [x] Warranty fields + local notification scheduling (30d/7d, `LocalNotificationScheduler`, permission requested lazily)

### Export
- [ ] Shared Proof Pack PDF renderer (Tax/Warranty/Insurance)
- [ ] Tax CSV export
- [ ] Share sheet integration

### Monetisation & settings
- [ ] StoreKit 2 products (Free / Solo Pro monthly / annual)
- [ ] Paywall screen + entitlement gating at free limit
- [ ] Restore purchases
- [ ] Settings screen (profile, storage, export-all, delete account)
- [ ] Privacy-minimised analytics events (spec section 15 event list)

### Quality
- [ ] Accessibility pass (Dynamic Type, VoiceOver labels, non-colour-only status)
- [ ] XCTest unit test files for UI-adjacent logic
- [ ] XCTest integration test files (signup→workspace→save, RLS negative test, offline→sync)
- [ ] First real Xcode build performed (update this doc with results)

## 6. Writing conventions

- **Never use em dashes (—) anywhere**: not in code comments, commit
  messages, docs, or UI copy. Use a hyphen, colon, or a new sentence
  instead.
- **Commits always use the repo owner's identity**, never Claude's. Local
  git config in this repo is already set to `dinnyyy <joshdinn01@gmail.com>`;
  do not add Co-Authored-By or any other Claude attribution to commit
  messages, and don't let a fresh session reset `user.name`/`user.email`
  back to a Claude identity.

## 7. Decisions deliberately left as placeholders (need founder/legal input before App Store submission)

Per spec section 20 - do not silently invent these, they're configuration:
- Final app name/branding (currently unnamed; "Receipt Vault" used as a
  working codename in docs/comments only)
- Minimum iOS version (tied to whichever Xcode/SDK actually builds this  - 
  decide when you have Xcode)
- Free-tier purchase limit (spec assumes 40, server-configurable)
- Exact subscription prices (research suggests ~A$7.99–9.99/mo Solo Pro,
  ~A$79/yr annual - must be set in App Store Connect, not hard-coded)
- Support email/URL, Privacy Policy, Terms text
- Data hosting region (prefer Australian region where practical)
