drop policy if exists farm_expenses_access on public.farm_expenses;
create policy farm_expenses_access on public.farm_expenses for all to authenticated
using (public.is_admin()) with check (public.is_admin());
