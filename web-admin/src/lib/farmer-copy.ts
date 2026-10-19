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
  "seeds planted": "Check for new sprouts",
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

const generatedProfileNotes = new Set([
  "seed-grown calamansi has a long and variable juvenile period. show a first-bearing window only after transplanting and confirm care with a local agriculturist.",
  "amounts are field estimates. verify soil condition, drainage, variety, and product label before applying water or fertilizer.",
  "maturity depends on variety and observed pod condition. the date range is an inspection window, not an automatic harvest instruction.",
]);

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

export function farmerCropNote(value: string): string | null {
  return generatedProfileNotes.has(normalizedCopyKey(value)) ? null : value;
}

export function farmerCropTips(profileKey: string | null, growthStage: string): string[] {
  const crop = normalizedCopyKey(profileKey ?? "");
  const stage = normalizedCopyKey(growthStage);
  const early = ["seeded", "seedbed", "germinating", "nursery seedling", "seeds planted", "seeds in nursery", "seeds sprouting", "seedlings growing in nursery"];

  if (crop === "calamansi") {
    if (early.includes(stage) || stage === "transplant review") {
      return [
        "Keep the soil around young seedlings moist, but let extra water drain away.",
        "Check the leaves for damage and clear weeds growing close to the seedlings.",
      ];
    }
    if (["first bearing", "first fruits appearing", "fruiting", "fruits growing"].includes(stage)) {
      return [
        "Check the leaves and fruit for spots or insect damage.",
        "Pick fruit carefully so branches and leaves are not damaged.",
      ];
    }
    return [
      "Check the soil near the roots before watering; calamansi does not do well when water pools around it.",
      "Clear weeds near the tree and check leaves and branches for spots or insect damage.",
    ];
  }

  if (crop === "sitaw") {
    if (stage === "trellising" || stage === "vines growing on support") {
      return [
        "Guide the vines onto a support as they begin to climb.",
        "Keep the soil moist, but do not let water pool around the plants.",
      ];
    }
    if (["flowering", "pod formation", "first harvest", "harvest ready", "repeated harvest", "flowers opening", "pods starting to form", "ready to harvest", "more harvests"].includes(stage)) {
      return [
        "Water regularly while flowers and pods are growing. Too much or too little water can harm the crop.",
        "Check pods for damage and pick them when they are young and tender.",
      ];
    }
    return [
      "Keep the soil moist while seeds sprout and young plants grow; avoid flooding the row.",
      "Keep weeds clear so young plants have room to grow.",
    ];
  }

  if (crop === "peanut") {
    if (["pegging", "pod development", "peanut stems reaching into the soil", "pods growing"].includes(stage)) {
      return [
        "Keep the topsoil moist while pods form, and let extra rainwater drain away.",
        "Check the plants for weeds and signs of leaf or pod damage.",
      ];
    }
    if (["maturity check", "harvest ready", "check if the crop is ready to harvest", "ready to harvest"].includes(stage)) {
      return [
        "Check several pods before harvesting. Look for clear veins on most pods and a dark inner shell.",
        "If the pods are not ready yet, give the plants more time and check again later.",
      ];
    }
    return [
      "Keep the soil moist as seeds sprout and young plants grow; make sure extra water can drain away.",
      "Clear weeds while the plants are small, taking care not to disturb them.",
    ];
  }

  return [
    "Check the soil before watering and make sure extra water can drain away.",
    "Look over leaves and stems for damage or insects as the plant grows.",
  ];
}

export function farmerSensorLabel(value: string) {
  const key = normalizedCopyKey(value);
  if (["soil moisture", "soil moisture (%)"].includes(key)) return "Soil moisture";
  if (key === "raw soil probe (adc)") return "Raw soil reading";
  return value;
}
