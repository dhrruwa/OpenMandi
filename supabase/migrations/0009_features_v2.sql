-- Alter message_type enum to support audio messages
-- In Postgres, ADD VALUE cannot run inside a transaction block, so we run it cleanly.
ALTER TYPE public.message_type ADD VALUE IF NOT EXISTS 'audio';

-- Extend listings table
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS pincode text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS village text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS taluk text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS district text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE public.listings ADD COLUMN IF NOT EXISTS country text;

-- Extend messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS transcript text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS translated_text text;

-- Create dealer preferred locations table
CREATE TABLE IF NOT EXISTS public.dealer_preferred_locations (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid not null references public.users(id) on delete cascade,
  label text not null,
  lat double precision not null,
  lng double precision not null,
  radius_km int not null default 50,
  created_at timestamptz not null default now()
);

-- Enable RLS and define policies
ALTER TABLE public.dealer_preferred_locations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'dealer_preferred_locations' AND policyname = 'dealer_prefloc_all'
  ) THEN
    CREATE POLICY dealer_prefloc_all ON public.dealer_preferred_locations
      FOR ALL TO authenticated
      USING (dealer_id = auth.uid() or public.is_admin())
      WITH CHECK (dealer_id = auth.uid());
  END IF;
END
$$;

-- Create chat-voice storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('chat-voice', 'chat-voice', true, 10485760,
     ARRAY['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/webm', 'audio/m4a', 'audio/x-m4a'])
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'chat voice messages are public'
  ) THEN
    CREATE POLICY "chat voice messages are public" ON storage.objects
      FOR SELECT USING (bucket_id = 'chat-voice');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'users upload own chat voice'
  ) THEN
    CREATE POLICY "users upload own chat voice" ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'chat-voice'
                  AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'users delete own chat voice'
  ) THEN
    CREATE POLICY "users delete own chat voice" ON storage.objects
      FOR DELETE TO authenticated
      USING (bucket_id = 'chat-voice'
             AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END
$$;

-- Distance helper (Haversine formula in km)
CREATE OR REPLACE FUNCTION public.haversine_distance(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
) RETURNS double precision LANGUAGE sql PURE AS $$
  SELECT 6371.0 * 2.0 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2.0), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lon2 - lon1) / 2.0), 2)
  ));
$$;

-- Matching engine trigger function
CREATE OR REPLACE FUNCTION public.match_listing_dealers()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_crop_name text;
  v_crop_emoji text;
  v_crop_hi text;
  v_crop_kn text;
  v_crop_te text;
  v_crop_ta text;
  v_crop_ml text;
  v_crop_mr text;
  v_crop_gu text;
  v_crop_bn text;
  v_crop_pa text;
  v_crop_or text;
  v_crop_as text;
  v_crop_ur text;
  v_pref_lang text;
  v_dealer_count int := 0;
  v_msg_dealer text;
  v_msg_farmer text;
  r record;
