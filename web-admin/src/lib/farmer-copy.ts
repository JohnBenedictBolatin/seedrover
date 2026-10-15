const stageLabels: Record<string, string> = {
  seeded: "Seeds planted",
  seedbed: "Seeds in nursery",
  germinating: "Seeds sprouting",
  "nursery seedling": "Seedlings growing in nursery",
  "transplant review": "Check seedlings before moving",
  establishing: "Settling in after moving",
  juvenile: "Young tree growing",
  vegetative: "Leaves and stems growing",
  trellising: "Vines growing on support",
  flowering: "Flowers opening",
  "pod formation": "Pods starting to form",
  pegging: "Peanut stems reaching into the soil",
  "pod development": "Pods growing",
  "maturity check": "Check if the crop is ready to harvest",
  "first bearing": "First fruits appearing",
  fruiting: "Fruits growing",
  "first harvest": "Ready to harvest",
  "harvest ready": "Ready to harvest",
  "repeated harvest": "More harvests",
  completed: "Harvested",
  "review recorded stage": "Check recorded growth stage",
};

const careLabels: Record<string, string> = {
  "monitor establishment": "Check that the young plants are growing well",
  "germination and nursery review": "Check for sprouts and healthy seedlings",
  germination: "Check for sprouts",
  "partial planting - inspect row": "Some seeds may not have dropped. Check the row.",
  "monitor growth": "Check how the plants are growing",
  "review crop condition": "Check how the crop is growing",
  "check crop health": "Check that the crop looks healthy",
  "water crop": "Water the crop",
  "fertilize crop": "Add fertilizer to the crop",
};

const cropStatusLabels: Record<string, string> = {
  "needs attention": "Needs care",
  "harvest ready": "Ready to harvest",
  cancelled: "Ended without a harvest",
  completed: "Harvested",
};

function normalizedCopyKey(value: string) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

export function farmerGrowthStage(value: string) {
  return stageLabels[normalizedCopyKey(value)] ?? value;
}

export function farmerCareText(value: string) {
  return careLabels[normalizedCopyKey(value)] ?? value;
}

export function farmerCropStatus(value: string) {
  return cropStatusLabels[normalizedCopyKey(value)] ?? value;
}

export function farmerSensorLabel(value: string) {
  const key = normalizedCopyKey(value);
  if (["soil moisture", "soil moisture (%)"].includes(key)) return "Water in soil";
  if (key === "raw soil probe (adc)") return "Sensor reading before setup";
  return value;
}
