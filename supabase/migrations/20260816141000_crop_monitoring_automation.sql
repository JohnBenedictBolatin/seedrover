-- One-time deployment configuration for hourly crop evaluation and FCM dispatch.

create or replace function public.configure_crop_monitoring_automation(
  p_project_url text,
  p_service_role_key text,
  p_cron_secret text
) returns void
language plpgsql
security definer
set search_path = public, extensions, vault, pg_catalog
as $$
declare
  secret_id uuid;
  existing_job bigint;
begin
  if not public.is_admin() then
    raise exception 'System Administrator role required';
  end if;
  if nullif(btrim(p_project_url), '') is null
     or nullif(btrim(p_service_role_key), '') is null
     or nullif(btrim(p_cron_secret), '') is null then
    raise exception 'Project URL, service role key, and cron secret are required';
  end if;

  select id into secret_id from vault.decrypted_secrets where name = 'seedrover_project_url';
  if secret_id is null then
    perform vault.create_secret(rtrim(p_project_url, '/'), 'seedrover_project_url');
  else
    perform vault.update_secret(secret_id, rtrim(p_project_url, '/'));
  end if;
  select id into secret_id from vault.decrypted_secrets where name = 'seedrover_service_role_key';
  if secret_id is null then
    perform vault.create_secret(p_service_role_key, 'seedrover_service_role_key');
  else
    perform vault.update_secret(secret_id, p_service_role_key);
  end if;
  select id into secret_id from vault.decrypted_secrets where name = 'seedrover_crop_monitor_cron_secret';
  if secret_id is null then
    perform vault.create_secret(p_cron_secret, 'seedrover_crop_monitor_cron_secret');
  else
    perform vault.update_secret(secret_id, p_cron_secret);
  end if;

  select jobid into existing_job from cron.job where jobname = 'seedrover-crop-monitor-hourly';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule(
    'seedrover-crop-monitor-hourly',
    '7 * * * *',
    $job$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'seedrover_project_url') || '/functions/v1/crop-monitor',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'seedrover_service_role_key'),
          'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'seedrover_crop_monitor_cron_secret')
        ),
        body := '{}'::jsonb
      );
    $job$
  );
end;
$$;

revoke all on function public.configure_crop_monitoring_automation(text,text,text) from public;
grant execute on function public.configure_crop_monitoring_automation(text,text,text) to authenticated;

create or replace function public.dispatch_crop_notification_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  project_url text;
  service_key text;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets where name = 'seedrover_project_url';
  select decrypted_secret into service_key from vault.decrypted_secrets where name = 'seedrover_service_role_key';
  if project_url is null or service_key is null then return new; end if;
  perform net.http_post(
    url := project_url || '/functions/v1/push-notification',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
    body := jsonb_build_object('record', to_jsonb(new))
  );
  return new;
exception when others then
  raise warning 'Unable to dispatch notification %: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_dispatch_crop_push on public.notifications;
create trigger notifications_dispatch_crop_push
  after insert on public.notifications
  for each row
  when (new.notification_type = 'Crop Reminder')
  execute function public.dispatch_crop_notification_push();
