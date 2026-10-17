begin;

do $$
declare sitaw_name text; calamansi_name text; peanut_name text; other_name text;
begin
  sitaw_name := public.generate_assigned_planting_name('sitaw','Sitaw','CRP-2026-000083');
  calamansi_name := public.generate_assigned_planting_name('calamansi','Calamansi','CRP-2026-000084');
  peanut_name := public.generate_assigned_planting_name('peanut','Peanut','CRP-2026-000085');
  other_name := public.generate_assigned_planting_name(null,'Okra','CRP-2026-000086');

  if sitaw_name !~ '^(Sunny|Garden|Backyard|Morning|Family) Sitaw 83$' then
    raise exception 'Unexpected assigned Sitaw name: %', sitaw_name;
  end if;
  if calamansi_name !~ '^(Garden|Orchard|Backyard|Sunny|Family) Calamansi 84$' then
    raise exception 'Unexpected assigned Calamansi name: %', calamansi_name;
  end if;
  if peanut_name !~ '^(Garden|Field|Backyard|Family|Sunny) Peanut 85$' then
    raise exception 'Unexpected assigned Peanut name: %', peanut_name;
  end if;
  if other_name <> 'Garden Okra 86' then
    raise exception 'Unexpected fallback assigned name: %', other_name;
  end if;
  if sitaw_name = public.generate_assigned_planting_name('sitaw','Sitaw','CRP-2026-000088') then
    raise exception 'Assigned names should distinguish batch sequences.';
  end if;
end $$;

rollback;
