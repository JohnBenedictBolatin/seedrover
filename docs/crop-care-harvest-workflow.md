# Crop care and harvest workflow

Crop batches move through four clear steps: plant the batch, record care and field observations, harvest the batch once, then review the closed batch and its inventory movement.

Routine care is recorded as Watered, Fertilized, Checked crop, Observed growth, or Transplanted where appropriate. Each entry may reference the due task that prompted it. A recorded harvest asks for the total batch weight in kilograms and names the matching produce inventory item before confirmation. The database records one harvest, one inventory receipt, closes the batch, and dismisses its open tasks in one transaction. A second submission with the same persistent submission ID returns the original result; a different submission against a closed batch is rejected. Closing without a harvest requires a reason and does not change stock.

Harvest destinations must already exist as a unique inventory item with the same normalized crop name and unit `kg`. Missing, duplicate, mismatched, or incompatible entries block the harvest without changing inventory or batch status. Correct the inventory item before retrying.

Crop activity history shows recorded entries and optional dated photos. Photos belong to an observation and are stored privately. Comparing dated photos supports visual progress reviews; photos and logging frequency do not establish crop health. Apply the forward migration `20260927100000_crop_care_single_batch_harvest.sql` before enabling the new activity and photo entry flow. Until then, clients keep displaying ordinary activity history if `crop_activity_photos` is not present, but new crop entries using the migration RPC and the photo journal are unavailable.

On mobile, unsent care and harvest submissions are account-scoped drafts with stable submission IDs. A queued harvest is not shown as completed and does not appear in confirmed inventory until its transaction syncs. Review rejected drafts and retry after resolving the reported issue.
