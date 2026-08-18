# Graph Report - .  (2026-08-18)

## Corpus Check
- Corpus is ~24,911 words - fits in a single context window. You may not need a graph.

## Summary
- 79 nodes · 124 edges · 10 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output
- Edge kinds: contains: 48 · references: 27 · MODIFIES: 14 · ON_BRANCH: 12 · PARENT_OF: 10 · reads_from: 10 · triggers: 3


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 80 · Candidates: 93
- Excluded: 0 untracked · 21 ignored · 1 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.

## Graph Freshness
- Built from Git commit: `9c7307b`
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
- `95e91dc Initialize graphify knowledge graph; add no-em-dash convention to CLAUDE.md` --PARENT_OF--> `d5ee20a Add Supabase schema, RLS policies, and RPCs; verified against local Postgres`  [EXTRACTED]
  git → git  _Bridges community 0 → community 1_

## Hyperedges (group relationships)
- **Workspace-scoped RLS enforced across core tables** — workspaces_table, purchases_table, items_table, attachments_table [EXTRACTED 0.85]
- **Local-first capture-to-sync pipeline** — swiftdata, attachments_table, purchases_table [EXTRACTED 0.85]

## Communities

### Community 0 - "Core Purchase Schema"
Cohesion: 0.26
Nodes (12): claude/iphone-app-mvp-phase-1-p1std2, main, 74b3489 Add iOS app scaffold: project.yml, SwiftData schema, service protocols, 77d838a graphify update: index auth/onboarding, 95e91dc Initialize graphify knowledge graph; add no-em-dash convention to CLAUDE.md, 9c27588 Add Sign in with Apple, Supabase email OTP, and workspace bootstrap, 9c7307b Add SwiftData repositories, attachment staging, and outbox sync engine, a2766ae graphify update: index Supabase schema; stop tracking ephemeral graphify state (+4 more)

### Community 1 - "Project Documentation"
Cohesion: 0.20
Nodes (3): d5ee20a Add Supabase schema, RLS policies, and RPCs; verified against local Postgres, auth.users, public.subscription_state

### Community 2 - "Shared Business Logic"
Cohesion: 0.40
Nodes (8): public, public.attachments, public.create_initial_workspace(), public.delete_account_data(), public.profiles, public.workspace_members, public.workspaces, v_workspace

### Community 3 - "Supabase Backend"
Cohesion: 0.31
Nodes (6): items_touch_updated_at, public.items, public.purchases, public.warranties, purchases_set_updated_at, warranties_touch_updated_at

### Community 4 - "On-device OCR"
Cohesion: 0.62
Nodes (6): auth.users, public.folders, public.profiles, public.tags, public.workspace_members, public.workspaces

### Community 5 - "RLS Test Harness"
Cohesion: 0.52
Nodes (6): public.folders, public.purchase_purposes, public.purchase_tags, public.purchases, public.tags, public.workspaces

### Community 6 - "Folder Hierarchy"
Cohesion: 0.38
Nodes (5): auth.users, pg_roles, storage.buckets, storage.foldername(), storage.objects

### Community 7 - "Graphify Tooling"
Cohesion: 0.67
Nodes (5): public.items, public.purchase_items, public.purchases, public.warranties, public.workspaces

### Community 8 - "PDF Export"
Cohesion: 0.70
Nodes (4): public.attachments, public.items, public.purchases, public.workspaces

### Community 9 - "Apple Sign-In"
Cohesion: 0.83
Nodes (2): docs/ios-mvp-specification.docx, docs/viability-research.docx

## Knowledge Gaps
- **1 isolated node(s):** `auth.users`
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Apple Sign-In`** (2 nodes): `docs/ios-mvp-specification.docx`, `docs/viability-research.docx`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `auth.users` to the rest of the system?**
  _1 weakly-connected nodes found - possible documentation gaps or missing edges._