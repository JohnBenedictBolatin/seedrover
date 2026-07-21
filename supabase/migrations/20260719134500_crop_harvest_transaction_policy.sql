drop policy if exists inventory_transactions_insert_allowed
  on public.inventory_transactions;

create policy inventory_transactions_insert_allowed
  on public.inventory_transactions
  for insert
  to authenticated
  with check (
    performed_by = auth.uid()
    and (
      public.has_permission('stocks.manage')
      or (
        source = 'harvest'
        and transaction_type = 'IN'
        and public.has_permission('crops.manage')
      )
    )
  );
