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
    ["Entry Type", "Receipt / Reference", "Receipt Link", "Date", "Customer", "Payment", "Transaction ID", "Item", "Quantity", "Unit Price", "Sale Line Total", "Sale Total", "Payment Received", "Status"],
    ...rows.map((row) => [
      row.entryType,
      row.receiptNumber,
      row.receiptLink,
      row.saleDate,
      row.customerName,
      row.paymentMethod,
      row.transactionReference,
      row.itemName,
      row.quantitySold,
      row.unitPrice,
      row.lineTotal,
      row.receiptTotal ?? "",
      row.collectionAmount ?? "",
      row.status,
    ]),
  ]);

  return new Response(html, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-sales.xls"',
      "Content-Type": "application/vnd.ms-excel; charset=utf-8",
    },
  });
}
