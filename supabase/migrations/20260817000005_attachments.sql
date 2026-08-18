-- Attachments: original evidence files (spec 6.5, 7). Always private; never
-- a public-read URL. Polymorphic to either a purchase or an item, never
-- neither (spec 7.2 "at least one of purchase_id/item_id set").

create table public.attachments (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  purchase_id uuid references public.purchases(id) on delete cascade,
  item_id uuid references public.items(id) on delete cascade,
  type text not null check (type in ('receipt_image', 'invoice_pdf', 'item_photo', 'serial_label', 'warranty_document', 'valuation', 'manual', 'other')),
  storage_path text not null unique,
  original_filename text,
  mime_type text not null,
  bytes bigint,
  sha256 text,
  page_count integer,
  created_at timestamptz not null default now(),
  check (purchase_id is not null or item_id is not null)
);

create index attachments_purchase_id_idx on public.attachments(purchase_id);
create index attachments_item_id_idx on public.attachments(item_id);
create index attachments_workspace_id_idx on public.attachments(workspace_id);
