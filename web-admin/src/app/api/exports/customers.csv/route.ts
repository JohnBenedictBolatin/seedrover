import { getCustomerExportRows, requireOperationsExporter, rowsToCsv } from "@/lib/exports";
import { checkExportRateLimit, rateLimitResponse } from "@/lib/rate-limit";

export async function GET(request: Request) {
  const exportLimit = await checkExportRateLimit(request);

  if (exportLimit.limited) {
    return rateLimitResponse("Too many export requests. Please wait before exporting again.", exportLimit);
  }

  const profile = await requireOperationsExporter();

  if (!profile) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { searchParams } = new URL(request.url);
  const rows = await getCustomerExportRows({
    search: searchParams.get("search") ?? undefined,
  });
  const csv = rowsToCsv([
    [
      "Customer Name",
      "Contact",
      "Customer Type",
      "Tags",
      "Location",
      "Receipt Count",
      "Total Spent",
      "Average Spend",
      "Last Purchase",
      "Payment Methods",
      "Top Items",
      "Notes",
    ],
    ...rows.map((row) => [
      row.name,
      row.contact,
      row.customerType,
      row.tags,
      row.location,
      row.receiptCount,
      row.totalSpent,
      row.averageSpend,
      row.lastPurchaseAt,
      row.paymentMethods,
      row.topItems,
      row.notes,
    ]),
  ]);

  return new Response(csv, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-customers.csv"',
      "Content-Type": "text/csv; charset=utf-8",
    },
  });
}
