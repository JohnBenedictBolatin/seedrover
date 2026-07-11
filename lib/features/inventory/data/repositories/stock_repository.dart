import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/stock_model.dart';

class StockRepository {
  const StockRepository(this._client);

  static const _stockImagesBucket = 'stock-images';

  final SupabaseClient _client;

  Stream<List<StockModel>> watchStocks() {
    return _client
        .from(DatabaseTables.inventory)
        .stream(primaryKey: ['id'])
        .order('updated_at')
        .asyncMap((_) => getStocks());
  }

  Future<List<StockModel>> getStocks() async {
    final rows = await _client
        .from(DatabaseTables.inventory)
        .select(
          'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
          'category, created_at, updated_at',
        )
        .order('updated_at', ascending: false) as List<dynamic>;

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
    final row = await _client
        .from(DatabaseTables.inventory)
        .insert({
          ..._stockPayload(stock),
          'stock_code': await _nextStockCode(),
          'quantity': stock.currentQuantity,
        })
        .select(
          'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
          'category, created_at, updated_at',
        )
        .single();
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
      activity: 'Inventory Created',
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
    final row = await _client
        .from(DatabaseTables.inventory)
        .update(_stockPayload(stock))
        .eq('id', stock.id)
        .select(
          'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
          'category, created_at, updated_at',
        )
        .single();

    await _recordActivity(
      activity: 'Inventory Updated',
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
      activity: 'Inventory Deleted',
      description: 'Inventory item deleted.',
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
      activity: 'Stock In',
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
      activity: 'Stock Out',
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
      activity: 'Inventory Adjustment',
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
    final row = await _client
        .from(DatabaseTables.inventory)
        .select(
          'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
          'category, created_at, updated_at',
        )
        .eq('id', stockId)
        .single();

    return _stockFromRow(row, displayId: _displayIdFromUuid(stockId));
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
      imagePath: row['image_path'] as String?,
      imageUrl: _publicImageUrl(row['image_path'] as String?),
      imageAssetPath: null,
    );
  }

  Future<List<StockTransactionModel>> _transactionsFor(String stockId) async {
    final rows = await _client
        .from(DatabaseTables.inventoryTransactions)
        .select('transaction_type, quantity, remarks, created_at, profiles(full_name)')
        .eq('inventory_id', stockId)
        .order('created_at', ascending: false) as List<dynamic>;

    return rows.map((row) {
      final data = row as Map<String, dynamic>;
      final profile = data['profiles'] as Map<String, dynamic>?;

      return StockTransactionModel(
        type: _transactionTypeFromDb(data['transaction_type'] as String?),
        quantity: _toDouble(data['quantity']),
        performedAt: _parseDate(data['created_at']) ?? DateTime.now(),
        remarks: data['remarks'] as String? ?? 'No remarks.',
        performedBy: profile?['full_name'] as String? ?? 'SeedRover User',
      );
    }).toList(growable: false);
  }

  Map<String, Object?> _stockPayload(StockModel stock) {
    return {
      'item_name': stock.name,
      'stock_code': stock.displayId == 'STK-000' ? null : stock.displayId,
      'unit': stock.unit,
      'minimum_quantity': stock.minimumStockLevel,
      'image_path': stock.imagePath,
      'storage_location': stock.storageLocation,
      'category': _categoryToDb(stock.category),
      'updated_by': _client.auth.currentUser?.id,
    };
  }

  Future<void> _recordActivity({
    required String activity,
    required String description,
  }) async {
    await _client.from(DatabaseTables.activityLogs).insert({
      'user_id': _client.auth.currentUser?.id,
      'activity': activity,
      'description': description,
      'module': 'Stocks',
    });
  }

  StockCategory _categoryFromDb(String? value) {
    return switch (value) {
      'Seeds' => StockCategory.legumes,
      'Fertilizer' => StockCategory.herbs,
      'Consumables' => StockCategory.fruitVegetables,
      'Hardware' || 'Tools' => StockCategory.others,
      _ => StockCategory.others,
    };
  }

  String _categoryToDb(StockCategory category) {
    return switch (category) {
      StockCategory.legumes => 'Seeds',
      StockCategory.herbs => 'Fertilizer',
      StockCategory.leafyVegetables ||
      StockCategory.fruitVegetables ||
      StockCategory.rootCrops ||
      StockCategory.fruits ||
      StockCategory.preparedProduce => 'Consumables',
      StockCategory.others => 'Consumables',
    };
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
}

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(supabaseClientProvider)),
);
