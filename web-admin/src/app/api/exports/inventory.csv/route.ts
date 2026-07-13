import {
  getInventoryExportRows,
  requireOperationsExporter,
  rowsToCsv,
} from "@/lib/exports";

export async function GET() {
  const profile = await requireOperationsExporter();

  if (!profile) {
    return new Response("Unauthorized", { status: 401 });
  }

  const rows = await getInventoryExportRows();
  const csv = rowsToCsv([
    [
      "Stock Code",
      "Item Name",
      "Category",
      "Quantity",
      "Unit",
      "Minimum Quantity",
      "Storage Location",
      "Unit Cost",
      "Selling Price",
      "Inventory Value",
      "Estimated Sales Value",
      "Updated At",
    ],
    ...rows.map((row) => [
      row.stockCode,
      row.itemName,
      row.category,
      row.quantity,
      row.unit,
      row.minimumQuantity,
      row.storageLocation,
      row.unitCost,
      row.sellingPrice,
      row.inventoryValue,
      row.estimatedSalesValue,
      row.updatedAt,
    ]),
  ]);

  return new Response(csv, {
    headers: {
      "Content-Disposition": 'attachment; filename="seedrover-inventory.csv"',
      "Content-Type": "text/csv; charset=utf-8",
    },
  });
}
