import 'dart:math';

import '../../../../shared/models/action_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/constants/shared_workflow_terms.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/app_input_formatters.dart';
import '../../../../core/utils/business_calendar.dart';
import '../models/inventory_history_model.dart';
import '../models/stock_model.dart';
import '../models/sales_period_aggregation.dart';

class StockRepository {
  const StockRepository(this._client);

  static const _stockImagesBucket = 'stock-images';
  static const _inventoryColumns =
      'id, stock_code, item_name, quantity, unit, minimum_quantity, unit_cost, selling_price, image_path, storage_location, '
      'category, notes, spoilage_profile_id, created_at, updated_at';
  static const _legacyInventoryColumns =
      'id, stock_code, item_name, quantity, unit, minimum_quantity, image_path, storage_location, '
      'category, notes, created_at, updated_at';

  final SupabaseClient _client;
  String? get currentAccountId => _client.auth.currentUser?.id;

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

  Future<InventoryHistoryPage> getInventoryHistoryPage({
    required int pageIndex,
    int pageSize = 5,
  }) async {
    final results = await Future.wait<Object>([
      _client
          .from(DatabaseTables.inventoryTransactions)
          .select(
            'transaction_type, quantity, remarks, source, created_at, inventory(item_name, stock_code)',
          )
          .order('created_at', ascending: false)
          .range(pageIndex * pageSize, (pageIndex + 1) * pageSize - 1),
      _client
          .from(DatabaseTables.inventoryTransactions)
          .count(CountOption.exact),
    ]);
    final rows = results.first as List<dynamic>;
    return InventoryHistoryPage(
      records: rows
          .map((row) => InventoryHistoryRecord.fromJson(
                row as Map<String, dynamic>,
              ))
          .toList(growable: false),
      total: results[1] as int,
    );
  }

  Future<StockModel> createStock(
    StockModel stock, {
    StockImageUpload? imageUpload,
  }) async {
    if (stock.name.trim().isEmpty ||
        stock.storageLocation.trim().isEmpty ||
        stock.unit.trim().isEmpty ||
        stock.currentQuantity < 0 ||
        stock.minimumStockLevel < 0 ||
        stock.unitCost == null ||
        stock.sellingPrice == null ||
        imageUpload == null) {
      throw ArgumentError(
        'Item name, quantity details, prices, storage location, and image are required.',
      );
    }

    final row = await _insertStock(stock);
    final stockId = row['id'] as String;
    try {
      final imagePath = await _uploadStockImage(
        stockId: stockId,
        upload: imageUpload,
      );

      await _client
          .from(DatabaseTables.inventory)
          .update({'image_path': imagePath}).eq('id', stockId);

      await _recordActivity(
        activity: 'Inventory item created',
        description: '${stock.name} inventory item created.',
      );

      return await _stockById(stockId).then(
        (createdStock) => createdStock.copyWith(
          notes: stock.notes,
          imagePath: imagePath,
          imageUrl: _publicImageUrl(imagePath),
          imageAssetPath: stock.imageAssetPath,
        ),
      );
    } catch (_) {
      throw UnconfirmedWrite(
          'The item was created, but its photo or details could not be confirmed. Check inventory before creating it again.',
          stockId: stockId);
    }
  }

  Future<StockModel> updateStock(StockModel stock) async {
    final previousStock = await _stockById(stock.id);

    await _updateStockRow(stock);

    try {
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
    } catch (_) {
      throw UnconfirmedWrite(
          'The item update was sent, but its refreshed details could not be confirmed.',
          stockId: stock.id);
    }
  }

  Future<void> deleteStock(String stockId) async {
    await _client.from(DatabaseTables.inventory).delete().eq('id', stockId);
    try {
      await _recordActivity(
        activity: 'Inventory item deleted',
        description: 'Inventory item deleted.',
      );
    } catch (_) {
      throw UnconfirmedWrite(
          'The deletion was sent, but its activity record could not be confirmed.',
          stockId: stockId);
    }
  }

