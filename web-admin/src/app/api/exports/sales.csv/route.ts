import { getSalesExportRows, requireOperationsExporter, rowsToCsv } from "@/lib/exports";
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
  const csv = rowsToCsv([
    [
      "Receipt Number",
      "Sale Date",
      "Customer Name",
      "Customer Contact",
      "Payment Method",
      "Transaction ID",
      "Item Name",
      "Quantity Sold",
      "Unit",
      "Unit Price",
      "Line Total",
      "Receipt Subtotal",
      "Discount Amount",
      "Receipt Total",
      "Status",
    ],
    ...rows.map((row) => [
      row.receiptNumber,
      row.saleDate,
      row.customerName,
      row.customerContact,
      row.paymentMethod,
      row.transactionReference,
      row.itemName,
      row.quantitySold,
      row.unit,
      row.unitPrice,
      row.lineTotal,
      row.receiptSubtotal,
      row.discountAmount,
      row.receiptTotal,
      row.status,
    ]),
  ]);

  return new Response(csv, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-sales.csv"',
      "Content-Type": "text/csv; charset=utf-8",
    },
  });
}
