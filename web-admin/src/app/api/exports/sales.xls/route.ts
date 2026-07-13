import {
  getSalesExportRows,
  requireOperationsExporter,
  rowsToExcelHtml,
} from "@/lib/exports";

export async function GET() {
  const profile = await requireOperationsExporter();

  if (!profile) {
    return new Response("Unauthorized", { status: 401 });
  }

  const rows = await getSalesExportRows();
  const html = rowsToExcelHtml("SeedRover Sales", [
    ["Receipt", "Date", "Customer", "Payment", "Item", "Quantity", "Unit Price", "Line Total"],
    ...rows.map((row) => [
      row.receiptNumber,
      row.saleDate,
      row.customerName,
      row.paymentMethod,
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
