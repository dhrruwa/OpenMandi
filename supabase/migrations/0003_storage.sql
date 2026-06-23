-- ============================================================
-- OpenMandi — storage buckets + policies.
--   listing-photos : public read, owner-scoped write (path = <uid>/...)
--   kyc-docs       : PRIVATE. Never public. Access only via short-lived
--                    signed URLs; rows readable by owner or admin.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('listing-photos', 'listing-photos', true,  5242880,
     array['image/jpeg','image/png','image/webp']),
  ('kyc-docs',       'kyc-docs',       false, 8388608,
     array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

-- ---------- listing-photos ----------
create policy "listing photos are public" on storage.objects
  for select using (bucket_id = 'listing-photos');

create policy "users upload own listing photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-photos'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users manage own listing photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'listing-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "users delete own listing photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- kyc-docs (private) ----------
create policy "owner reads own kyc docs" on storage.objects
  for select to authenticated
  using (bucket_id = 'kyc-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

create policy "owner uploads own kyc docs" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'kyc-docs'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner replaces own kyc docs" on storage.objects
  for update to authenticated
  using (bucket_id = 'kyc-docs'
         and (storage.foldername(name))[1] = auth.uid()::text);