BEGIN
  -- load crop details
  SELECT name, emoji, 
         coalesce(names_i18n->>'hi', name),
         coalesce(names_i18n->>'kn', name),
         coalesce(names_i18n->>'te', name),
         coalesce(names_i18n->>'ta', name),
         coalesce(names_i18n->>'ml', name),
         coalesce(names_i18n->>'mr', name),
         coalesce(names_i18n->>'gu', name),
         coalesce(names_i18n->>'bn', name),
         coalesce(names_i18n->>'pa', name),
         coalesce(names_i18n->>'or', name),
         coalesce(names_i18n->>'as', name),
         coalesce(names_i18n->>'ur', name)
    INTO v_crop_name, v_crop_emoji, 
         v_crop_hi, v_crop_kn, v_crop_te, v_crop_ta, v_crop_ml, v_crop_mr, v_crop_gu, v_crop_bn, v_crop_pa, v_crop_or, v_crop_as, v_crop_ur
  FROM public.crops WHERE id = new.crop_id;

  -- loop over dealer preferred locations
  FOR r IN
    SELECT dpl.dealer_id, dpl.radius_km, u.preferred_language,
           public.haversine_distance(new.lat, new.lng, dpl.lat, dpl.lng) AS dist
    FROM public.dealer_preferred_locations dpl
    JOIN public.users u ON u.id = dpl.dealer_id
  LOOP
    IF r.dist <= r.radius_km THEN
      v_dealer_count := v_dealer_count + 1;
      
      -- construct localized message for the dealer
      v_msg_dealer := CASE r.preferred_language
        WHEN 'kn' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_kn || ' ' || round(r.dist)::text || ' km ದೂರದಲ್ಲಿ ಲಭ್ಯವಿದೆ.')
        WHEN 'hi' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_hi || ' ' || round(r.dist)::text || ' km दूर उपलब्ध है।')
        WHEN 'te' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_te || ' ' || round(r.dist)::text || ' km దూరంలో అందుబాటులో ఉంది.')
        WHEN 'ta' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_ta || ' ' || round(r.dist)::text || ' km தொலைவில் உள்ளது.')
        WHEN 'ml' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_ml || ' ' || round(r.dist)::text || ' km അകലെ ലഭ്യമാണ്.')
        WHEN 'mr' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_mr || ' ' || round(r.dist)::text || ' km अंतरावर उपलब्ध आहे.')
        WHEN 'gu' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_gu || ' ' || round(r.dist)::text || ' km દૂર ઉપલબ્ધ છે.')
        WHEN 'bn' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_bn || ' ' || round(r.dist)::text || ' কিমি দূরে পাওয়া যাচ্ছে।')
        WHEN 'pa' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_pa || ' ' || round(r.dist)::text || ' ਕਿਲੋਮੀਟਰ ਦੂਰ ਉਪਲਬਧ ਹੈ।')
        WHEN 'or' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_or || ' ' || round(r.dist)::text || ' କିଲୋମିଟର ଦୂରରେ ଉପଲବ୍ଧ |')
        WHEN 'as' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_as || ' ' || round(r.dist)::text || ' কিমি দূৰত উপলব্ধ।')
        WHEN 'ur' THEN (new.quantity || ' ' || new.unit || ' ' || v_crop_ur || ' ' || round(r.dist)::text || ' کلو میٹر دور دستیاب ہے۔')
        ELSE (new.quantity || ' ' || new.unit || ' ' || v_crop_name || ' available ' || round(r.dist)::text || ' km away.')
      END;

      -- send notification to dealer
      PERFORM public.notify(
        r.dealer_id,
        'offer'::public.notif_type,
        CASE r.preferred_language
          WHEN 'kn' THEN 'ಹೊಸ ಬೆಳೆ ಲಭ್ಯವಿದೆ'
          WHEN 'hi' THEN 'नई फसल उपलब्ध है'
          WHEN 'te' THEN 'కొత్త పంట అందుబాటులో ఉంది'
          WHEN 'ta' THEN 'புதிய பயிர் கிடைக்கிறது'
          WHEN 'ml' THEN 'പുതിയ വിള ലഭ്യമാണ്'
          WHEN 'mr' THEN 'नवीन पीक उपलब्ध आहे'
          WHEN 'gu' THEN 'નવો પાક ઉપલબ્ધ છે'
          WHEN 'bn' THEN 'নতুন ফসল উপলব্ধ'
          WHEN 'pa' THEN 'ਨਵੀਂ ਫਸਲ ਉਪਲਬਧ ਹੈ'
          WHEN 'or' THEN 'ନୂତନ ଫସଲ ଉପଲବ୍ଧ'
          WHEN 'as' THEN 'নতুন শস্য উপলব্ধ'
          WHEN 'ur' THEN 'نئی فصل دستیاب ہے'
          ELSE 'New crop available'
        END,
        v_msg_dealer,
        jsonb_build_object('listing_id', new.id, 'crop', v_crop_name, 'distance_km', round(r.dist))
      );
    END IF;
  END LOOP;

  -- notify farmer about matching dealers
  IF v_dealer_count > 0 THEN
    SELECT preferred_language INTO v_pref_lang FROM public.users WHERE id = new.farmer_id;
    
    v_msg_farmer := CASE v_pref_lang
      WHEN 'kn' THEN (v_dealer_count || ' ಖರೀದಿದಾರರು ನಿಮ್ಮ ಬೆಳೆಗೆ ಆಸಕ್ತಿ ಹೊಂದಿದ್ದಾರೆ.')
      WHEN 'hi' THEN (v_dealer_count || ' व्यापारी आपकी फसल में रुचि रखते हैं।')
      WHEN 'te' THEN (v_dealer_count || ' డీలర్లు మీ పంటపై ಆసక్తి చూపుతున్నారు.')
      WHEN 'ta' THEN (v_dealer_count || ' வியாபாரிகள் உங்கள் பயிரில் ஆர்வம் காட்டுகின்றனர்.')
      WHEN 'ml' THEN (v_dealer_count || ' വ്യാപാരികൾ നിങ്ങളുടെ വിളയിൽ താല്പര്യം കാണിക്കുന്നു.')
      WHEN 'mr' THEN (v_dealer_count || ' व्यापारी आपल्या पिकात रस दाखवत आहेत.')
      WHEN 'gu' THEN (v_dealer_count || ' વેપારીઓ તમારા પાકમાં રસ દર્શાવી રહ્યા છે.')
      WHEN 'bn' THEN (v_dealer_count || ' জন ব্যবসায়ী আপনার ফসলে আগ্রহী।')
      WHEN 'pa' THEN (v_dealer_count || ' ਡੀਲਰ ਤੁਹਾਡੀ ਫਸਲ ਵਿੱਚ ਦਿਲਚਸਪੀ ਰੱਖਦੇ ਹਨ।')
      WHEN 'or' THEN (v_dealer_count || ' ବ୍ୟବସାୟୀ ଆପଣଙ୍କ ଫସଲରେ ଆଗ୍ରହୀ ଅଛନ୍ତି।')
      WHEN 'as' THEN (v_dealer_count || ' গৰাকী ব্যৱসায়ী আপোনাৰ শস্যৰ প্ৰতি আগ্ৰহী।')
      WHEN 'ur' THEN (v_dealer_count || ' ڈیلر آپ کی فصل میں دلچسپی رکھتے ہیں۔')
      ELSE (v_dealer_count || ' dealers are interested in your listing.')
    END;

    PERFORM public.notify(
      new.farmer_id,
      'system'::public.notif_type,
      CASE v_pref_lang
        WHEN 'kn' THEN 'ಖರೀದಿದಾರರ ಆಸಕ್ತಿ'
        WHEN 'hi' THEN 'व्यापारी रुचि'
        WHEN 'te' THEN 'డీలర్ ఆసక్తి'
        WHEN 'ta' THEN 'வியாபாரி ஆர்வம்'
        WHEN 'ml' THEN 'വ്യാപാരി താല്പര്യം'
        WHEN 'mr' THEN 'व्यापारी आवड'
        WHEN 'gu' THEN 'વેપારી રસ'
        WHEN 'bn' THEN 'ব্যবসায়ী আগ্রহ'
        WHEN 'pa' THEN 'ਡੀਲਰ ਦੀ ਦਿਲਚਸਪੀ'
        WHEN 'or' THEN 'ବ୍ୟବସାୟୀଙ୍କ ଆଗ୍ରಹ'
        WHEN 'as' THEN 'ব্যৱসায়ীৰ আগ্ৰহ'
        WHEN 'ur' THEN 'ڈیلر کی دلچسپی'
        ELSE 'Dealer Match'
      END,
      v_msg_farmer,
      jsonb_build_object('listing_id', new.id, 'matches', v_dealer_count)
    );
  END IF;

  RETURN new;
END;
$$;

-- Trigger definition
CREATE OR REPLACE TRIGGER trg_match_listing_dealers
  AFTER INSERT ON public.listings
  FOR EACH ROW EXECUTE FUNCTION public.match_listing_dealers();

-- Expose new table to PostgREST
GRANT SELECT, INSERT, UPDATE, DELETE ON public.dealer_preferred_locations TO authenticated;
