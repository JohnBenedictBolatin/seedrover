import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/theme/app_colors.dart';
import 'package:seedrover/core/theme/app_theme.dart';
import 'package:seedrover/features/inventory/data/models/stock_model.dart';
import 'package:seedrover/features/inventory/presentation/screens/stock_details_screen.dart';
import 'package:seedrover/features/inventory/presentation/widgets/stock_card.dart';
import 'package:seedrover/features/inventory/presentation/widgets/stock_overview_hero.dart';
import 'package:seedrover/shared/widgets/app_page_header.dart';
import 'package:seedrover/shared/widgets/compact_search_filter_bar.dart';

void main() {
  testWidgets('inventory rows and summary fit phone widths and large text',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final width in [320.0, 390.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(_themeApp(
          brightness,
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const StockOverviewHero(
                    totalItems: 18,
                    inStockItems: 12,
                    needsAttentionItems: 6,
                  ),
                  const SizedBox(height: 12),
                  StockCard(stock: _stock(), onView: () {}),
                ],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Inventory items'), findsOneWidget);
        expect(find.text('STK-2026-000018'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('inventory landing and detail tabs render in light and dark',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        _themeApp(
          brightness,
          Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppPageHeader(
                    title: 'Inventory',
                    actions: IconButton.filledTonal(
                      tooltip: 'Add inventory item',
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const StockOverviewHero(
                    totalItems: 18,
                    inStockItems: 12,
                    needsAttentionItems: 6,
                  ),
                  const SizedBox(height: 12),
                  CompactSearchFilterBar(
                    searchQuery: '',
                    groups: const [],
                    onSearchChanged: (_) {},
                    onApply: (_) {},
                  ),
                  const SizedBox(height: 16),
                  StockCard(stock: _stock(), onView: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('Inventory items'), findsOneWidget);

      for (var tab = 0; tab < 2; tab++) {
        await tester.pumpWidget(
          _detailPreview(brightness, tab),
        );
        await tester.pumpAndSettle();
        expect(find.text('Inventory Details'), findsOneWidget);
        expect(find.text(['Sitaw', 'History'][tab]), findsWidgets);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Widget _themeApp(Brightness brightness, Widget child) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode:
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      builder: (context, child) {
        AppColors.useLightPalette(
          Theme.of(context).brightness == Brightness.light,
        );
        return child ?? const SizedBox.shrink();
      },
      home: child,
    );

Widget _detailPreview(Brightness brightness, int initialIndex) => _themeApp(
      brightness,
      DefaultTabController(
        length: 2,
        initialIndex: initialIndex,
        child: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            final stock = _stock();
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    StockDetailsHeader(onBack: () {}),
                    StockDetailsTabBar(controller: controller),
                    Expanded(
                      child: TabBarView(
                        controller: controller,
                        children: [
                          InventoryTabPage(
                            children: [
                              StockOverviewCard(
                                stock: stock,
                                onRecordSale: () {},
                                onDelete: () {},
                                onReceive: () {},
                                onIssue: () {},
                                onAdjust: () {},
                                onEdit: () {},
                              ),
                            ],
                          ),
                          InventoryTabPage(
                            children: [StockHistorySection(stock: stock)],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

StockModel _stock() => StockModel(
      id: 'stock-18',
      displayId: 'STK-2026-000018',
      name: 'Sitaw',
      category: StockCategory.legumes,
      currentQuantity: 12.5,
      unit: 'kg',
      storageLocation: 'Harvest Bay',
      minimumStockLevel: 4,
      supplier: 'Farm harvest',
      dateAdded: DateTime(2026, 6, 10),
      lastUpdated: DateTime(2026, 9, 20),
      notes: 'Freshly sorted produce.',
      unitCost: 20,
      sellingPrice: 45,
      transactions: [
        StockTransactionModel(
          type: StockTransactionType.stockIn,
          quantity: 15,
          performedAt: DateTime(2026, 9, 19, 8, 30),
          remarks: 'Harvest Bay receipt',
          performedBy: 'Leo Santos',
        ),
        StockTransactionModel(
          type: StockTransactionType.sale,
          quantity: 2.5,
          performedAt: DateTime(2026, 9, 20, 10, 15),
          remarks: 'Market sale',
          performedBy: 'Leo Santos',
        ),
      ],
      sales: [
        SalesTransactionModel(
          id: 'sale-1',
          inventoryId: 'stock-18',
          quantitySold: 2.5,
          unitPrice: 45,
          totalAmount: 112.5,
          saleDate: DateTime(2026, 9, 20),
          recordedBy: 'Leo Santos',
          status: SalesTransactionStatus.completed,
        ),
      ],
    );
