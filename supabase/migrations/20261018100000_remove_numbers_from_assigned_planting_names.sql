begin;

create or replace function public.generate_assigned_planting_name(
  p_profile_key text, p_crop_name text, p_batch_code text
) returns text language plpgsql immutable set search_path=public as $$
declare seed_name text; names text[]; suffix text; number_value bigint; name_index integer;
begin
  seed_name := case lower(coalesce(p_profile_key,''))
    when 'sitaw' then 'Sitaw'
    when 'calamansi' then 'Calamansi'
    when 'peanut' then 'Peanut'
    else initcap(coalesce(nullif(btrim(p_crop_name),''),'Crop'))
  end;
  suffix := nullif(regexp_replace(coalesce(p_batch_code,''),'^.*-',''), '');
  if suffix ~ '^[0-9]+$' then
    number_value := suffix::bigint;
  else
    number_value := 0;
  end if;
  names := case lower(coalesce(p_profile_key,''))
    when 'sitaw' then array['Sunny','Garden','Backyard','Morning','Family']
    when 'calamansi' then array['Garden','Orchard','Backyard','Sunny','Family']
    when 'peanut' then array['Garden','Field','Backyard','Family','Sunny']
    else array['Garden']
  end;
  name_index := mod(number_value,cardinality(names))::integer + 1;
  return names[name_index] || ' ' || seed_name;
end $$;

-- Regenerate only the system-assigned names. Custom names belong to farmers and
-- remain untouched. Duplicate assigned names are allowed; the crop ID remains
-- the unique identifier for each planting.
select set_config('app.crop_planting_name_rpc','on',true);
update public.crops c
set assigned_planting_name = public.generate_assigned_planting_name(
      c.crop_profile_key, c.crop_name, c.batch_code),
    updated_at = now()
where c.custom_planting_name is null
  and c.assigned_planting_name is not null;

commit;
