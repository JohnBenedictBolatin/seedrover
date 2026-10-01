-- Route every persisted, user-facing notification to the existing FCM sender.
-- Audit events remain in activity_logs and do not create rows here.

create or replace function public.deactivate_push_device_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.push_device_tokens
  set is_active = false
  where profile_id = auth.uid()
    and token = p_token;
$$;

revoke all on function public.deactivate_push_device_token(text) from public;
grant execute on function public.deactivate_push_device_token(text) to authenticated;

create or replace function public.configure_notification_push_dispatch(
  p_project_url text,
  p_service_role_key text
) returns void
language plpgsql
security definer
set search_path = public, vault, pg_catalog
as $$
declare
  secret_id uuid;
begin
  if not public.is_admin() then
    raise exception 'System Administrator role required';
  end if;
  if nullif(btrim(p_project_url), '') is null
     or nullif(btrim(p_service_role_key), '') is null then
    raise exception 'Project URL and service-role key are required';
  end if;

  select id into secret_id from vault.decrypted_secrets
  where name = 'seedrover_project_url';
  if secret_id is null then
    perform vault.create_secret(rtrim(p_project_url, '/'), 'seedrover_project_url');
  else
    perform vault.update_secret(secret_id, rtrim(p_project_url, '/'));
  end if;

  select id into secret_id from vault.decrypted_secrets
  where name = 'seedrover_service_role_key';
  if secret_id is null then
    perform vault.create_secret(p_service_role_key, 'seedrover_service_role_key');
  else
    perform vault.update_secret(secret_id, p_service_role_key);
  end if;
end;
$$;

revoke all on function public.configure_notification_push_dispatch(text, text) from public;
grant execute on function public.configure_notification_push_dispatch(text, text) to authenticated;

create or replace function public.dispatch_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  project_url text;
  service_key text;
begin
  select decrypted_secret into project_url
  from vault.decrypted_secrets
  where name = 'seedrover_project_url';

  select decrypted_secret into service_key
  from vault.decrypted_secrets
  where name = 'seedrover_service_role_key';

  if project_url is null or service_key is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(project_url, '/') || '/functions/v1/push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object('record', to_jsonb(new))
  );
  return new;
exception when others then
  raise warning 'Unable to dispatch notification %: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_dispatch_crop_push on public.notifications;
drop trigger if exists notifications_dispatch_push on public.notifications;
create trigger notifications_dispatch_push
  after insert on public.notifications
  for each row execute function public.dispatch_notification_push();
