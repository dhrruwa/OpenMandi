-- Reconcile columns that features (offer counts, voice chat, location) rely on
-- but that were missing on the deployed schema. Idempotent.

-- offer count + farmer location on listings
alter table public.listings add column if not exists offers   int not null default 0;
alter table public.listings add column if not exists pincode  text;
alter table public.listings add column if not exists village  text;
alter table public.listings add column if not exists taluk    text;
alter table public.listings add column if not exists district text;
alter table public.listings add column if not exists state    text;
alter table public.listings add column if not exists country  text;

-- voice message fields
alter table public.messages add column if not exists audio_url       text;
alter table public.messages add column if not exists transcript      text;
alter table public.messages add column if not exists translated_text text;
