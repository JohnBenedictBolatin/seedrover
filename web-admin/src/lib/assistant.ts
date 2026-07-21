import { getActivityDashboard } from "@/lib/activity";
import { getCropsDashboard } from "@/lib/crops";
import { getInventoryDashboard } from "@/lib/inventory";
import { getRoverMonitor } from "@/lib/rover";
import { getSalesWorkspaceData } from "@/lib/sales";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { AdminProfile } from "@/lib/auth";

export type AssistantChatMessage = {
  role: "user" | "assistant";
  content: string;
};

type AssistantContext = {
  source: string;
  note: string;
  generatedAt: string;
  permittedSections: string[];
  rover: Record<string, unknown>;
  crops: Array<Record<string, unknown>>;
  stocks: Array<Record<string, unknown>>;
  recentActivities: Array<Record<string, unknown>>;
  farmAnalytics: Record<string, unknown>;
};

export async function buildWebAssistantContext(profile: AdminProfile): Promise<AssistantContext> {
  const canSeeInventory =
    profile.roleName === "System Administrator" ||
    profile.roleName === "Farm Inventory Manager";
  const canSeeCrops =
    profile.roleName === "System Administrator" ||
    profile.roleName === "Farm Planting Manager";
  const canSeeSystem = profile.roleName === "System Administrator";

  const [inventory, sales, crops, rover, activity] = await Promise.all([
    canSeeInventory ? getInventoryDashboard() : Promise.resolve(null),
    canSeeInventory ? getSalesWorkspaceData() : Promise.resolve(null),
    canSeeCrops || canSeeSystem ? getCropsDashboard() : Promise.resolve(null),
    canSeeCrops || canSeeSystem ? getRoverMonitor() : Promise.resolve(null),
    canSeeSystem ? getActivityDashboard() : Promise.resolve(null),
  ]);

  const topSoldItems = (sales?.analytics.topItems ?? []).map((item) => ({
    label: item.label,
    value: item.value,
  }));
  const recommendationHints: string[] = [];
  const latestSale = sales?.orders[0]
    ? {
        receipt: sales.orders[0].receiptNumber,
        customer: sales.orders[0].customerName,
        paymentMethod: sales.orders[0].paymentMethod,
        totalAmount: sales.orders[0].totalAmount,
        date: sales.orders[0].saleDate,
        status: sales.orders[0].status,
        source: sales.orders[0].source,
      }
    : null;

  if (topSoldItems[0]) {
    recommendationHints.push(
      `${topSoldItems[0].label} is currently the top sold item in the available web sales data.`,
    );
  }

  if ((inventory?.summary?.lowStockItems ?? 0) > 0) {
    recommendationHints.push(
      `${inventory?.summary?.lowStockItems ?? 0} inventory item(s) need stock attention.`,
    );
  }

  if ((crops?.summary?.needsAttention ?? 0) > 0) {
    recommendationHints.push(
      `${crops?.summary?.needsAttention ?? 0} crop record(s) need attention.`,
    );
  }

  return {
    source: "web_admin_current_state",
    note:
      `Data comes from the SeedRover web admin console and is limited to the current user's ${profile.roleName} responsibilities.`,
    generatedAt: new Date().toISOString(),
    permittedSections: [
      canSeeInventory ? "inventory" : null,
      canSeeInventory ? "sales" : null,
      canSeeCrops || canSeeSystem ? "crops" : null,
      canSeeCrops || canSeeSystem ? "rover" : null,
      canSeeSystem ? "activity_logs" : null,
    ].filter((section): section is string => Boolean(section)),
    rover: rover?.status
      ? {
          status: rover.status.roverStatus,
          batteryLevel: rover.status.batteryLevel,
          seedLevel: rover.status.seedLevel,
          wifiConnected: rover.status.wifiConnected,
          bluetoothConnected: rover.status.bluetoothConnected,
          cameraConnected: rover.status.cameraConnected,
          currentActivity: rover.status.currentActivity,
          emergencyStop: rover.status.emergencyStop,
          lastUpdated: rover.status.lastUpdated,
          sensors: rover.sensors,
        }
      : {},
    crops: (crops?.crops ?? []).slice(0, 12).map((crop) => ({
      id: crop.id,
      name: crop.cropName,
      manager: crop.managerName,
      status: crop.cropStatus,
      growthStage: crop.growthStage,
      plantingDate: crop.plantingDate,
      estimatedHarvest: crop.estimatedHarvest,
      progress: crop.progress,
      notes: crop.maintenanceNotes,
    })),
    stocks: (inventory?.items ?? []).slice(0, 12).map((item) => ({
      id: item.id,
      name: item.itemName,
      category: item.category,
      quantity: item.quantity,
      unit: item.unit,
      minimumQuantity: item.minimumQuantity,
      storageLocation: item.storageLocation,
      unitCost: item.unitCost,
      sellingPrice: item.sellingPrice,
      currentStockValue: item.quantity * (item.unitCost ?? 0),
      estimatedSalesValue: item.quantity * (item.sellingPrice ?? 0),
      recentTransactions: item.transactions.slice(0, 3),
      recentSales: item.sales.slice(0, 3),
    })),
    recentActivities: (activity?.logs ?? []).slice(0, 8).map((log) => ({
      title: log.activity,
      description: log.description,
      module: log.module,
      user: log.userName,
      timestamp: log.createdAt,
    })),
    farmAnalytics: {
      currentSalesStatus: {
        summary:
          !sales || sales.summary.completedSalesCount === 0
            ? "No completed sales transactions are available in the current web data."
            : `Current web data has ${sales.summary.completedSalesCount} completed sale(s), totaling PHP ${sales.summary.salesThisMonth.toFixed(
                2,
              )} this month.`,
        salesToday: sales?.summary.salesToday ?? 0,
        salesThisMonth: sales?.summary.salesThisMonth ?? 0,
        salesTransactionsThisMonth: sales?.summary.transactions ?? 0,
        averageTransactionValue: sales?.summary.averageTransactionValue ?? 0,
        totalDiscountGiven: sales?.summary.totalDiscountGiven ?? 0,
        bestSellingItem: sales?.summary.bestSellingItem ?? "Not available",
        latestSale,
        recentSales: sales?.orders.slice(0, 5) ?? [],
      },
      salesByDay: sales?.analytics.dailySales ?? [],
      salesByCategory: sales?.analytics.salesByCategory ?? [],
      paymentMethods: sales?.analytics.paymentMethods ?? [],
      topSoldItems,
      lowPerformingItems: sales?.analytics.lowPerformingItems ?? [],
      inventorySummary: inventory?.summary ?? null,
      salesSummary: sales?.summary ?? null,
      cropSummary: crops?.summary ?? null,
      roverStatus: rover?.status ?? null,
      recommendationHints,
    },
  };
}

