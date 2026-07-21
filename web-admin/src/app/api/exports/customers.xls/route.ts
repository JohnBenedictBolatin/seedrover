import {
  getCustomerExportRows,
  requireOperationsExporter,
  rowsToExcelHtml,
} from "@/lib/exports";
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
  const html = rowsToExcelHtml("SeedRover Customers", [
    ["Customer", "Contact", "Type", "Receipts", "Total Spent", "Average Spend", "Last Purchase"],
    ...rows.map((row) => [
      row.name,
      row.contact,
      row.customerType,
      row.receiptCount,
      row.totalSpent,
      row.averageSpend,
      row.lastPurchaseAt,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-customers.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
