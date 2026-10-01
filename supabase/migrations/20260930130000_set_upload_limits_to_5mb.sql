-- Apply the same per-file cap to every image and receipt bucket, including
-- buckets that were originally created without an explicit size limit.
update storage.buckets
set file_size_limit = 5242880
where id in (
  'profile-images',
  'stock-images',
  'crop-images',
  'crop-journal',
  'expense-receipts',
  'installment-receipts'
);
