import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/utils/currency_formatter.dart';
import 'package:seedrover/features/inventory/data/models/stock_model.dart';

void main() {
  group('inventory sales calculations', () {
    test('formats Philippine peso values consistently', () {
      expect(CurrencyFormatter.php(125), 'PHP 125.00');
      expect(CurrencyFormatter.phpOrUnset(null), 'Not set');
    });

    test('calculates stock value and completed sales totals', () {
      final stock = StockModel(
        id: 'stock-1',
        displayId: 'STK-001',
        name: 'Sitaw',
        category: StockCategory.legumes,
        currentQuantity: 10,
        unit: 'kg',
        storageLocation: 'Harvest Bay',
        minimumStockLevel: 3,
        supplier: 'Farm Harvest',
        dateAdded: DateTime(2026, 7),
        lastUpdated: DateTime(2026, 7, 13),
        notes: 'Fresh harvest.',
        transactions: const [],
        unitCost: 20,
        sellingPrice: 45,
        sales: [
          SalesTransactionModel(
            id: 'sale-1',
            inventoryId: 'stock-1',
            quantitySold: 2,
            unitPrice: 45,
            totalAmount: 90,
            saleDate: DateTime(2026, 7, 13, 9),
            recordedBy: 'Admin',
            status: SalesTransactionStatus.completed,
          ),
          SalesTransactionModel(
            id: 'sale-2',
            inventoryId: 'stock-1',
            quantitySold: 1,
            unitPrice: 45,
            totalAmount: 45,
            saleDate: DateTime(2026, 7, 13, 10),
            recordedBy: 'Admin',
            status: SalesTransactionStatus.voided,
          ),
        ],
      );

      expect(stock.currentStockValue, 200);
      expect(stock.estimatedSalesValue, 450);
      expect(stock.quantitySold, 2);
      expect(stock.totalSalesValue, 90);
      expect(stock.lastSaleDate, DateTime(2026, 7, 13, 9));
    });
  });
}
