import {
  getInventoryExportRows,
  requireOperationsExporter,
  rowsToExcelHtml,
} from "@/lib/exports";

export async function GET() {
  const profile = await requireOperationsExporter();

  if (!profile) {
    return new Response("Unauthorized", { status: 401 });
  }

  const rows = await getInventoryExportRows();
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
