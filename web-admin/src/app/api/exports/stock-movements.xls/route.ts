import {
  getStockMovementExportRows,
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
  const rows = await getStockMovementExportRows({
    end: searchParams.get("end") ?? undefined,
    search: searchParams.get("search") ?? undefined,
    source: searchParams.get("source") ?? undefined,
    start: searchParams.get("start") ?? undefined,
    type: searchParams.get("type") ?? undefined,
  });
  const html = rowsToExcelHtml("SeedRover Stock Movements", [
    ["Item", "Stock Code", "Movement Type", "Quantity", "Source", "Date", "Remarks"],
    ...rows.map((row) => [
      row.itemName,
      row.stockCode,
      row.movementType,
      row.quantity,
      row.source,
      row.createdAt,
      row.remarks,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-stock-movements.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
