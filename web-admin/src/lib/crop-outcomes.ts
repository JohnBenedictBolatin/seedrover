import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropOutcome = { id: string; cropName: string; outcome: string; reason: string | null; quantity: number | null; recordedAt: string };
type Row = { id: string; crop_name: string; outcome: string; reason: string | null; quantity: number | string | null; recorded_at: string };

export async function getCropOutcomes() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { outcomes: [], error: "Supabase is not configured." };
  const { data, error } = await supabase.from("crop_outcomes").select("id, crop_name, outcome, reason, quantity, recorded_at").order("recorded_at", { ascending: false }).returns<Row[]>();
  return { outcomes: (data ?? []).map<CropOutcome>((row) => ({ id: row.id, cropName: row.crop_name, outcome: row.outcome, reason: row.reason, quantity: row.quantity === null ? null : Number(row.quantity), recordedAt: row.recorded_at })), error: error?.message ?? null };
}
