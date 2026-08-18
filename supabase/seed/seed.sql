-- Non-sensitive demo data for local development (spec section 24 developer
-- checklist). Safe to run against a fresh `supabase db reset`. Does not
-- create an auth.users row: sign up a real user first (Supabase Auth
-- owns that table), then replace :demo_user_id below with that user's id
-- and run this file, e.g.:
--   psql "$DATABASE_URL" -v demo_user_id="'<uuid-from-auth.users>'" -f supabase/seed/seed.sql

\set demo_workspace '''00000000-0000-0000-0000-000000000001'''
\set demo_purchase_1 '''00000000-0000-0000-0000-000000000101'''
\set demo_purchase_2 '''00000000-0000-0000-0000-000000000102'''
\set demo_item_1 '''00000000-0000-0000-0000-000000000201'''

insert into public.workspaces (id, name, type, owner_user_id)
values (:demo_workspace, 'Demo Workspace', 'personal', :demo_user_id)
on conflict (id) do nothing;

insert into public.workspace_members (workspace_id, user_id, role)
values (:demo_workspace, :demo_user_id, 'owner')
on conflict do nothing;

insert into public.purchases (id, workspace_id, merchant_name, purchase_date, total_amount, gst_amount, currency, status, category)
values
  (:demo_purchase_1, :demo_workspace, 'Bunnings Warehouse', '2026-08-13', 249.00, 22.64, 'AUD', 'saved', 'Tools'),
  (:demo_purchase_2, :demo_workspace, 'Officeworks', '2026-07-02', 89.95, 8.18, 'AUD', 'saved', 'Supplies')
on conflict (id) do nothing;

insert into public.purchase_purposes (purchase_id, purpose) values
  (:demo_purchase_1, 'tax'),
  (:demo_purchase_1, 'warranty'),
  (:demo_purchase_1, 'asset'),
  (:demo_purchase_2, 'tax')
on conflict do nothing;

insert into public.items (id, workspace_id, name, brand, model, serial_number, original_value, location)
values (:demo_item_1, :demo_workspace, 'Impact Driver', 'Makita', 'DTD171', 'SN-DEMO-0001', 249.00, 'Work Van')
on conflict (id) do nothing;

insert into public.purchase_items (purchase_id, item_id)
values (:demo_purchase_1, :demo_item_1)
on conflict do nothing;

insert into public.warranties (id, workspace_id, item_id, provider, start_date, expiry_date, reminder_enabled)
values ('00000000-0000-0000-0000-000000000301', :demo_workspace, :demo_item_1, 'Makita Australia', '2026-08-13', '2029-08-13', true)
on conflict (id) do nothing;

-- No attachment rows: seeding fake storage objects would require a real
-- file in the proof-files bucket, which this script deliberately doesn't
-- create. Add a real receipt through the app to see the full flow.
