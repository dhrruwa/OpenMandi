-- ============================================================
-- OpenMandi — seed (master data + recent mandi prices).
-- Users are created via real sign-up (email OTP), so no auth.users are
-- seeded here. After signing up one farmer + one dealer you can walk the
-- full loop against this master data.
-- ============================================================

insert into public.crops (name, emoji, category, default_unit, names_i18n) values
  ('Tomato',  '🍅', 'vegetable', 'quintal', '{"hi":"टमाटर","kn":"ಟೊಮ್ಯಾಟೊ"}'),
  ('Onion',   '🧅', 'vegetable', 'quintal', '{"hi":"प्याज","kn":"ಈರುಳ್ಳಿ"}'),
  ('Potato',  '🥔', 'vegetable', 'quintal', '{"hi":"आलू","kn":"ಆಲೂಗಡ್ಡೆ"}'),
  ('Brinjal', '🍆', 'vegetable', 'quintal', '{"hi":"बैंगन","kn":"ಬದನೆಕಾಯಿ"}'),
  ('Chilli',  '🌶️', 'vegetable', 'quintal', '{"hi":"मिर्च","kn":"ಮೆಣಸಿನಕಾಯಿ"}'),
  ('Carrot',  '🥕', 'vegetable', 'quintal', '{"hi":"गाजर","kn":"ಕ್ಯಾರೆಟ್"}'),
  ('Cabbage', '🥬', 'vegetable', 'quintal', '{"hi":"पत्तागोभी","kn":"ಎಲೆಕೋಸು"}'),
  ('Okra',    '🫛', 'vegetable', 'quintal', '{"hi":"भिंडी","kn":"ಬೆಂಡೆಕಾಯಿ"}')
on conflict (name) do nothing;

-- recent mandi prices (Kolar APMC) for the trend charts
insert into public.price_records (crop_id, market, price_min, price_max, price_modal, date, source)
select c.id, 'Kolar APMC', p.modal - 150, p.modal + 200, p.modal, current_date, 'agmarknet'
from public.crops c
join (values
  ('Tomato', 2400), ('Onion', 1850), ('Potato', 1320), ('Brinjal', 2100),
  ('Chilli', 9800), ('Carrot', 1700), ('Cabbage', 980), ('Okra', 3200)
) as p(name, modal) on p.name = c.name
on conflict (crop_id, market, date) do nothing;
