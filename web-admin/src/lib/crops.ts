import { createSupabaseServerClient } from "@/lib/supabase/server";

export type CropItem = {
  id: string;
  cropName: string;
  managerName: string;
  variety: string;
  location: string;
  progress: number;
  plantingDate: string;
  estimatedHarvest: string | null;
  growthStage: string;
  cropStatus: string;
  maintenanceNotes: string;
  imagePath: string | null;
  imageUrl: string | null;
  updatedAt: string;
};

export type CropSummary = {
  totalCrops: number;
  activeCrops: number;
  needsAttention: number;
  harvestReady: number;
  completedCrops: number;
};

export type HarvestInventoryOption = {
  id: string;
  itemName: string;
  category: string;
  unit: string;
};

type CropRow = {
  id: string;
  crop_name: string;
  planting_date: string;
  estimated_harvest: string | null;
  growth_stage: string;
  maintenance_notes: string | null;
  image_path: string | null;
  crop_status: string;
  updated_at: string;
  profiles: { full_name: string } | { full_name: string }[] | null;
};

type HarvestInventoryRow = {
  id: string;
  item_name: string;
  category: string;
  unit: string;
};

function managerName(row: CropRow) {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return profile?.full_name ?? "Unassigned";
}

function progressFor(stage: string, status: string) {
  if (status === "Completed") return 1;
  return ({ Seeded: 0.12, Germinating: 0.24, Vegetative: 0.46, Flowering: 0.66, "Harvest Ready": 0.94 } as Record<string, number>)[stage] ?? 0.12;
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
      "id, crop_name, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, updated_at, profiles(full_name)",
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
    variety: "Farm Crop",
    location: "SeedRover field record",
    progress: progressFor(row.growth_stage, row.crop_status),
    plantingDate: row.planting_date,
    estimatedHarvest: row.estimated_harvest,
    growthStage: row.growth_stage,
    cropStatus: row.crop_status,
    maintenanceNotes: row.maintenance_notes ?? "No notes recorded.",
    imagePath: row.image_path,
    imageUrl:
      row.image_path === null
        ? null
        : supabase.storage.from("crop-images").getPublicUrl(row.image_path).data
            .publicUrl,
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

export async function getHarvestInventoryOptions() {
  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    return [];
  }

  const { data } = await supabase
    .from("inventory")
    .select("id, item_name, category, unit")
    .order("item_name", { ascending: true })
    .returns<HarvestInventoryRow[]>();

  return (data ?? []).map<HarvestInventoryOption>((row) => ({
    id: row.id,
    itemName: row.item_name,
    category: row.category,
    unit: row.unit,
  }));
}