  Future<StockSalesSummaryModel> getSalesSummary() async {
    final now = BusinessCalendar.now();
    final weekStart = BusinessCalendar.startOfWeek(now);
    final yearStart = BusinessCalendar.startOfYear(now);
    final queryStart = weekStart.isBefore(yearStart) ? weekStart : yearStart;
    final asOf = now.toIso8601String();
    const pageSize = 500;
    final rows = <dynamic>[];
    for (var offset = 0;; offset += pageSize) {
      final page = await _client
          .from(DatabaseTables.salesTransactions)
          .select('id, quantity_sold, total_amount, sale_date, status')
          .gte('sale_date', queryStart.toUtc().toIso8601String())
          .lt('sale_date', asOf)
          .order('sale_date', ascending: false)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1) as List<dynamic>;
      rows.addAll(page);
      if (page.length < pageSize) {
        break;
      }
    }

    final orderItems = <dynamic>[];
    for (var offset = 0;; offset += pageSize) {
      final page = await _client
          .from(DatabaseTables.salesOrderItems)
          .select(
            'id, sales_order_id, quantity_sold, sales_orders!inner(sale_date, status)',
          )
          .eq('sales_orders.status', 'Completed')
          .gte('sales_orders.sale_date', queryStart.toUtc().toIso8601String())
          .lt('sales_orders.sale_date', asOf)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1) as List<dynamic>;
      orderItems.addAll(page);
      if (page.length < pageSize) {
        break;
      }
    }

    // Receipt totals are authoritative: summing item line totals would ignore
    // receipt-level discounts and make mobile sales exceed the web summary.
    final receiptOrders = <dynamic>[];
    for (var offset = 0;; offset += pageSize) {
      final page = await _client
          .from(DatabaseTables.salesOrders)
          .select('id, total_amount, sale_date, status')
          .eq('status', 'Completed')
          .gte('sale_date', queryStart.toUtc().toIso8601String())
          .lt('sale_date', asOf)
          .order('sale_date', ascending: false)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1) as List<dynamic>;
      receiptOrders.addAll(page);
      if (page.length < pageSize) break;
    }

    final standaloneSales = <SalesAggregateRecord>[];
    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      final saleDate = _parseDate(data['sale_date']);
      if (saleDate == null) continue;
      standaloneSales.add(SalesAggregateRecord(
        id: data['id']?.toString() ?? '',
        date: saleDate,
        total: _toDouble(data['total_amount']),
        quantity: _toDouble(data['quantity_sold']),
        status: data['status']?.toString() ?? '',
      ));
    }

    final receipts = <SalesAggregateRecord>[];
    for (final row in receiptOrders) {
      final data = row as Map<String, dynamic>;
      final saleDate = _parseDate(data['sale_date']);
      if (saleDate == null) continue;
      receipts.add(SalesAggregateRecord(
        id: data['id']?.toString() ?? '',
        date: saleDate,
        total: _toDouble(data['total_amount']),
        status: data['status']?.toString() ?? '',
      ));
    }

    final receiptLines = <SalesReceiptLineCount>[];
    for (final row in orderItems) {
      final data = row as Map<String, dynamic>;
      final order = data['sales_orders'] as Map<String, dynamic>?;
      if (order == null) continue;
      final saleDate = _parseDate(order['sale_date']);
      if (saleDate == null) continue;
      receiptLines.add(SalesReceiptLineCount(
        receiptId: data['sales_order_id']?.toString() ?? '',
        date: saleDate,
        quantity: _toDouble(data['quantity_sold']),
        status: order['status']?.toString() ?? '',
      ));
    }

    return aggregateSalesPeriods(
      standaloneSales: standaloneSales,
      receipts: receipts,
      receiptLines: receiptLines,
      asOf: now,
    );
  }

  Future<List<StockSalesTrendRecord>> getSalesTrendRecords() async {
    final now = BusinessCalendar.now();
    final start = BusinessCalendar.startOfYear(now).toUtc().toIso8601String();
    final end = now.toIso8601String();
    const pageSize = 500;
    final records = <StockSalesTrendRecord>[];

    Future<void> appendPages(
        {required String table, required String amountColumn}) async {
      for (var offset = 0;; offset += pageSize) {
        final page = await _client
            .from(table)
            .select('id, sale_date, $amountColumn, status')
            .eq('status', 'Completed')
            .gte('sale_date', start)
            .lt('sale_date', end)
            .order('sale_date', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1) as List<dynamic>;
        for (final row in page) {
          final data = row as Map<String, dynamic>;
          final date = _parseDate(data['sale_date']);
          if (date != null) {
            records.add(StockSalesTrendRecord(
              id: data['id'] as String,
              date: date,
              total: _toDouble(data[amountColumn]),
            ));
          }
        }
        if (page.length < pageSize) break;
      }
    }

    await Future.wait([
      appendPages(
          table: DatabaseTables.salesTransactions,
          amountColumn: 'total_amount'),
      appendPages(
          table: DatabaseTables.salesOrders, amountColumn: 'total_amount'),
    ]);
    records.sort((left, right) => left.date.compareTo(right.date));
    return records;
  }

  Future<List<ExistingSaleCustomer>> getExistingSaleCustomers() async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (final table in [
      DatabaseTables.salesOrders,
      DatabaseTables.salesTransactions,
    ]) {
      for (var offset = 0;; offset += pageSize) {
        final page = await _client
            .from(table)
            .select('customer_name, customer_contact, sale_date, id')
            .eq('status', 'Completed')
            .order('sale_date', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1) as List<dynamic>;
        rows.addAll(page.cast<Map<String, dynamic>>());
        if (page.length < pageSize) break;
      }
    }

    final customers = <String, ExistingSaleCustomer>{};
    for (final row in rows) {
      final name = (row['customer_name'] as String? ?? '')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty) continue;
      String contact;
      try {
        contact = AppInputFormatters.normalizeContactNumber(
          row['customer_contact'] as String?,
          required: true,
        )!;
      } on FormatException {
        continue;
      }
      final key = '${name.toLowerCase()}::$contact';
      customers.putIfAbsent(
        key,
        () => ExistingSaleCustomer(name: name, contact: contact),
      );
    }

    return customers.values.toList()
      ..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));
  }

  Future<StockModel> stockIn({
    required StockModel stock,
    required double quantity,
    required String supplier,
    required String remarks,
    String? requestId,
  }) async {
    final supplierText = supplier.trim();
    final receiptRemarks = _cleanRemarks(remarks, fallback: 'Stock added.');
    await _insertTransaction(
      stockId: stock.id,
      type: 'IN',
      quantity: quantity,
      source: 'manual',
      requestId: requestId ?? _newRequestId(),
      remarks: [
        if (supplierText.isNotEmpty) 'Source: $supplierText',
        receiptRemarks,
      ].join('\n'),
    );

    try {
      await _recordActivity(
        activity: 'Receive stock recorded',
        description: '${stock.name}: $quantity ${stock.unit} added.',
      );

      return await _stockById(stock.id).then(
        (updatedStock) => updatedStock.copyWith(
          displayId: stock.displayId,
          imagePath: stock.imagePath,
          imageUrl: stock.imageUrl,
          imageAssetPath: stock.imageAssetPath,
        ),
      );
    } catch (_) {
      throw UnconfirmedWrite(
          'The stock receipt was sent, but its refreshed balance could not be confirmed.',
          stockId: stock.id);
    }
  }

  Future<StockModel> stockOut({
    required StockModel stock,
    required double quantity,
    required String purpose,
    required String remarks,
    String? requestId,
    String? batchId,
  }) async {
    final purposeText = purpose.trim().isEmpty ? 'Stock used.' : purpose.trim();
    final remarksText = remarks.trim().isEmpty ? purposeText : remarks.trim();

    await _insertTransaction(
      stockId: stock.id,
      type: 'OUT',
      quantity: quantity,
      remarks: '$purposeText - $remarksText',
      requestId: requestId ?? _newRequestId(),
      targetBatchId: batchId,
    );

    try {
      await _recordActivity(
        activity: 'Issue stock recorded',
        description: '${stock.name}: $quantity ${stock.unit} deducted.',
      );

      return await _stockById(stock.id).then(
        (updatedStock) => updatedStock.copyWith(
          displayId: stock.displayId,
          imagePath: stock.imagePath,
          imageUrl: stock.imageUrl,
          imageAssetPath: stock.imageAssetPath,
        ),
      );
    } catch (_) {
      throw UnconfirmedWrite(
          'The stock issue was sent, but its refreshed balance could not be confirmed.',
          stockId: stock.id);
    }
  }

  Future<StockModel> recordSale(RecordSaleRequest request) async {
    final customerContact = AppInputFormatters.normalizeContactNumber(
      request.customerContact,
      required: true,
    )!;
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
    final response = await _client.rpc(
      'record_inventory_sale_receipt',
      params: {
        ...params,
        'p_customer_contact': customerContact,
      },
    );
    try {
      final sale = _saleFromResponse(response, request);
      final saleTransaction = StockTransactionModel(
        type: StockTransactionType.sale,
        quantity: request.quantitySold,
        performedAt: request.saleDate,
        remarks: 'Sale recorded: PHP ${request.totalAmount.toStringAsFixed(2)}',
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
    } catch (_) {
      throw UnconfirmedWrite(
          'The sale was sent, but its refreshed record could not be confirmed.',
          stockId: request.stock.id);
    }
  }

  Future<StockModel> adjustStock({
    required StockModel stock,
    required double newQuantity,
    required String reason,
    required String remarks,
    String? requestId,
  }) async {
    final reasonText =
        reason.trim().isEmpty ? 'Stock adjusted.' : reason.trim();
    final remarksText = remarks.trim().isEmpty ? reasonText : remarks.trim();

    await _insertTransaction(
      stockId: stock.id,
      type: 'ADJUSTMENT',
      quantity: newQuantity,
      remarks: '$reasonText - $remarksText',
      requestId: requestId ?? _newRequestId(),
    );

    try {
      await _recordActivity(
        activity: 'Stock quantity adjusted',
        description:
            '${stock.name}: stock adjusted to $newQuantity ${stock.unit}.',
      );

      return await _stockById(stock.id).then(
        (updatedStock) => updatedStock.copyWith(
          displayId: stock.displayId,
          imagePath: stock.imagePath,
          imageUrl: stock.imageUrl,
          imageAssetPath: stock.imageAssetPath,
        ),
      );
    } catch (_) {
      throw UnconfirmedWrite(
          'The adjustment was sent, but its refreshed balance could not be confirmed.',
          stockId: stock.id);
    }
  }

  Future<StockModel> _stockById(String stockId) async {
    final row = await _inventoryRowById(stockId);

    return _stockFromRow(row, displayId: _displayIdFromUuid(stockId));
  }

  Future<List<dynamic>> _inventoryRows() async {
    Future<List<dynamic>> fetch(String columns) async {
      const pageSize = 500;
      final rows = <dynamic>[];
      for (var offset = 0;; offset += pageSize) {
        final page = await _client
            .from(DatabaseTables.inventory)
            .select(columns)
            .order('updated_at', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1) as List<dynamic>;
        rows.addAll(page);
        if (page.length < pageSize) return rows;
      }
    }

    try {
      return await fetch(_inventoryColumns);
    } on PostgrestException catch (error) {
      if (!_isLegacyInventorySchemaError(error)) rethrow;
      return fetch(_legacyInventoryColumns);
    }
  }

  Future<Map<String, dynamic>> _inventoryRowById(String stockId) async {
    try {
      return await _client
          .from(DatabaseTables.inventory)
          .select(_inventoryColumns)
          .eq('id', stockId)
          .single();
    } on PostgrestException catch (error) {
      if (!_isLegacyInventorySchemaError(error)) rethrow;
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
      'stock_code': null,
      'quantity': stock.currentQuantity,
    };

    try {
      return await _client
          .from(DatabaseTables.inventory)
          .insert(payload)
          .select(_inventoryColumns)
          .single();
    } on PostgrestException catch (error) {
      if (!_isLegacyInventorySchemaError(error)) rethrow;
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
    } on PostgrestException catch (error) {
      if (!_isLegacyInventorySchemaError(error)) rethrow;
      await _client
          .from(DatabaseTables.inventory)
          .update(_legacyStockPayload(_stockPayload(stock)))
          .eq('id', stock.id)
          .select(_legacyInventoryColumns)
          .single();
    }
  }

  bool _isLegacyInventorySchemaError(PostgrestException error) {
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == 'PGRST204' ||
        error.code == '42703' ||
        (message.contains('schema cache') &&
            (message.contains('column') || message.contains('field'))) ||
        (message.contains('column') && message.contains('does not exist'));
  }

  Future<void> _insertTransaction({
    required String stockId,
    required String type,
    required double quantity,
    required String remarks,
    String? source,
    DateTime? batchReceivedOn,
    DateTime? batchHarvestOn,
    String? batchProfileId,
    String? requestId,
    String? targetBatchId,
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
      if (source != null) 'source': source,
      if (batchReceivedOn != null)
        'batch_received_on': _dateOnly(batchReceivedOn),
      if (batchHarvestOn != null) 'batch_harvest_on': _dateOnly(batchHarvestOn),
      if (batchProfileId != null) 'batch_profile_id': batchProfileId,
      if (requestId != null) 'request_id': requestId,
      if (targetBatchId != null) 'target_batch_id': targetBatchId,
      'performed_by': userId,
    });
  }

  Future<StockModel> _stockFromRow(
    Map<String, dynamic> row, {
    required String displayId,
  }) async {
    final movementData = await _movementDataFor(row['id'] as String);
    final transactions = movementData.transactions;
    final sales = await _salesFor(row['id'] as String);

    return StockModel(
      id: row['id'] as String,
      displayId: row['stock_code'] as String? ?? displayId,
      name: row['item_name'] as String? ?? 'Inventory Item',
      category: _categoryFromDb(row['category'] as String?),
      currentQuantity: _toDouble(row['quantity']),
      unit: 'kg',
      storageLocation: row['storage_location'] as String? ?? 'Unassigned',
      minimumStockLevel: _toDouble(row['minimum_quantity']),
      supplier: _supplierFrom(transactions),
      dateAdded: _parseDate(row['created_at']) ?? DateTime.now(),
      lastUpdated: _parseDate(row['updated_at']) ?? DateTime.now(),
      notes: row['notes'] as String? ?? _notesFrom(transactions),
      transactions: transactions,
      unitCost: _nullableDouble(row['unit_cost']),
      sellingPrice: _nullableDouble(row['selling_price']),
      sales: sales,
      imagePath: row['image_path'] as String?,
      imageUrl: _publicImageUrl(row['image_path'] as String?),
      imageAssetPath: null,
      spoilageProfileId: row['spoilage_profile_id'] as String?,
      batches: movementData.batches,
    );
  }

  Future<
      ({
        List<StockTransactionModel> transactions,
        List<InventoryStockBatch> batches
      })> _movementDataFor(String stockId) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final page = await _client
          .from('inventory_movement_batch_details')
          .select()
          .eq('inventory_id', stockId)
          .order('created_at', ascending: false, nullsFirst: false)
          .order('event_id')
          .range(offset, offset + pageSize - 1) as List<dynamic>;
      rows.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < pageSize) break;
    }

    final batchesById = <String, InventoryStockBatch>{};
    final transactions = <StockTransactionModel>[];
    for (final data in rows) {
      InventoryStockBatch? batch;
      final batchId = data['batch_id'] as String?;
      final receivedOn = data['batch_received_on'] as String?;
      if (batchId != null && receivedOn != null) {
        final estimatedOn = data['batch_estimated_spoilage_on'] as String?;
        batch = InventoryStockBatch(
          id: batchId,
          sourceTransactionId: data['movement_id'] as String?,
          originType: data['batch_origin'] as String? ?? 'historical',
          initialQuantity: _toDouble(data['batch_initial_quantity']),
          remainingQuantity: _toDouble(data['batch_remaining_quantity']),
          receivedOn: _calendarDate(receivedOn),
          harvestOn: data['batch_harvest_on'] == null
              ? null
              : _calendarDate(data['batch_harvest_on'] as String),
          ageKnown: data['batch_age_known'] as bool? ?? false,
          profileId: data['batch_profile_id'] as String?,
          profileName: data['batch_profile_name'] as String?,
          dateBasis: data['batch_date_basis'] as String? ?? 'Age unknown',
          estimatedSpoilageOn:
              estimatedOn == null ? null : _calendarDate(estimatedOn),
          referenceDays: (data['batch_reference_days'] as num?)?.toInt(),
          referenceVersion: (data['batch_reference_version'] as num?)?.toInt(),
          referenceSourceTitle: data['batch_reference_source_title'] as String?,
          referenceSource: data['batch_reference_source_url'] as String?,
          referenceConditions: data['batch_reference_conditions'] as String?,
          referenceNote: data['batch_reference_note'] as String?,
        );
        batchesById.putIfAbsent(batch.id, () => batch!);
      }

      final eventKind = data['event_kind'] as String?;
      final source = data['source'] as String?;
      final transactionType = data['transaction_type'] as String?;
      final type = switch (eventKind) {
        'opening' => StockTransactionType.opening,
        'historical' => StockTransactionType.historical,
        _ => switch (source) {
            'sale' => StockTransactionType.sale,
            'harvest' => StockTransactionType.harvest,
            _ => _transactionTypeFromDb(transactionType),
          },
      };
      final createdAt = _parseDate(data['created_at']);
      final allocatedRows =
          data['allocated_batches'] as List<dynamic>? ?? const [];
      transactions.add(StockTransactionModel(
        id: data['event_id'] as String?,
        type: type,
        quantity: _toDouble(data['quantity']),
        performedAt: createdAt ?? DateTime.utc(1900),
        remarks: data['remarks'] as String? ?? 'No remarks.',
        performedBy: data['performed_by_name'] as String? ?? '',
        source: source,
        batch: batch,
        dateKnown: createdAt != null,
        allocatedBatches: allocatedRows.map((value) {
          final allocation = value as Map<String, dynamic>;
          return StockBatchAllocation(
            batchId: allocation['batch_id'] as String,
            quantity: _toDouble(allocation['quantity']),
            originType: allocation['origin_type'] as String?,
            initialQuantity:
                (allocation['initial_quantity'] as num?)?.toDouble(),
            remainingQuantity:
                (allocation['remaining_quantity'] as num?)?.toDouble(),
            ageKnown: allocation['age_known'] as bool? ?? false,
            receivedOn: allocation['received_on'] == null
                ? null
                : _calendarDate(allocation['received_on'] as String),
            harvestOn: allocation['harvest_on'] == null
                ? null
                : _calendarDate(allocation['harvest_on'] as String),
            dateBasis: allocation['date_basis'] as String? ?? 'Age unknown',
            profileId: allocation['profile_id'] as String?,
            profileName: allocation['profile_name'] as String?,
            referenceVersion:
                (allocation['reference_version'] as num?)?.toInt(),
            referenceDays: (allocation['reference_days'] as num?)?.toInt(),
            referenceSourceTitle:
                allocation['reference_source_title'] as String?,
            referenceSource: allocation['reference_source_url'] as String?,
            referenceConditions: allocation['reference_conditions'] as String?,
            referenceNote: allocation['reference_note'] as String?,
            estimatedSpoilageOn: allocation['estimated_spoilage_on'] == null
                ? null
                : _calendarDate(allocation['estimated_spoilage_on'] as String),
          );
        }).toList(growable: false),
      ));
    }
    return (
      transactions: transactions,
      batches: batchesById.values.toList(growable: false),
    );
  }

  Future<List<SalesTransactionModel>> _salesFor(String stockId) async {
    const pageSize = 500;
    final rows = <dynamic>[];

    try {
      for (var offset = 0;; offset += pageSize) {
        final page = await _client
            .from(DatabaseTables.salesTransactions)
            .select(
              'id, inventory_id, quantity_sold, unit_price, total_amount, sale_date, customer_name, customer_contact, remarks, status, profiles(full_name)',
            )
            .eq('inventory_id', stockId)
            .order('sale_date', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1) as List<dynamic>;
        rows.addAll(page);
        if (page.length < pageSize) {
          break;
        }
      }
    } on PostgrestException {
      // Keep loading receipt sales if the legacy sale table is unavailable.
    }

    final sales = rows
        .map((row) {
          final data = row as Map<String, dynamic>;
          final profile = data['profiles'] as Map<String, dynamic>?;
          final saleDate = _parseDate(data['sale_date']);
          if (saleDate == null) return null;

          return SalesTransactionModel(
            id: data['id'] as String,
            inventoryId: data['inventory_id'] as String,
            quantitySold: _toDouble(data['quantity_sold']),
            unitPrice: _toDouble(data['unit_price']),
            totalAmount: _toDouble(data['total_amount']),
            saleDate: saleDate,
            recordedBy: profile?['full_name'] as String? ?? 'SeedRover User',
            customerName: data['customer_name'] as String?,
            customerContact: data['customer_contact'] as String?,
            remarks: data['remarks'] as String?,
            status: data['status'] == 'Voided'
                ? SalesTransactionStatus.voided
                : SalesTransactionStatus.completed,
          );
        })
        .whereType<SalesTransactionModel>()
        .toList();

    final receiptRows = <dynamic>[];
    try {
      for (var offset = 0;; offset += pageSize) {
        final page = await _client
            .from(DatabaseTables.salesOrderItems)
            .select(
              'id, inventory_id, quantity_sold, unit_price, line_total, sales_orders!inner(id, sale_date, customer_name, customer_contact, remarks, status, profiles(full_name))',
            )
            .eq('inventory_id', stockId)
            .range(offset, offset + pageSize - 1) as List<dynamic>;
        receiptRows.addAll(page);
        if (page.length < pageSize) {
          break;
        }
      }
    } on PostgrestException {
      // Receipt sales remain optional on older database deployments.
    }

    for (final row in receiptRows) {
      final data = row as Map<String, dynamic>;
      final order = data['sales_orders'] as Map<String, dynamic>?;
      if (order == null) continue;
      final saleDate = _parseDate(order['sale_date']);
      if (saleDate == null) continue;
      final profile = order['profiles'] as Map<String, dynamic>?;
      sales.add(SalesTransactionModel(
        id: order['id'] as String,
        inventoryId: data['inventory_id'] as String,
        quantitySold: _toDouble(data['quantity_sold']),
        unitPrice: _toDouble(data['unit_price']),
        totalAmount: _toDouble(data['line_total']),
        saleDate: saleDate,
        recordedBy: profile?['full_name'] as String? ?? 'SeedRover User',
        customerName: order['customer_name'] as String?,
        customerContact: order['customer_contact'] as String?,
        remarks: order['remarks'] as String?,
        status: order['status'] == 'Voided'
            ? SalesTransactionStatus.voided
            : SalesTransactionStatus.completed,
      ));
    }

    sales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return sales;
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
      customerName: data['customer_name'] as String? ?? request.customerName,
      customerContact:
          data['customer_contact'] as String? ?? request.customerContact,
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
      'unit': 'kg',
      'minimum_quantity': stock.minimumStockLevel,
      'unit_cost': stock.unitCost,
      'selling_price': stock.sellingPrice,
      'image_path': stock.imagePath,
      'storage_location': stock.storageLocation,
      'notes': stock.notes,
      'category': _categoryToDb(stock.category),
      'updated_by': _client.auth.currentUser?.id,
    };
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime _calendarDate(String value) {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Map<String, Object?> _legacyStockPayload(Map<String, Object?> payload) {
    return {
      for (final entry in payload.entries)
        if (entry.key != 'unit_cost' &&
            entry.key != 'selling_price' &&
            entry.key != 'notes' &&
            entry.key != 'spoilage_profile_id' &&
            entry.key != 'initial_received_on' &&
            entry.key != 'initial_harvest_on')
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
        'module': 'Inventory',
      });
    } catch (_) {
      // Activity logging should not block the inventory action itself.
    }
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
      if (transaction.type == StockTransactionType.stockIn ||
          transaction.type == StockTransactionType.harvest) {
        final supplier = RegExp(
          r'(?:^|\n)Source:\s*(.+)$',
          multiLine: true,
        ).firstMatch(transaction.remarks)?.group(1)?.trim();
        if (supplier != null && supplier.isNotEmpty) {
          return supplier;
        }

        return transaction.source ?? transaction.performedBy;
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
    if (upload.bytes.length > SharedWorkflowRules.photoMaxBytes) {
      throw Exception('Stock photos must be 5 MB or smaller.');
    }
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
