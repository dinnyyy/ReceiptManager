# Graph Report - .  (2026-08-27)

## Corpus Check
- Corpus is ~41,040 words - fits in a single context window. You may not need a graph.

## Summary
- 120 nodes · 219 edges · 16 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output
- Edge kinds: ON_BRANCH: 52 · PARENT_OF: 49 · contains: 48 · MODIFIES: 30 · references: 27 · reads_from: 10 · triggers: 3


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 121 · Candidates: 134
- Excluded: 0 untracked · 22 ignored · 1 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.

## Graph Freshness
- Built from Git commit: `fbce242`
- Compare this hash to `git rev-parse HEAD` before trusting freshness-sensitive graph output.
## God Nodes (most connected - your core abstractions)
1. `public.delete_account_data()` - 6 edges
2. `public.workspaces` - 5 edges
3. `public.purchases` - 5 edges
4. `public.create_initial_workspace()` - 5 edges
5. `auth.users` - 4 edges
6. `public.folders` - 4 edges
7. `public.items` - 4 edges
8. `public.attachments` - 4 edges
9. `public.workspace_members` - 3 edges
10. `public.purchase_tags` - 3 edges

## Surprising Connections (you probably didn't know these)
- `125ddee graphify update: index capture/OCR/review` --ON_BRANCH--> `claude/iphone-app-mvp-phase-1-p1std2`  [EXTRACTED]
  git → git  _Bridges community 5 → community 1_
- `1434289 Add ReceiptVaultCore: pure-Swift domain models and business logic` --ON_BRANCH--> `claude/iphone-app-mvp-phase-1-p1std2`  [EXTRACTED]
  git → git  _Bridges community 9 → community 1_
- `1a53f52 Add Supabase schema, RLS policies, and RPCs; verified against local Postgres` --ON_BRANCH--> `claude/iphone-app-mvp-phase-1-p1std2`  [EXTRACTED]
  git → git  _Bridges community 0 → community 1_
- `1a53f52 Add Supabase schema, RLS policies, and RPCs; verified against local Postgres` --PARENT_OF--> `e3e599c graphify update: index Supabase schema; stop tracking ephemeral graphify state`  [EXTRACTED]
  git → git  _Bridges community 0 → community 9_
- `37b2cc3 graphify update: index Items feature` --PARENT_OF--> `763f200 Add export builder (shared PDF renderer, CSV, share sheet); fix enum conformance`  [EXTRACTED]
  git → git  _Bridges community 5 → community 12_

## Hyperedges (group relationships)
- **Workspace-scoped RLS enforced across core tables** — workspaces_table, purchases_table, items_table, attachments_table [EXTRACTED 0.85]
- **Local-first capture-to-sync pipeline** — swiftdata, attachments_table, purchases_table [EXTRACTED 0.85]

## Communities

### Community 0 - "Core Purchase Schema"
Cohesion: 0.19
Nodes (8): 1a53f52 Add Supabase schema, RLS policies, and RPCs; verified against local Postgres, d5ee20a Add Supabase schema, RLS policies, and RPCs; verified against local Postgres, public.attachments, public.items, public.purchases, public.workspaces, auth.users, public.subscription_state

### Community 1 - "Project Documentation"
Cohesion: 0.28
Nodes (13): claude/iphone-app-mvp-phase-1-p1std2, 0a3a569 Final pass: coherence check, accessibility fixes, iOS version fix, integration test, 3695b1c graphify update: index settings feature, 4dfe85d Add SETUP.md: build steps and TestFlight distribution for non-technical testers, 4f268b6 graphify update: final index of the full app build, 74b3489 Add iOS app scaffold: project.yml, SwiftData schema, service protocols, 77d838a graphify update: index auth/onboarding, 9c27588 Add Sign in with Apple, Supabase email OTP, and workspace bootstrap (+5 more)

### Community 2 - "Shared Business Logic"
Cohesion: 0.40
Nodes (8): public, public.attachments, public.create_initial_workspace(), public.delete_account_data(), public.profiles, public.workspace_members, public.workspaces, v_workspace

### Community 3 - "Supabase Backend"
Cohesion: 0.31
Nodes (6): items_touch_updated_at, public.items, public.purchases, public.warranties, purchases_set_updated_at, warranties_touch_updated_at

