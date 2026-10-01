alter table public.farm_expenses
  drop constraint if exists farm_expenses_type_allowed;

update public.farm_expenses
set expense_type = case
  when expense_type = 'Recurring expense' then 'Operating expense'
  else 'Capital investment'
end
where expense_type not in ('Capital investment', 'Operating expense');

alter table public.farm_expenses
  alter column expense_type set default 'Capital investment';

alter table public.farm_expenses
  add constraint farm_expenses_type_allowed
  check (expense_type in ('Capital investment', 'Operating expense'));

comment on column public.farm_expenses.expense_type is
  'Classifies each individually recorded payment as either a capital investment or an operating expense.';
