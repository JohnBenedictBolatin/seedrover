begin;

create or replace function public.consume_assistant_rate_limit(
  p_key text,
  p_limit integer default 20,
  p_window_seconds integer default 60
)
returns table(allowed boolean, remaining integer, reset_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_count integer;
  current_reset timestamptz;
begin
  if p_key is null or length(p_key) <> 64
    or p_limit < 1 or p_limit > 100
    or p_window_seconds < 1 or p_window_seconds > 3600 then
    raise exception 'Invalid assistant rate limit request.';
  end if;

  insert into public.rate_limit_buckets(key, count, reset_at)
  values ('rovie:' || p_key, 1, clock_timestamp() + make_interval(secs => p_window_seconds))
  on conflict (key) do update set
    count = case
      when public.rate_limit_buckets.reset_at <= clock_timestamp() then 1
      else public.rate_limit_buckets.count + 1
    end,
    reset_at = case
      when public.rate_limit_buckets.reset_at <= clock_timestamp()
        then clock_timestamp() + make_interval(secs => p_window_seconds)
      else public.rate_limit_buckets.reset_at
    end,
    updated_at = clock_timestamp()
  returning rate_limit_buckets.count, rate_limit_buckets.reset_at
  into current_count, current_reset;

  return query select current_count <= p_limit,
    greatest(p_limit - current_count, 0), current_reset;
end;
$$;

revoke all on function public.consume_assistant_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_assistant_rate_limit(text, integer, integer) to service_role;

commit;
