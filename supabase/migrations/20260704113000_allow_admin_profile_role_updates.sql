create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if new.role_id is distinct from old.role_id then
    raise exception 'Only administrators can change user roles.';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'Only administrators can change account status.';
  end if;

  return new;
end;
$$;
