-- Profiles, workspaces, membership, folders, tags.
-- Spec section 7.1 / 8: one personal workspace per account in V1; team
-- membership is deliberately hidden from V1 UI but the schema allows it.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.workspaces (
  id uuid primary key,
  name text not null,
  type text not null check (type in ('personal', 'business')),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create index workspace_members_user_id_idx on public.workspace_members(user_id);

create table public.folders (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  parent_id uuid references public.folders(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (workspace_id, parent_id, name)
);

create index folders_workspace_id_idx on public.folders(workspace_id);

create table public.tags (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (workspace_id, name)
);

create index tags_workspace_id_idx on public.tags(workspace_id);
