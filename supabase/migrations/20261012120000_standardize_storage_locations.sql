-- Keep the inventory's physical storage choices aligned across web and mobile.
update public.inventory
set storage_location = case
  when lower(category) in ('leafy vegetables', 'herbs') then 'Leafy Greens Chiller'
  when lower(category) = 'fruits'
    or lower(item_name) in ('mushroom', 'bamboo shoots', 'snow peas', 'green peas')
    then 'Harvest Cooler'
  when lower(category) = 'root crops' then 'Root Crop Cellar'
  when lower(category) = 'prepared produce' then 'Packing Shed'
  else 'Produce Crate Bay'
end
where storage_location in (
  'Cold Storage A',
  'Cold Storage B',
  'Cold Storage C',
  'Cold Storage D',
  'Crate Rack B',
  'Crate Rack C',
  'Crate Rack D',
  'Crate Rack E',
  'Dry Storage B',
  'Packing Bay A'
);
