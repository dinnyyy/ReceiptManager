-- Server-side mirror of subscription state (spec 7.1, 11). StoreKit/App
-- Store remains the source of truth for entitlement; this table exists so
-- server-side logic and analytics don't need to call Apple directly.

create table public.subscription_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'solo_pro_monthly', 'solo_pro_annual')),
  entitlement_active boolean not null default false,
  product_id text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);
