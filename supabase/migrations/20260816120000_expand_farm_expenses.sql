alter table public.farm_expenses
  add column if not exists vendor text,
  add column if not exists payment_method text not null default 'Cash',
  add column if not exists reference_number text,
  add column if not exists expense_type text not null default 'One-time investment',
  add column if not exists related_crop_id uuid references public.crops(id) on delete set null,
  add column if not exists related_inventory_id uuid references public.inventory(id) on delete set null,
  add column if not exists quantity numeric(12,2),
  add column if not exists unit_cost numeric(12,2),
  add column if not exists receipt_path text,
  add column if not exists frequency text,
  add column if not exists next_due_date date,
  add column if not exists end_date date;

alter table public.farm_expenses
  drop constraint if exists farm_expenses_payment_method_allowed,
  drop constraint if exists farm_expenses_type_allowed,
  drop constraint if exists farm_expenses_quantity_positive,
  drop constraint if exists farm_expenses_unit_cost_non_negative,
  drop constraint if exists farm_expenses_frequency_allowed;

alter table public.farm_expenses
  add constraint farm_expenses_payment_method_allowed check (payment_method in ('Cash','GCash','Bank Transfer','Card','Other')),
  add constraint farm_expenses_type_allowed check (expense_type in ('One-time investment','Recurring expense')),
  add constraint farm_expenses_quantity_positive check (quantity is null or quantity > 0),
  add constraint farm_expenses_unit_cost_non_negative check (unit_cost is null or unit_cost >= 0),
  add constraint farm_expenses_frequency_allowed check (frequency is null or frequency in ('Weekly','Monthly','Quarterly','Yearly'));

insert into storage.buckets (id, name, public)
values ('expense-receipts', 'expense-receipts', false)
on conflict (id) do nothing;

drop policy if exists expense_receipts_authenticated_select on storage.objects;
drop policy if exists expense_receipts_authenticated_insert on storage.objects;

create policy expense_receipts_authenticated_select on storage.objects for select to authenticated using (bucket_id = 'expense-receipts');
create policy expense_receipts_authenticated_insert on storage.objects for insert to authenticated with check (bucket_id = 'expense-receipts');
