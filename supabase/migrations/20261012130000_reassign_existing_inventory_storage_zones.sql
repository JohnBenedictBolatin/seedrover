-- Reassign every existing inventory item to one of the five shared storage zones.
-- Category and item type determine the zone so custom legacy labels are cleared.
update public.inventory
set storage_location = case
  when lower(category) in ('leafy vegetables', 'herbs') then 'Leafy Greens Chiller'
  when lower(category) = 'fruits'
    or lower(item_name) in ('mushroom', 'bamboo shoots', 'snow peas', 'green peas')
    then 'Harvest Cooler'
  when lower(category) = 'root crops' then 'Root Crop Cellar'
  when lower(category) = 'prepared produce' then 'Packing Shed'
  else 'Produce Crate Bay'
end;
