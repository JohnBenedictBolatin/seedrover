alter table public.inventory
  drop constraint if exists inventory_category_allowed;

update public.inventory
set category = case
  when category = 'Seeds' then 'Legumes'
  when category = 'Fertilizer' then 'Herbs'
  when category = 'Consumables' then 'Fruit Vegetables'
  when category in ('Tools', 'Hardware') then 'Others'
  else category
end
where category in ('Seeds', 'Fertilizer', 'Consumables', 'Tools', 'Hardware');

alter table public.inventory
  add constraint inventory_category_allowed check (
    category in (
      'Leafy Vegetables',
      'Fruit Vegetables',
      'Legumes',
      'Root Crops',
      'Fruits',
      'Herbs',
      'Prepared Produce',
      'Others'
    )
  );
