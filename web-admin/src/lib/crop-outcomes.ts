import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropOutcome = {
  id: string;
  cropId: string | null;
  cropName: string;
  cropType: string;
  outcome: string;
  reason: string | null;
  quantity: number | null;
  recordedByName: string;
  recordedAt: string;
};

type Row = {
  id: string;
  crop_id: string | null;
  crop_name: string;
  outcome: string;
  reason: string | null;
  quantity: number | string | null;
  recorded_by: string | null;
  recorded_at: string;
};

export async function getCropOutcomes() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { outcomes: [], error: "Supabase is not configured." };
  const { data, error } = await supabase
    .from("crop_outcomes")
    .select("id, crop_id, crop_name, outcome, reason, quantity, recorded_by, recorded_at")
    .order("recorded_at", { ascending: false })
    .returns<Row[]>();

  const performerIds = [...new Set((data ?? [])
    .map((row) => row.recorded_by)
    .filter((id): id is string => Boolean(id)))];
  const { data: performerRows } = performerIds.length
    ? await supabase.rpc("crop_performer_names", { p_performer_ids: performerIds })
    : { data: [] };
  const performerNames = new Map(
    ((performerRows ?? []) as { performer_id: string; full_name: string | null }[])
      .map((performer) => [performer.performer_id, performer.full_name]),
  );
  const cropIds = [...new Set((data ?? []).map((row) => row.crop_id).filter((id): id is string => Boolean(id)))];
  const { data: cropRows } = cropIds.length
    ? await supabase.from("crops").select("id,crop_name,assigned_planting_name,custom_planting_name").in("id", cropIds)
    : { data: [] };
  const cropNames = new Map((cropRows ?? []).map((crop) => [
    crop.id,
    {
      displayName: crop.custom_planting_name?.trim() || crop.assigned_planting_name?.trim() || `Garden ${crop.crop_name}`,
      cropType: crop.crop_name,
    },
  ]));

  return {
    outcomes: (data ?? []).map<CropOutcome>((row) => {
      return {
        id: row.id,
        cropId: row.crop_id,
        cropName: (row.crop_id ? cropNames.get(row.crop_id)?.displayName : null) ?? row.crop_name,
        cropType: (row.crop_id ? cropNames.get(row.crop_id)?.cropType : null) ?? row.crop_name,
        outcome: row.outcome,
        reason: row.reason,
        quantity: row.quantity === null ? null : Number(row.quantity),
        recordedByName: (row.recorded_by ? performerNames.get(row.recorded_by) : null) ?? (row.recorded_by ? "Former user" : "Not recorded"),
        recordedAt: row.recorded_at,
      };
    }),
    error: error?.message ?? null,
  };
}
