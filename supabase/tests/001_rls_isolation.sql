-- RLS negative tests (spec 14.1, 17.2): two workspaces, two users, and a
-- proof that user B cannot read, update, delete, or forge-insert into user
-- A's data through any table or RPC this schema exposes. Run via
-- scripts/db_test.sh against a scratch Postgres database that has already
-- had scripts/local_pg_stub.sql + supabase/migrations/*.sql applied.
--
-- Convention: RAISE NOTICE 'PASS: ...' on success, RAISE EXCEPTION
-- 'FAIL: ...' on failure. The driver script runs with ON_ERROR_STOP=1, so
-- any FAIL (or any unexpected error) stops the whole suite with a non-zero
-- exit code.
--
-- Test-only workspace ids are stashed in a temp table (test_ctx) rather
-- than psql variables: psql's ":'name'" substitution does not reach inside
-- dollar-quoted ($$ ... $$) plpgsql bodies, and most of the assertions
-- below need to run inside a DO block to compare/branch on values.

create temporary table test_ctx (key text primary key, value uuid);
-- Temp tables live outside the public schema's default privileges, and the
-- rest of this script runs as the "authenticated" role, so grant access
-- explicitly while we're still the connecting superuser.
grant select, insert, update, delete on test_ctx to authenticated;

-- Seed two fake auth.users as the superuser (mirrors Supabase Auth writing
-- to auth.users directly; the app never does this itself).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'user-a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'user-b@example.com');

-- ---------------------------------------------------------------------
-- As user A: create workspace, a purchase, an item, an attachment.
-- ---------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into test_ctx (key, value) select 'workspace_a', (public.create_initial_workspace()).id;

insert into public.purchases (id, workspace_id, merchant_name, purchase_date, total_amount, status)
select '33333333-3333-3333-3333-333333333333', value, 'Bunnings Warehouse', '2026-08-13', 249.00, 'saved'
from test_ctx where key = 'workspace_a';

insert into public.purchase_purposes (purchase_id, purpose) values
  ('33333333-3333-3333-3333-333333333333', 'tax'),
  ('33333333-3333-3333-3333-333333333333', 'warranty');

insert into public.items (id, workspace_id, name, serial_number)
select '44444444-4444-4444-4444-444444444444', value, 'Makita Impact Driver', 'SN-A-0001'
from test_ctx where key = 'workspace_a';

insert into public.purchase_items (purchase_id, item_id) values
  ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444');

insert into public.attachments (id, workspace_id, purchase_id, type, storage_path, mime_type)
select
  '55555555-5555-5555-5555-555555555555', value, '33333333-3333-3333-3333-333333333333',
  'receipt_image', value || '/purchases/33333333-3333-3333-3333-333333333333/55555555-5555-5555-5555-555555555555.jpg',
  'image/jpeg'
from test_ctx where key = 'workspace_a';

insert into storage.objects (bucket_id, name, owner)
select
  'proof-files',
  value || '/purchases/33333333-3333-3333-3333-333333333333/55555555-5555-5555-5555-555555555555.jpg',
  '11111111-1111-1111-1111-111111111111'
from test_ctx where key = 'workspace_a';

do $$
begin
  if (select count(*) from public.purchases where id = '33333333-3333-3333-3333-333333333333') = 1 then
    raise notice 'PASS: user A can see their own purchase';
  else
    raise exception 'FAIL: user A cannot see their own just-inserted purchase';
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- As user B: separate workspace, then attempt every access path into A's data.
-- ---------------------------------------------------------------------
reset request.jwt.claim.sub;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

insert into test_ctx (key, value) select 'workspace_b', (public.create_initial_workspace()).id;

do $$
declare
  v_a uuid;
  v_b uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  select value into v_b from test_ctx where key = 'workspace_b';
  if v_a = v_b then
    raise exception 'FAIL: user A and user B were assigned the same workspace id';
  else
    raise notice 'PASS: user A and user B have distinct workspaces';
  end if;
end
$$;

do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  if (select count(*) from public.purchases where workspace_id = v_a) = 0 then
    raise notice 'PASS: user B sees zero purchases in user A workspace';
  else
    raise exception 'FAIL: user B can see purchases belonging to user A workspace';
  end if;
end
$$;

do $$
begin
  if (select count(*) from public.purchases where id = '33333333-3333-3333-3333-333333333333') = 0 then
    raise notice 'PASS: user B cannot select user A purchase by primary key';
  else
    raise exception 'FAIL: user B selected user A purchase directly by id';
  end if;
end
$$;

do $$
declare
  v_rows integer;
begin
  update public.purchases set merchant_name = 'hacked-by-b'
  where id = '33333333-3333-3333-3333-333333333333';
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise notice 'PASS: user B update against user A purchase affected zero rows';
  else
    raise exception 'FAIL: user B managed to update user A purchase (% rows)', v_rows;
  end if;
end
$$;

do $$
declare
  v_rows integer;
begin
  delete from public.purchases where id = '33333333-3333-3333-3333-333333333333';
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise notice 'PASS: user B delete against user A purchase affected zero rows';
  else
    raise exception 'FAIL: user B managed to delete user A purchase (% rows)', v_rows;
  end if;
end
$$;

-- Forging workspace_id on insert must fail the RLS WITH CHECK clause.
do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  begin
    insert into public.purchases (id, workspace_id, merchant_name)
    values ('66666666-6666-6666-6666-666666666666', v_a, 'forged-by-b');
    raise exception 'FAIL: user B inserted a purchase into user A workspace';
  exception
    when insufficient_privilege then
      raise notice 'PASS: user B insert into user A workspace was rejected by RLS';
  end;
end
$$;

do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  if (select count(*) from public.items where workspace_id = v_a) = 0 then
    raise notice 'PASS: user B sees zero items in user A workspace';
  else
    raise exception 'FAIL: user B can see items belonging to user A workspace';
  end if;
end
$$;

do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  if (select count(*) from public.attachments where workspace_id = v_a) = 0 then
    raise notice 'PASS: user B sees zero attachments in user A workspace';
  else
    raise exception 'FAIL: user B can see attachments belonging to user A workspace';
  end if;
end
$$;

do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  if (select count(*) from storage.objects where name like v_a::text || '/%') = 0 then
    raise notice 'PASS: user B sees zero storage.objects under user A workspace path';
  else
    raise exception 'FAIL: user B can list storage.objects under user A workspace path';
  end if;
end
$$;

do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('proof-files', v_a || '/purchases/forged/forged.jpg', '22222222-2222-2222-2222-222222222222');
    raise exception 'FAIL: user B uploaded a storage object under user A workspace path';
  exception
    when insufficient_privilege then
      raise notice 'PASS: user B storage upload into user A workspace path was rejected by RLS';
  end;
end
$$;

-- search_purchases RPC must not leak rows even if the caller passes
-- another workspace's id as the parameter.
do $$
declare
  v_a uuid;
begin
  select value into v_a from test_ctx where key = 'workspace_a';
  if (select count(*) from public.search_purchases(v_a)) = 0 then
    raise notice 'PASS: search_purchases(workspace_a) returns nothing when called as user B';
  else
    raise exception 'FAIL: search_purchases leaked user A rows to user B';
  end if;
end
$$;

-- delete_account_data must be unreachable from the client role entirely.
do $$
begin
  begin
    perform public.delete_account_data('11111111-1111-1111-1111-111111111111');
    raise exception 'FAIL: authenticated role was able to execute delete_account_data';
  exception
    when insufficient_privilege then
      raise notice 'PASS: authenticated role cannot execute delete_account_data';
  end;
end
$$;

reset role;
reset request.jwt.claim.sub;

-- ---------------------------------------------------------------------
-- Back as user A: confirm nothing user B did actually changed the record.
-- ---------------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  v_merchant text;
begin
  select merchant_name into v_merchant from public.purchases where id = '33333333-3333-3333-3333-333333333333';
  if v_merchant = 'Bunnings Warehouse' then
    raise notice 'PASS: user A purchase is untouched after every user B attempt';
  else
    raise exception 'FAIL: user A purchase was mutated (merchant_name = %)', v_merchant;
  end if;
end
$$;

reset role;
reset request.jwt.claim.sub;

select 'ALL RLS ISOLATION TESTS PASSED' as result;
