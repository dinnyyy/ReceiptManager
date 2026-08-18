-- Row Level Security. Every user-data table gets RLS enabled with policies
-- that verify workspace membership for SELECT/INSERT/UPDATE/DELETE (spec
-- 7.2, 14). The client authenticates as a normal Supabase user and never
-- holds a service-role key, so these policies are the only thing standing
-- between one user's data and another's.

-- is_workspace_member() only ever checks the CALLING user's own row in
-- workspace_members (workspace_id = $1 and user_id = auth.uid()), which is
-- always visible under that table's own "user_id = auth.uid()" SELECT
-- policy below. That avoids RLS recursion without needing SECURITY DEFINER.
create function public.is_workspace_member(ws_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.workspace_members
    where workspace_id = ws_id and user_id = auth.uid()
  );
$$;

create function public.is_workspace_owner(ws_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.workspace_members
    where workspace_id = ws_id and user_id = auth.uid() and role = 'owner'
  );
$$;

-- profiles ------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: read own" on public.profiles
  for select to authenticated using (id = auth.uid());

create policy "profiles: insert own" on public.profiles
  for insert to authenticated with check (id = auth.uid());

create policy "profiles: update own" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- workspaces ------------------------------------------------------------
alter table public.workspaces enable row level security;

-- Owner is included directly (not just via is_workspace_member) so the
-- owner can see their own just-created workspace before the first
-- workspace_members row exists. create_initial_workspace() relies on this:
-- its workspace_members insert's WITH CHECK does "exists (select ... from
-- workspaces where owner_user_id = auth.uid())", and that select is itself
-- subject to this policy, so without the owner_user_id clause a brand new
-- owner could never insert their own first membership row.
create policy "workspaces: members and owner can read" on public.workspaces
  for select to authenticated using (public.is_workspace_member(id) or owner_user_id = auth.uid());

create policy "workspaces: owner can create" on public.workspaces
  for insert to authenticated with check (owner_user_id = auth.uid());

create policy "workspaces: owner can update" on public.workspaces
  for update to authenticated using (public.is_workspace_owner(id)) with check (public.is_workspace_owner(id));

create policy "workspaces: owner can delete" on public.workspaces
  for delete to authenticated using (public.is_workspace_owner(id));

-- workspace_members -------------------------------------------------------
alter table public.workspace_members enable row level security;

-- V1 only ever creates an owner membership for the calling user (no invite
-- UI yet), so "read own row" is sufficient and keeps is_workspace_member()
-- above non-recursive.
create policy "workspace_members: read own" on public.workspace_members
  for select to authenticated using (user_id = auth.uid());

create policy "workspace_members: insert own owner row" on public.workspace_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  );

create policy "workspace_members: owner can remove" on public.workspace_members
  for delete to authenticated using (public.is_workspace_owner(workspace_id));

-- folders -----------------------------------------------------------------
alter table public.folders enable row level security;

create policy "folders: members can read" on public.folders
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "folders: members can insert" on public.folders
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "folders: members can update" on public.folders
  for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "folders: members can delete" on public.folders
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- tags ----------------------------------------------------------------------
alter table public.tags enable row level security;

create policy "tags: members can read" on public.tags
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "tags: members can insert" on public.tags
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "tags: members can update" on public.tags
  for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "tags: members can delete" on public.tags
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- purchases -------------------------------------------------------------
alter table public.purchases enable row level security;

create policy "purchases: members can read" on public.purchases
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "purchases: members can insert" on public.purchases
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "purchases: members can update" on public.purchases
  for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "purchases: members can delete" on public.purchases
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- purchase_purposes (no workspace_id column; join through purchases) --------
alter table public.purchase_purposes enable row level security;

create policy "purchase_purposes: members can read" on public.purchase_purposes
  for select to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );
create policy "purchase_purposes: members can insert" on public.purchase_purposes
  for insert to authenticated with check (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );
create policy "purchase_purposes: members can delete" on public.purchase_purposes
  for delete to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );

-- purchase_tags ---------------------------------------------------------
alter table public.purchase_tags enable row level security;

create policy "purchase_tags: members can read" on public.purchase_tags
  for select to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );
create policy "purchase_tags: members can insert" on public.purchase_tags
  for insert to authenticated with check (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );
create policy "purchase_tags: members can delete" on public.purchase_tags
  for delete to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );

-- items -----------------------------------------------------------------
alter table public.items enable row level security;

create policy "items: members can read" on public.items
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "items: members can insert" on public.items
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "items: members can update" on public.items
  for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "items: members can delete" on public.items
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- purchase_items ----------------------------------------------------------
alter table public.purchase_items enable row level security;

create policy "purchase_items: members can read" on public.purchase_items
  for select to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );
create policy "purchase_items: members can insert" on public.purchase_items
  for insert to authenticated with check (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
    and exists (select 1 from public.items i where i.id = item_id and public.is_workspace_member(i.workspace_id))
  );
create policy "purchase_items: members can delete" on public.purchase_items
  for delete to authenticated using (
    exists (select 1 from public.purchases p where p.id = purchase_id and public.is_workspace_member(p.workspace_id))
  );

-- warranties --------------------------------------------------------------
alter table public.warranties enable row level security;

create policy "warranties: members can read" on public.warranties
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "warranties: members can insert" on public.warranties
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "warranties: members can update" on public.warranties
  for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy "warranties: members can delete" on public.warranties
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- attachments ---------------------------------------------------------------
alter table public.attachments enable row level security;

create policy "attachments: members can read" on public.attachments
  for select to authenticated using (public.is_workspace_member(workspace_id));
create policy "attachments: members can insert" on public.attachments
  for insert to authenticated with check (public.is_workspace_member(workspace_id));
create policy "attachments: members can delete" on public.attachments
  for delete to authenticated using (public.is_workspace_member(workspace_id));

-- subscription_state ------------------------------------------------------
-- Read-only from the client. Writes happen from the App Store server-webhook
-- handler using the service role (spec 10.3), which bypasses RLS entirely.
alter table public.subscription_state enable row level security;

create policy "subscription_state: read own" on public.subscription_state
  for select to authenticated using (user_id = auth.uid());
