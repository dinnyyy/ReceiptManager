-- Extensions used across the schema.
-- pgcrypto: gen_random_uuid() as a server-side fallback (clients generate their own UUIDs,
--   see spec section 7 — client-generated UUIDs support offline capture + idempotent upsert).
-- pg_trgm: trigram indexes for fuzzy merchant-name search (spec 5.10 "search structured
--   fields plus raw OCR text").
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
