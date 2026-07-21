import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/stock_model.dart';

class StockRepository {
  const StockRepository(this._client);

  static const _stockImagesBucket = 'stock-images';
  static const _inventoryColumns =
      'id, stock_code, item_name, quantity, unit, minimum_quantity, unit_cost, selling_price, image_path, storage_location, '
      'category, created_at, updated_at';
  static const _legacyInventoryColumns =
      'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
      'category, created_at, updated_at';

  final SupabaseClient _client;

  Stream<List<StockModel>> watchStocks() {
    return _client
        .from(DatabaseTables.inventory)
        .stream(primaryKey: ['id'])
        .order('updated_at')
        .asyncMap((_) => getStocks());
  }

  Future<List<StockModel>> getStocks() async {
    final rows = await _inventoryRows();

    final stocks = <StockModel>[];
    for (var index = 0; index < rows.length; index++) {
      stocks.add(
        await _stockFromRow(
          rows[index] as Map<String, dynamic>,
          displayId: _displayIdFor(index),
        ),
      );
    }

    return stocks;
  }

  Future<StockModel> createStock(
    StockModel stock, {
    StockImageUpload? imageUpload,
  }) async {
    final row = await _insertStock(stock);
    final stockId = row['id'] as String;
    var imagePath = stock.imagePath;

    if (imageUpload != null) {
      imagePath = await _uploadStockImage(
        stockId: stockId,
        upload: imageUpload,
      );

      await _client
          .from(DatabaseTables.inventory)
          .update({'image_path': imagePath})
          .eq('id', stockId);
    }

    await _recordActivity(
      activity: 'Inventory item created',
      description: '${stock.name} inventory item created.',
    );

    return _stockById(stockId).then(
      (createdStock) => createdStock.copyWith(
        notes: stock.notes,
        imagePath: imagePath,
        imageUrl: _publicImageUrl(imagePath),
        imageAssetPath: stock.imageAssetPath,
      ),
    );
  }

  Future<StockModel> updateStock(StockModel stock) async {
    final previousStock = await _stockById(stock.id);

    await _updateStockRow(stock);

    await _recordPricingActivities(previous: previousStock, next: stock);
    await _recordActivity(
      activity: 'Inventory item updated',
      description: '${stock.name} inventory item updated.',
    );

    final updatedStock = await _stockById(stock.id);

    return updatedStock.copyWith(
      displayId: stock.displayId,
      notes: stock.notes,
      imagePath: stock.imagePath,
      imageUrl: stock.imageUrl,
      imageAssetPath: stock.imageAssetPath,
    );
  }

  Future<void> deleteStock(String stockId) async {
    await _client.from(DatabaseTables.inventory).delete().eq('id', stockId);
    await _recordActivity(
      activity: 'Inventory item deleted',
      description: 'Inventory item deleted.',
    );
  }

  Future<StockSalesSummaryModel> getSalesSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    late final List<dynamic> rows;

    try {
      rows = await _client
          .from(DatabaseTables.salesTransactions)
          .select('quantity_sold, total_amount, sale_date, status')
          .gte('sale_date', monthStart.toUtc().toIso8601String())
          .order('sale_date', ascending: false) as List<dynamic>;
    } on PostgrestException {
      return StockSalesSummaryModel.empty();
    }

    var salesToday = 0.0;
    var salesThisMonth = 0.0;
    var unitsSoldThisMonth = 0.0;
    var transactionCount = 0;

    for (final row in rows) {
      final data = row as Map<String, dynamic>;

      if (data['status'] == 'Voided') {
        continue;
      }

      final saleDate = _parseDate(data['sale_date']) ?? now;
      final totalAmount = _toDouble(data['total_amount']);
      final quantitySold = _toDouble(data['quantity_sold']);

      salesThisMonth += totalAmount;
      unitsSoldThisMonth += quantitySold;
      transactionCount += 1;

      if (!saleDate.isBefore(todayStart)) {
        salesToday += totalAmount;
      }
    }

