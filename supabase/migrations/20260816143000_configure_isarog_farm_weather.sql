-- Isarog Farmhouse, Zone 3 Upper Lampog, Barangay Tinangis, Pili, Camarines Sur.
update public.farm_weather_settings
set
  latitude = 13.634597,
  longitude = 123.330082,
  pagasa_region = 'Bicol Region',
  pagasa_province = 'Camarines Sur',
  pagasa_municipality = 'Pili',
  timezone = 'Asia/Manila',
  updated_at = now()
where id = true;