### Community 4 - "On-device OCR"
Cohesion: 0.25
Nodes (7): main, 426ef79 Scaffold project: CLAUDE.md plan, README, repo layout, move source docs into docs/, 712759b Initialize graphify knowledge graph; add no-em-dash convention to CLAUDE.md, 88e01d4 Add initial Receipt Manager research and spec docs, 95e91dc Initialize graphify knowledge graph; add no-em-dash convention to CLAUDE.md, caf16db Add initial Receipt Manager research and spec docs, f10f37b Scaffold project: CLAUDE.md plan, README, repo layout, move source docs into docs/

### Community 5 - "RLS Test Harness"
Cohesion: 0.25
Nodes (8): 125ddee graphify update: index capture/OCR/review, 3653d25 Add Home, Purchase Detail, and Vault screens, 37b2cc3 graphify update: index Items feature, 3d47fc8 Add capture flow, on-device OCR, and the Review/Save screen, 5663285 graphify update: index persistence/sync layer, 6231493 Add SwiftData repositories, attachment staging, and outbox sync engine, 7ceb962 Add Items feature: list, detail, create/edit, warranty reminders, d4f2361 graphify update: index Home/PurchaseDetail/Vault

### Community 6 - "Folder Hierarchy"
Cohesion: 0.62
Nodes (6): auth.users, public.folders, public.profiles, public.tags, public.workspace_members, public.workspaces

### Community 7 - "Graphify Tooling"
Cohesion: 0.52
Nodes (6): public.folders, public.purchase_purposes, public.purchase_tags, public.purchases, public.tags, public.workspaces

### Community 8 - "PDF Export"
Cohesion: 0.38
Nodes (5): auth.users, pg_roles, storage.buckets, storage.foldername(), storage.objects

### Community 9 - "Apple Sign-In"
Cohesion: 0.33
Nodes (6): 1434289 Add ReceiptVaultCore: pure-Swift domain models and business logic, ab15fb5 graphify update: index auth/onboarding, aef5772 graphify update: index ReceiptVaultCore (note: tree-sitter Swift grammar unavailable in this environment, AST extraction limited), b9fbaca Add iOS app scaffold: project.yml, SwiftData schema, service protocols, cf14a8e Add Sign in with Apple, Supabase email OTP, and workspace bootstrap, e3e599c graphify update: index Supabase schema; stop tracking ephemeral graphify state

### Community 10 - "Community 10"
Cohesion: 0.67
Nodes (5): public.items, public.purchase_items, public.purchases, public.warranties, public.workspaces

### Community 11 - "Community 11"
Cohesion: 0.40
Nodes (5): 1bf43bd Add export builder (shared PDF renderer, CSV, share sheet); fix enum conformance, 884db08 graphify update: index Home/PurchaseDetail/Vault, aee74f0 graphify update: index Items feature, b4049cf Add Items feature: list, detail, create/edit, warranty reminders, cba5df2 Add StoreKit 2 subscriptions and the paywall screen

### Community 12 - "Community 12"
Cohesion: 0.40
Nodes (4): 7131f18 Add Settings screen and account deletion, 763f200 Add export builder (shared PDF renderer, CSV, share sheet); fix enum conformance, d6a7e46 Add StoreKit 2 subscriptions and the paywall screen, fc89c0e graphify update: index export builder and subscriptions

### Community 13 - "Community 13"
Cohesion: 0.83
Nodes (2): docs/ios-mvp-specification.docx, docs/viability-research.docx

### Community 14 - "Community 14"
Cohesion: 0.50
Nodes (4): 0db04cc Add Home, Purchase Detail, and Vault screens, 9e9ea8c graphify update: index persistence/sync layer, a9cd509 Add capture flow, on-device OCR, and the Review/Save screen, e033ca7 graphify update: index capture/OCR/review

### Community 15 - "Community 15"
Cohesion: 0.50
Nodes (4): 1d4fbad graphify update: index settings feature, 5051277 graphify update: index export builder and subscriptions, e3c6353 Add Settings screen and account deletion, f0adbe4 Final pass: coherence check, accessibility fixes, iOS version fix, integration test

## Knowledge Gaps
- **1 isolated node(s):** `auth.users`
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 13`** (2 nodes): `docs/ios-mvp-specification.docx`, `docs/viability-research.docx`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `auth.users` to the rest of the system?**
  _1 weakly-connected nodes found - possible documentation gaps or missing edges._