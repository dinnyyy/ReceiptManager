-- Items: the real-world asset/product side of a purchase (spec 5.9, 5.11, 21).
-- A purchase can link to multiple items and an item can link to multiple
-- purchases (e.g. a laptop purchase plus a separate accessory purchase).

create table public.items (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  brand text,
  model text,
  serial_number text,
  original_value numeric(12, 2) check (original_value is null or original_value >= 0),
  location text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index items_workspace_id_idx on public.items(workspace_id);
create index items_workspace_id_serial_number_idx on public.items(workspace_id, serial_number);

create table public.purchase_items (
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  allocated_value numeric(12, 2) check (allocated_value is null or allocated_value >= 0),
  primary key (purchase_id, item_id)
);

create index purchase_items_item_id_idx on public.purchase_items(item_id);

-- Warranties are a separate table (not columns on items) so a future
-- extended/replacement warranty can be recorded without losing the
-- original one (spec 7.1 entity notes).
create table public.warranties (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  item_id uuid not null references public.items(id) on delete cascade,
  provider text,
  start_date date,
  expiry_date date,
  details text,
  reminder_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index warranties_item_id_idx on public.warranties(item_id);
create index warranties_workspace_id_expiry_date_idx on public.warranties(workspace_id, expiry_date);
