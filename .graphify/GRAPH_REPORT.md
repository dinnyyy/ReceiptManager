# Graph Report - .  (2026-08-18)

## Corpus Check
- Corpus is ~2,232 words - fits in a single context window. You may not need a graph.

## Summary
- 32 nodes · 19 edges · 17 communities detected
- Extraction: 95% EXTRACTED · 0% INFERRED · 5% AMBIGUOUS
- Token cost: 4,200 input · 3,600 output
- Edge kinds: references: 15 · implements: 2 · calls: 1 · shares_data_with: 1


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 2 · Candidates: 5
- Excluded: 11 untracked · 3 ignored · 0 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.
## God Nodes (most connected - your core abstractions)
1. `purchases table` - 5 edges
2. `items table` - 3 edges
3. `docs/viability-research.docx` - 2 edges
4. `docs/ios-mvp-specification.docx` - 2 edges
5. `Supabase (Postgres + Auth + Storage)` - 2 edges
6. `workspaces table` - 2 edges
7. `purchase_items table` - 2 edges
8. `attachments table` - 2 edges
9. `Packages/ReceiptVaultCore` - 2 edges
10. `Apple Vision OCR (VNRecognizeTextRequest)` - 1 edges

## Surprising Connections (you probably didn't know these)
- `Supabase CLI` --references--> `Supabase (Postgres + Auth + Storage)`  [EXTRACTED]
  README.md → CLAUDE.md

## Hyperedges (group relationships)
- **Workspace-scoped RLS enforced across core tables** — workspaces_table, purchases_table, items_table, attachments_table [EXTRACTED 0.85]
- **Local-first capture-to-sync pipeline** — swiftdata, attachments_table, purchases_table [EXTRACTED 0.85]

## Communities

### Community 0 - "Core Purchase Schema"
Cohesion: 0.33
Nodes (7): attachments table, items table, purchase_items table, purchase_purposes table, purchases table, tags table, warranties table

### Community 1 - "Project Documentation"
Cohesion: 0.83
Nodes (2): docs/ios-mvp-specification.docx, docs/viability-research.docx

### Community 2 - "Shared Business Logic"
Cohesion: 0.67
Nodes (3): CSV export (Foundation string generation), Throwaway Python prototype, Packages/ReceiptVaultCore

### Community 3 - "Supabase Backend"
Cohesion: 0.67
Nodes (3): Supabase (Postgres + Auth + Storage), Supabase CLI, workspaces table

### Community 4 - "On-device OCR"
Cohesion: 1.00
Nodes (2): Apple Vision OCR (VNRecognizeTextRequest), OCRService (protocol)

### Community 5 - "RLS Test Harness"
Cohesion: 1.00
Nodes (2): scripts/db_test.sh, supabase/tests/*.sql

### Community 6 - "Folder Hierarchy"
Cohesion: 1.00
Nodes (1): folders table

### Community 7 - "Graphify Tooling"
Cohesion: 1.00
Nodes (1): Graphify

### Community 8 - "PDF Export"
Cohesion: 1.00
Nodes (1): PDFKit

### Community 9 - "Apple Sign-In"
Cohesion: 1.00
Nodes (1): Sign in with Apple

### Community 10 - "Subscriptions"
Cohesion: 1.00
Nodes (1): StoreKit 2

### Community 11 - "Email OTP Auth"
Cohesion: 1.00
Nodes (1): Supabase email OTP

### Community 12 - "Local Persistence"
Cohesion: 1.00
Nodes (1): SwiftData

### Community 13 - "SwiftUI UI Layer"
Cohesion: 1.00
Nodes (1): SwiftUI

### Community 14 - "Local Notifications"
Cohesion: 1.00
Nodes (1): UserNotifications (local only)

### Community 15 - "Document Scanning"
Cohesion: 1.00
Nodes (1): VisionKit (VNDocumentCameraViewController)

### Community 16 - "Xcode Project Generation"
Cohesion: 1.00
Nodes (1): XcodeGen

## Ambiguous Edges - Review These
- `tags table` → `purchases table`  [AMBIGUOUS]
  CLAUDE.md · relation: references

## Knowledge Gaps
- **21 isolated node(s):** `SwiftUI`, `SwiftData`, `VisionKit (VNDocumentCameraViewController)`, `Apple Vision OCR (VNRecognizeTextRequest)`, `OCRService (protocol)` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Project Documentation`** (2 nodes): `docs/ios-mvp-specification.docx`, `docs/viability-research.docx`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `On-device OCR`** (2 nodes): `Apple Vision OCR (VNRecognizeTextRequest)`, `OCRService (protocol)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `RLS Test Harness`** (2 nodes): `scripts/db_test.sh`, `supabase/tests/*.sql`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Folder Hierarchy`** (1 nodes): `folders table`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Graphify Tooling`** (1 nodes): `Graphify`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `PDF Export`** (1 nodes): `PDFKit`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Apple Sign-In`** (1 nodes): `Sign in with Apple`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Subscriptions`** (1 nodes): `StoreKit 2`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Email OTP Auth`** (1 nodes): `Supabase email OTP`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Local Persistence`** (1 nodes): `SwiftData`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `SwiftUI UI Layer`** (1 nodes): `SwiftUI`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Local Notifications`** (1 nodes): `UserNotifications (local only)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Document Scanning`** (1 nodes): `VisionKit (VNDocumentCameraViewController)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Xcode Project Generation`** (1 nodes): `XcodeGen`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `tags table` and `purchases table`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `purchases table` connect `Core Purchase Schema` to `Supabase Backend`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Why does `workspaces table` connect `Supabase Backend` to `Core Purchase Schema`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `SwiftUI`, `SwiftData`, `VisionKit (VNDocumentCameraViewController)` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._