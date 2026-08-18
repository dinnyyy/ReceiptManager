-- Purchases: the central object (spec section 7, 21). One purchase can carry
-- multiple purposes (purchase_purposes) and multiple tags (purchase_tags)
-- without duplicating the underlying record.

create table public.purchases (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  status text not null default 'saved' check (status in ('draft', 'needs_review', 'saved', 'archived')),
  merchant_name text,
  purchase_date date,
  total_amount numeric(12, 2) check (total_amount is null or total_amount >= 0),
  gst_amount numeric(12, 2) check (gst_amount is null or gst_amount >= 0),
  currency char(3) not null default 'AUD',
  receipt_number text,
  category text,
  folder_id uuid references public.folders(id) on delete set null,
  notes text,
  raw_ocr_text text,
  ocr_engine text,
  ocr_json jsonb,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index purchases_workspace_id_purchase_date_idx on public.purchases(workspace_id, purchase_date desc);
create index purchases_workspace_id_merchant_name_idx on public.purchases(workspace_id, merchant_name);
create index purchases_workspace_id_status_idx on public.purchases(workspace_id, status);
create index purchases_merchant_name_trgm_idx on public.purchases using gin (merchant_name gin_trgm_ops);

create table public.purchase_purposes (
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  purpose text not null check (purpose in ('tax', 'warranty', 'insurance', 'asset', 'reimbursement', 'donation', 'personal', 'other')),
  primary key (purchase_id, purpose)
);

create table public.purchase_tags (
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  primary key (purchase_id, tag_id)
);

create index purchase_tags_tag_id_idx on public.purchase_tags(tag_id);
