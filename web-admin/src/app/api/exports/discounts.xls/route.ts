import {
  getDiscountExportRows,
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
  const rows = await getDiscountExportRows({
    end: searchParams.get("end") ?? undefined,
    search: searchParams.get("search") ?? undefined,
    start: searchParams.get("start") ?? undefined,
    status: searchParams.get("status") ?? undefined,
  });
  const html = rowsToExcelHtml("SeedRover Discounts", [
    ["Code", "Customer", "Type", "Value", "Released", "Redeemed", "Status"],
    ...rows.map((row) => [
      row.code,
      row.customerName,
      row.discountType,
      row.discountValue,
      row.releasedAt,
      row.redeemedAt,
      row.status,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-discounts.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
