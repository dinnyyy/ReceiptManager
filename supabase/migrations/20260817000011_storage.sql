-- Private storage bucket + RLS (spec 6.5, 10.1, 10.2, 14). Path convention:
--   {workspace_id}/purchases/{purchase_id}/{attachment_id}.{ext}
--   {workspace_id}/items/{item_id}/{attachment_id}.{ext}
-- storage.foldername(name) splits the object path on '/' into an array, so
-- (storage.foldername(name))[1] is the workspace_id segment. Membership is
-- checked against that segment, never trusted from client-supplied
-- filenames or headers.

insert into storage.buckets (id, name, public)
values ('proof-files', 'proof-files', false)
on conflict (id) do nothing;

create policy "proof-files: members can read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'proof-files'
    and public.is_workspace_member((storage.foldername(name))[1]::uuid)
  );

create policy "proof-files: members can upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'proof-files'
    and public.is_workspace_member((storage.foldername(name))[1]::uuid)
  );

create policy "proof-files: members can delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'proof-files'
    and public.is_workspace_member((storage.foldername(name))[1]::uuid)
  );

-- No update policy: attachments are immutable evidence. Replace by
-- deleting and re-uploading under a new attachment UUID.
