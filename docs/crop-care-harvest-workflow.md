# Crop care, harvest, and crop ending

Planting a crop creates one crop record. Sitaw and Calamansi can produce more than one harvest from that planting; Peanut and crop profiles without repeat-harvest support keep a single final harvest. The planting name is the farmer-facing name for that crop record. The crop type and tracking ID remain separate so harvests continue to go to the correct inventory item.

## Record care

Farmers can record watering, fertilizing, a field check, a growth-stage observation, or transplanting where the crop supports it. Entries include the date and time and may include notes, a related care task, and photos for a growth-stage observation. The stage selected for an observation must be one of the crop profile's stages at or after the recorded stage. A saved observation records what the farmer saw; it does not by itself prove crop health.

On mobile, care entries saved without connectivity remain account-scoped drafts with a stable submission ID. A draft is not presented as a confirmed server record. Retrying uses the same ID so a response lost after commit does not create a duplicate entry.

## Record a harvest

The farmer enters the weight picked in kilograms, when it was picked, the optional note, and—on repeat-harvest crops—an optional **Check again on** date. Harvests go to the matching produce inventory item. That destination must exist, be unique for the crop, and use `kg`; a missing or incompatible destination blocks the harvest without changing crop or stock records.

Each confirmed picking creates one harvest record and one inventory receipt/batch in the same transaction. A repeated request with the same submission ID and payload returns its committed result; reusing that ID with a different payload fails. A confirmed Sitaw or Calamansi picking leaves the crop active and does not reset its planting date or growth timeline. A confirmed Peanut or other single-harvest crop closes after its final harvest. The crop history shows the individual harvests and their combined total without double-counting mirrored activities or inventory receipts.

For a repeat crop, the optional check date creates a reminder to check whether more produce is ready to pick. Leaving it blank adds no reminder. A synced mobile harvest appears in confirmed inventory and crop totals only after the server confirms it. An unsynced draft remains pending and is not treated as a completed harvest.

Legacy clients that use the final-harvest operation cannot silently record a repeat harvest; they receive an update-required error. Previously committed submissions can still be reconciled by their submission ID.

## End a crop

Ending is a separate action for active repeat-harvest crops. The farmer chooses why the plants are ending and supplies an explanation when choosing **Other**. Ending requires connectivity and resolution of pending local crop entries. The server records the closing time and reason, stops care reminders, and preserves crop, harvest, inventory, sales, and activity history. It adds no inventory movement. A crop with harvests ends as completed with its accumulated yield; a crop with no harvest ends as cancelled and is shown as **Ended without a harvest**. Closed crops stay closed.

The database serializes harvest and ending operations for the same crop. A harvest committed first contributes to the final total; an ending committed first prevents a later harvest. Retrying a committed ending with the same submission ID resolves to the original result.

## Images and history

Growth photos are private attachments to a dated stage observation. Comparing photos can help farmers review visible changes, but photos and logging frequency do not establish crop health. Harvest history stores each harvest's date, weight, recorder, note, and inventory destination.

The workflows described here are implemented by the migrations under `supabase/migrations/`, including `20260927100000_crop_care_single_batch_harvest.sql`, `20261016100000_crop_repeat_harvest.sql`, and the planting-name migrations. Confirm the target database has the required migrations applied before releasing a client that depends on their interfaces.
