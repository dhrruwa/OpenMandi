-- Public bucket for chat voice notes (WhatsApp-style). Owner-scoped uploads
-- (path = <uid>/...), public read for playback.
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-voice', 'chat-voice', true, 10485760)
on conflict (id) do nothing;

drop policy if exists "chat voice public read" on storage.objects;
create policy "chat voice public read" on storage.objects
  for select using (bucket_id = 'chat-voice');

drop policy if exists "chat voice owner upload" on storage.objects;
create policy "chat voice owner upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-voice'
              and (storage.foldername(name))[1] = auth.uid()::text);
