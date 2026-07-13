import { getSalesExportRows, requireOperationsExporter, rowsToCsv } from "@/lib/exports";

export async function GET() {
  const profile = await requireOperationsExporter();

  if (!profile) {
    return new Response("Unauthorized", { status: 401 });
  }

  const rows = await getSalesExportRows();
  const csv = rowsToCsv([
    [
      "Receipt Number",
      "Sale Date",
      "Customer Name",
      "Customer Contact",
      "Payment Method",
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
