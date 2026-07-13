import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropItem = {
  id: string;
  cropName: string;
  managerName: string;
  plantingDate: string;
  estimatedHarvest: string | null;
  growthStage: string;
  cropStatus: string;
  maintenanceNotes: string;
  updatedAt: string;
};

export type CropSummary = {
  totalCrops: number;
  activeCrops: number;
  needsAttention: number;
  harvestReady: number;
  completedCrops: number;
};

type CropRow = {
  id: string;
  crop_name: string;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  crop_status: string;
  updated_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

function managerName(row: CropRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "Unassigned";
}

export async function getCropsDashboard() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return {
      crops: [],
      summary: null,
      error: "Supabase is not configured.",
    };
  }

  const { data, error } = await supabase
    .from("crops")
    .select(
      "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, crop_status, updated_at, profiles(full_name)",
    )
    .order("planting_date", { ascending: false })
    .returns<CropRow[]>();

  if (error) {
    return {
      crops: [],
      summary: null,
      error: error.message,
    };
  }

  const crops: CropItem[] = (data ?? []).map((row) => ({
    id: row.id,
    cropName: row.crop_name,
    managerName: managerName(row),
    plantingDate: row.planting_date,
    estimatedHarvest: row.estimated_harvest,
    growthStage: row.growth_stage,
    cropStatus: row.crop_status,
    maintenanceNotes: row.maintenance_notes ?? "No notes recorded.",
    updatedAt: row.updated_at,
  }));

  const summary: CropSummary = {
    totalCrops: crops.length,
    activeCrops: crops.filter((crop) => crop.cropStatus === "Active").length,
    needsAttention: crops.filter((crop) => crop.cropStatus === "Needs Attention")
      .length,
    harvestReady: crops.filter((crop) => crop.cropStatus === "Harvest Ready")
      .length,
    completedCrops: crops.filter((crop) => crop.cropStatus === "Completed").length,
  };

  return {
    crops,
    summary,
    error: null,
  };
}
