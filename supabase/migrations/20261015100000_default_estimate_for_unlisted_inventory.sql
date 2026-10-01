-- Ensure every new inventory batch receives an estimate, including products
-- without an exact product-name match. Exact catalogue matches still win.
insert into public.inventory_spoilage_profiles (
  id, display_name, aliases, shelf_life_days, conditions, cultivar_note,
  reference_version, source_title, source_url, enabled
)
values (
  'unlisted_default_3_days',
  'Unlisted product (3-day default)',
  array[]::text[],
  3,
  'Generic fallback; ordinary ambient storage assumed without a product-specific condition.',
  'Three days is a simple application default, not a product-specific research result. Replace with a product-specific profile when evidence is added.',
  1,
  'PhilMech: Evaporative coolers prolong shelf-life of veggies',
  'https://www.philmech.gov.ph/?action=storyFullView&page=stories&recordID=NE08010151&storyCateg=News&storyMonth=1&storyYear=2008',
  true
)
on conflict (id) do update set
  display_name = excluded.display_name,
  aliases = excluded.aliases,
  shelf_life_days = excluded.shelf_life_days,
  conditions = excluded.conditions,
  cultivar_note = excluded.cultivar_note,
  reference_version = excluded.reference_version,
  source_title = excluded.source_title,
  source_url = excluded.source_url,
  enabled = excluded.enabled;

create or replace function public.resolve_spoilage_profile(p_name text)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare
  normalized_name text := public.normalize_spoilage_product_name(p_name);
  matched_profile text;
begin
  select profile.id into matched_profile
    from public.inventory_spoilage_profiles profile
    cross join lateral unnest(array_prepend(profile.display_name, profile.aliases)) alias_name
   where profile.id <> 'unlisted_default_3_days'
     and public.normalize_spoilage_product_name(alias_name) = normalized_name
     and profile.enabled
   order by profile.id
   limit 1;

  return coalesce(matched_profile, 'unlisted_default_3_days');
end;
$$;

-- Assign defaults to existing items and batches without changing their dates
-- or quantities. Batches with known age immediately gain a calculated date;
-- unknown-age reversals and adjustments remain undated until their origin is known.
update public.inventory item
   set spoilage_profile_id = public.resolve_spoilage_profile(item.item_name)
 where item.spoilage_profile_id is distinct from public.resolve_spoilage_profile(item.item_name);

insert into public.inventory_stock_batch_audit (
  batch_id, previous_received_on, new_received_on, previous_harvest_on,
  new_harvest_on, previous_profile_id, new_profile_id, action, changed_by
)
select batch.id, batch.received_on, batch.received_on, batch.harvest_on,
       batch.harvest_on, batch.profile_id, item.spoilage_profile_id,
       'automatic_profile', null
  from public.inventory_stock_batches batch
  join public.inventory item on item.id = batch.inventory_id
 where batch.profile_id is null
   and item.spoilage_profile_id is not null;

update public.inventory_stock_batches batch
   set profile_id = item.spoilage_profile_id
  from public.inventory item
 where item.id = batch.inventory_id
   and batch.profile_id is null
   and item.spoilage_profile_id is not null;

update public.inventory_stock_batches batch
   set reference_profile_name = profile.display_name
  from public.inventory_spoilage_profiles profile
 where profile.id = batch.profile_id
   and batch.reference_profile_name is null;

notify pgrst, 'reload schema';
