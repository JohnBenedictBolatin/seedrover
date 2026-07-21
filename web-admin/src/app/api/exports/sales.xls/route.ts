import {
  getSalesExportRows,
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
  const rows = await getSalesExportRows({
    end: searchParams.get("end") ?? undefined,
    payment: searchParams.get("payment") ?? undefined,
    start: searchParams.get("start") ?? undefined,
    status: searchParams.get("status") ?? undefined,
  });
  const html = rowsToExcelHtml("SeedRover Sales", [
    ["Receipt", "Date", "Customer", "Payment", "Transaction ID", "Item", "Quantity", "Unit Price", "Line Total"],
    ...rows.map((row) => [
      row.receiptNumber,
      row.saleDate,
      row.customerName,
      row.paymentMethod,
      row.transactionReference,
      row.itemName,
      row.quantitySold,
      row.unitPrice,
      row.lineTotal,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-sales.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
