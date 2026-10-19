begin;

-- Several client-facing tables were created after the initial blanket grants.
-- Keep the existing RLS rules as the permission boundary and grant only the
-- table operations needed by each supported workflow.
grant select, insert, update, delete on public.crop_profiles to authenticated;
grant select on public.crop_profile_versions to authenticated;
grant select, insert on public.crop_activities to authenticated;
grant select, update on public.crop_tasks to authenticated;
grant select, insert, update, delete on public.crop_profile_images to authenticated;
grant select on public.crop_outcomes to authenticated;

grant select on public.sales_transactions to authenticated;
grant select, insert, update on public.customers to authenticated;
grant select, insert, update on public.customer_discounts to authenticated;
grant select, insert on public.customer_payments to authenticated;
grant update (status, paid_at) on public.customer_payments to authenticated;

grant select, insert, update, delete on public.farm_expenses to authenticated;
grant select, insert, update, delete on public.farm_weather_settings to authenticated;
grant select on public.weather_forecasts to authenticated;

-- Crop outcomes are written by protected status-sync triggers. Restrict direct
-- reads to the crop-view permission instead of the old any-signed-in policy.
drop policy if exists crop_outcomes_access on public.crop_outcomes;
drop policy if exists crop_outcomes_select_allowed on public.crop_outcomes;
create policy crop_outcomes_select_allowed
  on public.crop_outcomes
  for select to authenticated
  using (public.has_permission('crops.view'));

-- Customer payment history contains customer and payment details. Scope it to
-- the inventory/sales roles and record the authenticated actor on new entries.
drop policy if exists customer_payments_access on public.customer_payments;
drop policy if exists customer_payments_select_allowed on public.customer_payments;
drop policy if exists customer_payments_insert_allowed on public.customer_payments;
drop policy if exists customer_payments_update_allowed on public.customer_payments;

create policy customer_payments_select_allowed
  on public.customer_payments
  for select to authenticated
  using (
    public.is_admin()
    or public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
    or public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

create policy customer_payments_insert_allowed
  on public.customer_payments
  for insert to authenticated
  with check (
    (
      public.has_permission('stocks.sales.record')
      or public.has_permission('stocks.manage')
    )
    and recorded_by = auth.uid()
  );

create policy customer_payments_update_allowed
  on public.customer_payments
  for update to authenticated
  using (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  )
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

commit;
