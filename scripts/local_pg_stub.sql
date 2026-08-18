-- Local-only stand-in for the parts of a real Supabase project that this
-- repo's migrations assume already exist: the `auth` schema (auth.users,
-- auth.uid()), the `storage` schema (storage.buckets, storage.objects,
-- storage.foldername()), the authenticated/anon/service_role roles, and the
-- default privilege grants Supabase applies to the public schema.
--
-- This file is NOT part of supabase/migrations/ and must never be applied
-- against a real Supabase project (it already has all of this). It exists
-- solely so scripts/db_test.sh can prove the migrations + RLS policies in
-- supabase/migrations/ behave correctly against a plain local Postgres.

drop schema if exists auth cascade;
create schema auth;

create table auth.users (
  id uuid primary key,
  email text,
  created_at timestamptz not null default now()
);

-- Supabase's real auth.uid() reads the "sub" claim out of the request JWT.
-- We simulate that with a session GUC the test script sets per simulated
-- user: SET request.jwt.claim.sub = '<uuid>';
create function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

drop schema if exists storage cascade;
create schema storage;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text not null,
  owner uuid,
  created_at timestamptz not null default now()
);

-- Mirrors Supabase's real storage.foldername(): split an object path on '/'
-- and return every segment except the filename itself.
create function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select (regexp_split_to_array(name, '/'))[1 : array_length(regexp_split_to_array(name, '/'), 1) - 1];
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;

-- Supabase grants these by default so PostgREST/the client SDK can reach
-- tables at all; row-level policies do the actual per-row authorization.
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant usage, select on sequences to authenticated;
alter default privileges in schema public grant execute on functions to authenticated;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema storage to anon, authenticated, service_role;
grant select, insert, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;

-- Real Supabase ships storage.objects with RLS already enabled.
alter table storage.objects enable row level security;