export async function askRovie({
  history,
  profile,
  question,
}: {
  history: AssistantChatMessage[];
  profile: AdminProfile;
  question: string;
}) {
  const supabase = await createSupabaseServerClient();
  const context = await buildWebAssistantContext(profile);

  if (!supabase) {
    return {
      answer: fallbackRovieAnswer(question, context),
      detail: "Supabase is not configured.",
      fallback: true,
    };
  }

  try {
    const { data, error } = await supabase.functions.invoke("assistant", {
      body: {
        question,
        history,
        context,
      },
    });

    if (error) {
      return {
        answer: fallbackRovieAnswer(question, context),
        detail: error.message,
        fallback: true,
      };
    }

    const answer = typeof data?.answer === "string" ? data.answer.trim() : "";

    if (!answer) {
      return {
        answer: fallbackRovieAnswer(question, context),
        detail: "The assistant returned an empty response.",
        fallback: true,
      };
    }

    return { answer, detail: null, fallback: false };
  } catch (error) {
    return {
      answer: fallbackRovieAnswer(question, context),
      detail: error instanceof Error ? error.message : "Assistant request failed.",
      fallback: true,
    };
  }
}

function fallbackRovieAnswer(question: string, context: AssistantContext) {
  const normalized = question.toLowerCase();
  const analytics = context.farmAnalytics;
  const sales = analytics.currentSalesStatus as Record<string, unknown> | undefined;
  const inventory = analytics.inventorySummary as
    | { totalItems?: number; lowStockItems?: number; inventoryValue?: number }
    | null
    | undefined;
  const cropSummary = analytics.cropSummary as
    | { activeCrops?: number; needsAttention?: number; harvestReady?: number }
    | null
    | undefined;
  const rover = context.rover;

  if (normalized.includes("sales") || normalized.includes("sell")) {
    return `Based on the current web data, sales today are PHP ${Number(
      sales?.salesToday ?? 0,
    ).toFixed(2)} and sales this month are PHP ${Number(
      sales?.salesThisMonth ?? 0,
    ).toFixed(2)}. Best-selling item: ${String(
      sales?.bestSellingItem ?? "No sales yet",
    )}.`;
  }

  if (normalized.includes("stock") || normalized.includes("inventory")) {
    return `Based on the current web data, there are ${
      inventory?.totalItems ?? 0
    } inventory item(s), with ${
      inventory?.lowStockItems ?? 0
    } needing stock attention. Estimated inventory value is PHP ${Number(
      inventory?.inventoryValue ?? 0,
    ).toFixed(2)}.`;
  }

  if (normalized.includes("crop") || normalized.includes("plant")) {
    return `Based on the current web data, there are ${
      cropSummary?.activeCrops ?? 0
    } active crop record(s), ${cropSummary?.needsAttention ?? 0} needing attention, and ${
      cropSummary?.harvestReady ?? 0
    } harvest-ready.`;
  }

  if (normalized.includes("rover") || normalized.includes("battery")) {
    return `Based on the current web data, rover status is ${String(
      rover.status ?? "not available",
    )}. Battery: ${String(rover.batteryLevel ?? "unknown")}%. Current activity: ${String(
      rover.currentActivity ?? "not available",
    )}.`;
  }

  return "Hi, I'm Rovie. Based on the current web data, I can help with SeedRover sales, inventory, crops, rover status, and farm operations. Ask me what you want to check.";
}