    return StockSalesSummaryModel(
      salesToday: salesToday,
      salesThisMonth: salesThisMonth,
      unitsSoldThisMonth: unitsSoldThisMonth,
      salesTransactions: transactionCount,
    );
  }

  Future<StockModel> stockIn({
    required StockModel stock,
    required double quantity,
    required String supplier,
    required String remarks,
  }) async {
    await _insertTransaction(
      stockId: stock.id,
      type: 'IN',
      quantity: quantity,
      remarks: _cleanRemarks(remarks, fallback: 'Stock added.'),
    );

    await _recordActivity(
      activity: 'Stock in recorded',
      description: '${stock.name}: $quantity ${stock.unit} added.',
    );

    return _stockById(stock.id).then(
      (updatedStock) => updatedStock.copyWith(
        displayId: stock.displayId,
        imagePath: stock.imagePath,
        imageUrl: stock.imageUrl,
        imageAssetPath: stock.imageAssetPath,
      ),
    );
  }

  Future<StockModel> stockOut({
    required StockModel stock,
    required double quantity,
    required String purpose,
    required String remarks,
  }) async {
    final purposeText = purpose.trim().isEmpty ? 'Stock used.' : purpose.trim();
    final remarksText = remarks.trim().isEmpty ? purposeText : remarks.trim();

    await _insertTransaction(
      stockId: stock.id,
      type: 'OUT',
      quantity: quantity,
      remarks: '$purposeText - $remarksText',
    );

    await _recordActivity(
      activity: 'Stock out recorded',
      description: '${stock.name}: $quantity ${stock.unit} deducted.',
    );

    return _stockById(stock.id).then(
      (updatedStock) => updatedStock.copyWith(
        displayId: stock.displayId,
        imagePath: stock.imagePath,
        imageUrl: stock.imageUrl,
        imageAssetPath: stock.imageAssetPath,
      ),
    );
  }

  Future<StockModel> recordSale(RecordSaleRequest request) async {
    final params = {
      'p_inventory_id': request.stock.id,
      'p_quantity_sold': request.quantitySold,
      'p_unit_price': request.unitPrice,
      'p_sale_date': request.saleDate.toUtc().toIso8601String(),
      'p_customer_name': request.customerName,
      'p_remarks': request.remarks,
      'p_payment_method': request.paymentMethod,
      'p_transaction_reference': request.transactionReference,
      'p_other_payment_method': request.otherPaymentMethod,
    };
    Object? response;

    try {
      response = await _client.rpc('record_inventory_sale', params: params);
    } on PostgrestException catch (error) {
      if (!_needsLegacySaleParams(error.message)) {
        rethrow;
      }

      response = await _client.rpc(
        'record_inventory_sale',
        params: {
          'p_inventory_id': request.stock.id,
          'p_quantity_sold': request.quantitySold,
          'p_unit_price': request.unitPrice,
          'p_sale_date': request.saleDate.toUtc().toIso8601String(),
          'p_customer_name': request.customerName,
          'p_remarks': request.remarks,
        },
      );
    }
    final sale = _saleFromResponse(response, request);
    final saleTransaction = StockTransactionModel(
      type: StockTransactionType.sale,
      quantity: request.quantitySold,
      performedAt: request.saleDate,
      remarks:
          'Sale recorded: PHP ${request.totalAmount.toStringAsFixed(2)}',
      performedBy: 'SeedRover User',
    );
    final updatedStock = await _stockById(request.stock.id);
    final hasSale = updatedStock.sales.any((item) => item.id == sale.id);
    final hasSaleTransaction = updatedStock.transactions.any(
      (transaction) =>
          transaction.type == StockTransactionType.sale &&
          transaction.performedAt.isAtSameMomentAs(request.saleDate) &&
          transaction.quantity == request.quantitySold,
    );

    return updatedStock.copyWith(
      displayId: request.stock.displayId,
      imagePath: request.stock.imagePath,
      imageUrl: request.stock.imageUrl,
      imageAssetPath: request.stock.imageAssetPath,
      sales: hasSale ? updatedStock.sales : [sale, ...updatedStock.sales],
      transactions: hasSaleTransaction
          ? updatedStock.transactions
          : [saleTransaction, ...updatedStock.transactions],
    );
  }

  Future<StockModel> adjustStock({
    required StockModel stock,
    required double newQuantity,
    required String reason,
    required String remarks,
  }) async {
    final reasonText = reason.trim().isEmpty ? 'Stock adjusted.' : reason.trim();
    final remarksText = remarks.trim().isEmpty ? reasonText : remarks.trim();

    await _insertTransaction(
      stockId: stock.id,
      type: 'ADJUSTMENT',
      quantity: newQuantity,
      remarks: '$reasonText - $remarksText',
    );

    await _recordActivity(
      activity: 'Stock quantity adjusted',
      description: '${stock.name}: stock adjusted to $newQuantity ${stock.unit}.',
    );

    return _stockById(stock.id).then(
      (updatedStock) => updatedStock.copyWith(
        displayId: stock.displayId,
        imagePath: stock.imagePath,
        imageUrl: stock.imageUrl,
        imageAssetPath: stock.imageAssetPath,
      ),
    );
  }

  Future<StockModel> _stockById(String stockId) async {
    final row = await _inventoryRowById(stockId);

    return _stockFromRow(row, displayId: _displayIdFromUuid(stockId));
  }

  Future<List<dynamic>> _inventoryRows() async {
    try {
      return await _client
          .from(DatabaseTables.inventory)
          .select(_inventoryColumns)
          .order('updated_at', ascending: false) as List<dynamic>;
    } on PostgrestException {
      return _client
          .from(DatabaseTables.inventory)
          .select(_legacyInventoryColumns)
          .order('updated_at', ascending: false) as List<dynamic>;
    }
  }

  Future<Map<String, dynamic>> _inventoryRowById(String stockId) async {
    try {
      return await _client
          .from(DatabaseTables.inventory)
          .select(_inventoryColumns)
          .eq('id', stockId)
          .single();
    } on PostgrestException {
      return _client
          .from(DatabaseTables.inventory)
          .select(_legacyInventoryColumns)
          .eq('id', stockId)
          .single();
    }
  }

  Future<Map<String, dynamic>> _insertStock(StockModel stock) async {
    final payload = {
      ..._stockPayload(stock),
      'stock_code': await _nextStockCode(),
      'quantity': stock.currentQuantity,
    };

    try {
      return await _client
          .from(DatabaseTables.inventory)
          .insert(payload)
          .select(_inventoryColumns)
          .single();
    } on PostgrestException {
      return _client
          .from(DatabaseTables.inventory)
          .insert(_legacyStockPayload(payload))
          .select(_legacyInventoryColumns)
          .single();
    }
  }

  Future<void> _updateStockRow(StockModel stock) async {
    try {
      await _client
          .from(DatabaseTables.inventory)
          .update(_stockPayload(stock))
          .eq('id', stock.id)
          .select(_inventoryColumns)
          .single();
    } on PostgrestException {
      await _client
          .from(DatabaseTables.inventory)
          .update(_legacyStockPayload(_stockPayload(stock)))
          .eq('id', stock.id)
          .select(_legacyInventoryColumns)
          .single();
    }
  }

  Future<void> _insertTransaction({
    required String stockId,
    required String type,
    required double quantity,
    required String remarks,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Sign in before changing inventory.');
    }

    await _client.from(DatabaseTables.inventoryTransactions).insert({
      'inventory_id': stockId,
      'transaction_type': type,
      'quantity': quantity,
      'remarks': remarks,
      'performed_by': userId,
    });
  }

  Future<StockModel> _stockFromRow(
    Map<String, dynamic> row, {
    required String displayId,
  }) async {
    final transactions = await _transactionsFor(row['id'] as String);
    final sales = await _salesFor(row['id'] as String);

    return StockModel(
      id: row['id'] as String,
      displayId: row['stock_code'] as String? ?? displayId,
      name: row['item_name'] as String? ?? 'Inventory Item',
      category: _categoryFromDb(row['category'] as String?),
      currentQuantity: _toDouble(row['quantity']),
      unit: row['unit'] as String? ?? 'unit',
      storageLocation: row['storage_location'] as String? ?? 'Unassigned',
      minimumStockLevel: _toDouble(row['minimum_quantity']),
      supplier: _supplierFrom(transactions),
      dateAdded: _parseDate(row['created_at']) ?? DateTime.now(),
      lastUpdated: _parseDate(row['updated_at']) ?? DateTime.now(),
      notes: _notesFrom(transactions),
      transactions: transactions,
      unitCost: _nullableDouble(row['unit_cost']),
      sellingPrice: _nullableDouble(row['selling_price']),
      sales: sales,
      imagePath: row['image_path'] as String?,
      imageUrl: _publicImageUrl(row['image_path'] as String?),
      imageAssetPath: null,
    );
  }

  Future<List<StockTransactionModel>> _transactionsFor(String stockId) async {
    late final List<dynamic> rows;

    try {
      rows = await _client
          .from(DatabaseTables.inventoryTransactions)
          .select(
            'transaction_type, quantity, remarks, source, created_at, profiles(full_name)',
          )
          .eq('inventory_id', stockId)
          .order('created_at', ascending: false) as List<dynamic>;
    } on PostgrestException {
      rows = await _client
          .from(DatabaseTables.inventoryTransactions)
          .select(
            'transaction_type, quantity, remarks, created_at, profiles(full_name)',
          )
          .eq('inventory_id', stockId)
          .order('created_at', ascending: false) as List<dynamic>;
    }

    return rows.map((row) {
      final data = row as Map<String, dynamic>;
      final profile = data['profiles'] as Map<String, dynamic>?;

      return StockTransactionModel(
        type: data['source'] == 'sale'
            ? StockTransactionType.sale
            : _transactionTypeFromDb(data['transaction_type'] as String?),
        quantity: _toDouble(data['quantity']),
        performedAt: _parseDate(data['created_at']) ?? DateTime.now(),
        remarks: data['remarks'] as String? ?? 'No remarks.',
        performedBy: profile?['full_name'] as String? ?? 'SeedRover User',
      );
    }).toList(growable: false);
  }

  Future<List<SalesTransactionModel>> _salesFor(String stockId) async {
    late final List<dynamic> rows;

    try {
      rows = await _client
          .from(DatabaseTables.salesTransactions)
          .select(
            'id, inventory_id, quantity_sold, unit_price, total_amount, sale_date, customer_name, remarks, status, profiles(full_name)',
          )
          .eq('inventory_id', stockId)
          .order('sale_date', ascending: false) as List<dynamic>;
    } on PostgrestException {
      return const [];
    }

    return rows.map((row) {
      final data = row as Map<String, dynamic>;
      final profile = data['profiles'] as Map<String, dynamic>?;

      return SalesTransactionModel(
        id: data['id'] as String,
        inventoryId: data['inventory_id'] as String,
        quantitySold: _toDouble(data['quantity_sold']),
        unitPrice: _toDouble(data['unit_price']),
        totalAmount: _toDouble(data['total_amount']),
        saleDate: _parseDate(data['sale_date']) ?? DateTime.now(),
        recordedBy: profile?['full_name'] as String? ?? 'SeedRover User',
        customerName: data['customer_name'] as String?,
        remarks: data['remarks'] as String?,
        status: data['status'] == 'Voided'
            ? SalesTransactionStatus.voided
            : SalesTransactionStatus.completed,
      );
    }).toList(growable: false);
  }

  SalesTransactionModel _saleFromResponse(
    Object? response,
    RecordSaleRequest request,
  ) {
    final data = response is Map<String, dynamic> ? response : const {};

    return SalesTransactionModel(
      id: data['id'] as String? ??
          'local-sale-${DateTime.now().microsecondsSinceEpoch}',
      inventoryId: data['inventory_id'] as String? ?? request.stock.id,
      quantitySold: _toDouble(data['quantity_sold'] ?? request.quantitySold),
      unitPrice: _toDouble(data['unit_price'] ?? request.unitPrice),
      totalAmount: _toDouble(data['total_amount'] ?? request.totalAmount),
      saleDate: _parseDate(data['sale_date']) ?? request.saleDate,
      recordedBy: 'SeedRover User',
      customerName:
          data['customer_name'] as String? ?? request.customerName,
      remarks: data['remarks'] as String? ?? request.remarks,
      status: data['status'] == 'Voided'
          ? SalesTransactionStatus.voided
          : SalesTransactionStatus.completed,
    );
  }

  Map<String, Object?> _stockPayload(StockModel stock) {
    return {
      'item_name': stock.name,
      'stock_code': stock.displayId == 'STK-000' ? null : stock.displayId,
      'unit': stock.unit,
      'minimum_quantity': stock.minimumStockLevel,
      'unit_cost': stock.unitCost,
      'selling_price': stock.sellingPrice,
      'image_path': stock.imagePath,
      'storage_location': stock.storageLocation,
      'category': _categoryToDb(stock.category),
      'updated_by': _client.auth.currentUser?.id,
    };
  }

  Map<String, Object?> _legacyStockPayload(Map<String, Object?> payload) {
    return {
      for (final entry in payload.entries)
        if (entry.key != 'unit_cost' && entry.key != 'selling_price')
          entry.key: entry.value,
    };
  }

  Future<void> _recordActivity({
    required String activity,
    required String description,
  }) async {
    try {
      await _client.from(DatabaseTables.activityLogs).insert({
        'user_id': _client.auth.currentUser?.id,
        'activity': activity,
        'description': description,
        'module': 'Stocks',
      });
    } catch (_) {
      // Activity logging should not block the inventory action itself.
    }
  }

  bool _needsLegacySaleParams(String message) {
    return message.contains('p_payment_method') ||
        message.contains('p_transaction_reference') ||
        message.contains('p_other_payment_method') ||
        message.contains('record_inventory_sale');
  }

  StockCategory _categoryFromDb(String? value) {
    return switch (value) {
      'Leafy Vegetables' => StockCategory.leafyVegetables,
      'Fruit Vegetables' => StockCategory.fruitVegetables,
      'Legumes' => StockCategory.legumes,
      'Root Crops' => StockCategory.rootCrops,
      'Fruits' => StockCategory.fruits,
      'Herbs' => StockCategory.herbs,
      'Prepared Produce' => StockCategory.preparedProduce,
      'Others' => StockCategory.others,
      'Seeds' => StockCategory.legumes,
      'Fertilizer' => StockCategory.herbs,
      'Consumables' => StockCategory.fruitVegetables,
      'Hardware' || 'Tools' => StockCategory.others,
      _ => StockCategory.others,
    };
  }

  String _categoryToDb(StockCategory category) {
    return category.label;
  }

  StockTransactionType _transactionTypeFromDb(String? value) {
    return switch (value) {
      'OUT' => StockTransactionType.stockOut,
      'ADJUSTMENT' => StockTransactionType.adjustment,
      _ => StockTransactionType.stockIn,
    };
  }

  String _supplierFrom(List<StockTransactionModel> transactions) {
    for (final transaction in transactions) {
      if (transaction.type == StockTransactionType.stockIn) {
        return transaction.performedBy;
      }
    }

    return 'Farm Harvest';
  }

  String _notesFrom(List<StockTransactionModel> transactions) {
    if (transactions.isEmpty) {
      return 'Inventory item loaded from Supabase.';
    }

    return transactions.first.remarks;
  }

  String _displayIdFor(int index) {
    return 'STK-${(index + 1).toString().padLeft(3, '0')}';
  }

  Future<String> _nextStockCode() async {
    final rows = await _client
        .from(DatabaseTables.inventory)
        .select('stock_code') as List<dynamic>;
    var maxNumber = 0;

    for (final row in rows) {
      final code = (row as Map<String, dynamic>)['stock_code'] as String?;
      final match = RegExp(r'^STK-(\d+)$').firstMatch(code ?? '');
      final number = int.tryParse(match?.group(1) ?? '') ?? 0;

      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    return 'STK-${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  String _displayIdFromUuid(String stockId) {
    final digits = stockId.replaceAll(RegExp(r'[^0-9]'), '');
    final safeDigits = digits.isEmpty
        ? '1'
        : digits.substring(0, digits.length < 3 ? digits.length : 3);
    final value = int.parse(safeDigits);

    return 'STK-${value.toString().padLeft(3, '0')}';
  }

  Future<String> _uploadStockImage({
    required String stockId,
    required StockImageUpload upload,
  }) async {
    final extension = _extensionFor(upload.fileName, upload.mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedName = upload.fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '-')
        .toLowerCase();
    final baseName = normalizedName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final path = '$stockId/$timestamp-$baseName.$extension';

    await _client.storage.from(_stockImagesBucket).uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(
            contentType: upload.mimeType,
            upsert: true,
          ),
        );

    return path;
  }

  String? _publicImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage.from(_stockImagesBucket).getPublicUrl(imagePath);
  }

  String _extensionFor(String fileName, String mimeType) {
    final normalizedName = fileName.toLowerCase();

    if (normalizedName.endsWith('.png') || mimeType == 'image/png') {
      return 'png';
    }

    if (normalizedName.endsWith('.webp') || mimeType == 'image/webp') {
      return 'webp';
    }

    return 'jpg';
  }

  String _cleanRemarks(String value, {required String fallback}) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  double _toDouble(Object? value) {
    return (value as num?)?.toDouble() ?? 0;
  }

  double? _nullableDouble(Object? value) {
    return (value as num?)?.toDouble();
  }

  Future<void> _recordPricingActivities({
    required StockModel previous,
    required StockModel next,
  }) async {
    if (previous.unitCost != next.unitCost) {
      await _recordActivity(
        activity: 'Unit Cost Updated',
        description: '${next.name}: unit cost updated.',
      );
    }

    if (previous.sellingPrice != next.sellingPrice) {
      await _recordActivity(
        activity: 'Selling Price Updated',
        description: '${next.name}: selling price updated.',
      );
    }
  }
}

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(supabaseClientProvider)),
);
