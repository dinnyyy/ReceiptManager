-- create_initial_workspace: idempotent profile/workspace/membership creation
-- after signup (spec 5.2, 10.3, P0). Runs as the calling user (SECURITY
-- INVOKER, the default) so normal RLS policies apply; every insert here is
-- already permitted by the RLS policies in 20260817000009_rls.sql for
-- exactly this "create my own personal workspace" shape, so no privilege
-- escalation is needed.
create function public.create_initial_workspace(p_workspace_id uuid default null)
returns public.workspaces
language plpgsql
security invoker
as $$
declare
  v_workspace_id uuid;
  v_workspace public.workspaces;
begin
  insert into public.profiles (id)
  values (auth.uid())
  on conflict (id) do nothing;

  select w.* into v_workspace
  from public.workspaces w
  join public.workspace_members m on m.workspace_id = w.id
  where m.user_id = auth.uid() and w.type = 'personal'
  order by w.created_at asc
  limit 1;

  if found then
    return v_workspace;
  end if;

  -- Deliberately not "insert ... returning * into v_workspace" here: the
  -- workspaces SELECT policy requires workspace_members to already show
  -- this user as a member, which is only true after the second insert
  -- below. Using RETURNING before that membership row exists makes
  -- Postgres reject the whole insert with "new row violates row-level
  -- security policy" (RETURNING is subject to the SELECT policy too, not
  -- just the INSERT WITH CHECK policy) - caught by the local RLS test
  -- suite in supabase/tests/.
  v_workspace_id := coalesce(p_workspace_id, gen_random_uuid());

  insert into public.workspaces (id, name, type, owner_user_id)
  values (v_workspace_id, 'My Workspace', 'personal', auth.uid());

  insert into public.workspace_members (workspace_id, user_id, role)
  values (v_workspace_id, auth.uid(), 'owner');

  select w.* into v_workspace from public.workspaces w where w.id = v_workspace_id;

  return v_workspace;
end;
$$;

grant execute on function public.create_initial_workspace(uuid) to authenticated;

-- search_purchases: structured filters + full-text search scoped to
-- workspace, including joined item name/model/serial (spec 5.10, 10.4).
-- SECURITY INVOKER so RLS still applies; the explicit is_workspace_member
-- check is defense-in-depth, not the only guard.
create function public.search_purchases(
  p_workspace_id uuid,
  p_query text default null,
  p_purposes text[] default null,
  p_date_from date default null,
  p_date_to date default null,
  p_folder_id uuid default null,
  p_tag_id uuid default null,
  p_min_amount numeric default null,
  p_max_amount numeric default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof public.purchases
language sql
stable
security invoker
as $$
  select distinct p.*
  from public.purchases p
  left join public.purchase_purposes pp on pp.purchase_id = p.id
  left join public.purchase_tags pt on pt.purchase_id = p.id
  left join public.purchase_items pi on pi.purchase_id = p.id
  left join public.items i on i.id = pi.item_id
  where public.is_workspace_member(p_workspace_id)
    and p.workspace_id = p_workspace_id
    and (p_purposes is null or pp.purpose = any(p_purposes))
    and (p_date_from is null or p.purchase_date >= p_date_from)
    and (p_date_to is null or p.purchase_date <= p_date_to)
    and (p_folder_id is null or p.folder_id = p_folder_id)
    and (p_tag_id is null or pt.tag_id = p_tag_id)
    and (p_min_amount is null or p.total_amount >= p_min_amount)
    and (p_max_amount is null or p.total_amount <= p_max_amount)
    and (p_status is null or p.status = p_status)
    and (
      p_query is null
      or p.search_vector @@ websearch_to_tsquery('english', p_query)
      or i.search_vector @@ websearch_to_tsquery('english', p_query)
    )
  order by p.purchase_date desc nulls last, p.created_at desc
  limit p_limit offset p_offset;
$$;

grant execute on function public.search_purchases(
  uuid, text, text[], date, date, uuid, uuid, numeric, numeric, text, integer, integer
) to authenticated;

-- delete_account_data: server-controlled cascade cleanup (spec 5.14, 10.3,
-- P0). Callable only by the service role (an Edge Function verifies the
-- requesting user out-of-band, deletes the auth.users row, then calls this
-- with elevated rights) because by the time storage cleanup runs the user's
-- own session may already be gone. Returns the storage paths the caller
-- must delete from the Storage API; Postgres cannot reach into Storage
-- itself.
create function public.delete_account_data(p_user_id uuid)
returns table (storage_path text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select a.storage_path
  from public.attachments a
  where a.workspace_id in (
    select w.id from public.workspaces w
    join public.workspace_members m on m.workspace_id = w.id
    where m.user_id = p_user_id
  );

  delete from public.workspaces w
  where w.id in (
    select w2.id from public.workspaces w2
    join public.workspace_members m on m.workspace_id = w2.id
    where m.user_id = p_user_id
  );
  -- ON DELETE CASCADE on every child table (purchases, items, attachments,
  -- warranties, folders, tags, ...) removes the rest.

  delete from public.profiles where id = p_user_id;
end;
$$;

revoke all on function public.delete_account_data(uuid) from public, authenticated, anon;
grant execute on function public.delete_account_data(uuid) to service_role;
