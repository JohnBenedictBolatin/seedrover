-- Remove audit-feed entries whose sole purpose was the retired installment feature.
delete from public.activity_logs
 where activity ilike '%installment%'
    or description ilike '%installment%';

notify pgrst, 'reload schema';
