-- Client interview additions: resource costs, crop outcomes, and installment payments.

create table if not exists public.crop_outcomes (
  id uuid primary key default gen_random_uuid(),
  crop_id uuid references public.crops(id) on delete set null,
  crop_name text not null,
  outcome text not null default 'Failed',
  reason text,
  quantity numeric(12,2),
  recorded_by uuid references public.profiles(id) on delete set null,
  recorded_at timestamptz not null default now(),
  constraint crop_outcomes_outcome_allowed check (outcome in ('Failed','Discarded','Lost','Harvested'))
);

create table if not exists public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  customer_key text not null,
  customer_name text not null,
  sale_reference text,
  amount numeric(12,2) not null,
  due_date date,
  paid_at timestamptz,
  status text not null default 'Pending',
  notes text,
  recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_payments_amount_positive check (amount > 0),
  constraint customer_payments_status_allowed check (status in ('Pending','Paid','Overdue'))
);

create table if not exists public.farm_expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null,
  category text not null default 'Other',
  amount numeric(12,2) not null,
  expense_date date not null default current_date,
  notes text,
  recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint farm_expenses_amount_positive check (amount > 0)
);

alter table public.crop_outcomes enable row level security;
alter table public.customer_payments enable row level security;
alter table public.farm_expenses enable row level security;

drop policy if exists crop_outcomes_access on public.crop_outcomes;
drop policy if exists customer_payments_access on public.customer_payments;
drop policy if exists farm_expenses_access on public.farm_expenses;

create policy crop_outcomes_access on public.crop_outcomes for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy customer_payments_access on public.customer_payments for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy farm_expenses_access on public.farm_expenses for all using (auth.uid() is not null) with check (auth.uid() is not null);

create index if not exists crop_outcomes_recorded_at_idx on public.crop_outcomes(recorded_at desc);
create index if not exists customer_payments_customer_key_idx on public.customer_payments(customer_key);
create index if not exists farm_expenses_expense_date_idx on public.farm_expenses(expense_date desc);

create or replace function public.notify_admin_on_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, title, message, notification_type, action_route)
  select p.id,
    new.activity,
    coalesce(new.description, 'A new activity was recorded in SeedRover.'),
    case when new.module in ('Crops', 'Planting') then 'Crop Reminder' else 'System' end,
    case when new.module in ('Crops', 'Planting') then '/crops' else '/activity-log' end
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.is_active and r.role_name = 'System Administrator' and p.id is distinct from new.user_id;
  return new;
end;
$$;

drop trigger if exists activity_logs_notify_admin on public.activity_logs;
create trigger activity_logs_notify_admin
  after insert on public.activity_logs
  for each row execute function public.notify_admin_on_activity();
