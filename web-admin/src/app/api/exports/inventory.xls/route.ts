import {
  getInventoryExportRows,
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
  const rows = await getInventoryExportRows({
    category: searchParams.get("category") ?? undefined,
    search: searchParams.get("search") ?? undefined,
    status: searchParams.get("status") ?? undefined,
  });
  const html = rowsToExcelHtml("SeedRover Inventory", [
    ["Stock Code", "Item Name", "Category", "Quantity", "Unit", "Selling Price"],
    ...rows.map((row) => [
      row.stockCode,
      row.itemName,
      row.category,
      row.quantity,
      row.unit,
      row.sellingPrice,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-inventory.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
