begin;

create or replace function public.generate_assigned_planting_name(
  p_profile_key text, p_crop_name text, p_batch_code text
) returns text
language plpgsql
immutable
set search_path=public
as $$
declare
  seed_name text;
  names text[];
  suffix text;
  number_value bigint;
  name_index integer;
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
    when 'sitaw' then array[
      'Sunny','Morning','Backyard','Family','Riverside','Hillside','North Field','South Field',
      'East Row','West Row','Green Row','Long Row','Open Field','Farmyard','Sunrise','Sunset',
      'Village','Upper Field','Lower Field','Creekside','Bamboo Trellis','Kitchen Garden',
      'Garden Gate','Coconut Side','Stone Path','New Field','Riverbank','Home Garden',
      'Trellis Side','Market Garden','Meadow','Harvest Lane'
    ]
    when 'calamansi' then array[
      'Sunny','Garden','Orchard','Backyard','Family','Riverside','Hillside','North Garden',
      'South Garden','East Grove','West Grove','Morning','Sunrise','Sunset','Creekside',
      'Farmyard','Home Garden','Upper Garden','Lower Garden','Coconut Grove','Garden Gate',
      'Kitchen Garden','Village','Bamboo Side','Riverbank','Stone Path','New Orchard',
      'Meadow','Harvest Lane','Fieldside','Rainy Day','Sunlit Grove'
    ]
    when 'peanut' then array[
      'Sunny','Garden','Field','Backyard','Family','Riverside','Hillside','North Field',
      'South Field','East Row','West Row','Upper Field','Lower Field','Open Field','Farmyard',
      'Morning','Sunrise','Sunset','Village','Home Garden','Kitchen Garden','Riverbank',
      'Creekside','Coconut Side','Field Gate','Garden Gate','New Field','Meadow','Harvest Lane',
      'South Garden','Rainy Day','Stone Path'
    ]
    else array['Garden']
  end;

  name_index := mod(number_value,cardinality(names))::integer + 1;
  return names[name_index] || ' ' || seed_name;
end;
$$;

-- Reassign only the system-generated name field. Farmer-chosen names stay intact.
select set_config('app.crop_planting_name_rpc','on',true);
update public.crops c
set assigned_planting_name = public.generate_assigned_planting_name(
      c.crop_profile_key, c.crop_name, c.batch_code),
    updated_at = now()
where c.custom_planting_name is null
  and c.assigned_planting_name is not null;

commit;
