create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  customer_key text not null unique,
  display_name text not null,
  contact_number text,
  alternate_contact text,
  customer_type text not null default 'Farm Buyer',
  tags text[] not null default '{}',
  notes text,
  location text,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_type_allowed check (
    customer_type in ('Farm Buyer', 'Market Buyer', 'Wholesale', 'Restaurant', 'Retail', 'Other')
  )
);

create index if not exists customers_customer_key_idx
  on public.customers(customer_key);

create index if not exists customers_display_name_idx
  on public.customers(display_name);

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

alter table public.customers enable row level security;

drop policy if exists customers_select_allowed on public.customers;
create policy customers_select_allowed
  on public.customers
  for select
  using (
    public.has_permission('stocks.view')
    or public.has_permission('stocks.transactions.view')
  );

drop policy if exists customers_insert_allowed on public.customers;
create policy customers_insert_allowed
  on public.customers
  for insert
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customers_update_allowed on public.customers;
create policy customers_update_allowed
  on public.customers
  for update
  using (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  )
  with check (
    public.has_permission('stocks.sales.record')
    or public.has_permission('stocks.manage')
  );

drop policy if exists customers_delete_denied on public.customers;
create policy customers_delete_denied
  on public.customers
  for delete
  using (false);
