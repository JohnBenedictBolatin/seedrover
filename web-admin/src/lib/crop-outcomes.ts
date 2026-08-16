import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropOutcome = {
  id: string;
  cropName: string;
  outcome: string;
  reason: string | null;
  quantity: number | null;
  recordedByName: string;
  recordedAt: string;
};

type Row = {
  id: string;
  crop_name: string;
  outcome: string;
  reason: string | null;
  quantity: number | string | null;
  recorded_by: string | null;
  recorder: { full_name: string } | { full_name: string }[] | null;
  recorded_at: string;
};

export async function getCropOutcomes() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { outcomes: [], error: "Supabase is not configured." };
  const { data, error } = await supabase
    .from("crop_outcomes")
    .select("id, crop_name, outcome, reason, quantity, recorded_by, recorded_at, recorder:profiles!crop_outcomes_recorded_by_fkey(full_name)")
    .order("recorded_at", { ascending: false })
    .returns<Row[]>();

  return {
    outcomes: (data ?? []).map<CropOutcome>((row) => {
      const recorder = Array.isArray(row.recorder) ? row.recorder[0] : row.recorder;
      return {
        id: row.id,
        cropName: row.crop_name,
        outcome: row.outcome,
        reason: row.reason,
        quantity: row.quantity === null ? null : Number(row.quantity),
        recordedByName: recorder?.full_name ?? (row.recorded_by ? "Former user" : "Not recorded"),
        recordedAt: row.recorded_at,
      };
    }),
    error: error?.message ?? null,
  };
}
