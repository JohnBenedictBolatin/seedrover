import 'dart:typed_data';

enum StockCategory {
  leafyVegetables,
  fruitVegetables,
  legumes,
  rootCrops,
  fruits,
  herbs,
  preparedProduce,
  others;

  String get label {
    return switch (this) {
      StockCategory.leafyVegetables => 'Leafy Vegetables',
      StockCategory.fruitVegetables => 'Fruit Vegetables',
      StockCategory.legumes => 'Legumes',
      StockCategory.rootCrops => 'Root Crops',
      StockCategory.fruits => 'Fruits',
      StockCategory.herbs => 'Herbs',
      StockCategory.preparedProduce => 'Prepared Produce',
      StockCategory.others => 'Others',
    };
  }
}

enum StockStatus {
  inStock,
  lowStock,
  criticalStock,
  outOfStock;

  String get label {
    return switch (this) {
      StockStatus.inStock => 'In Stock',
      StockStatus.lowStock => 'Low Stock',
      StockStatus.criticalStock => 'Critical Stock',
      StockStatus.outOfStock => 'Out of Stock',
    };
  }
}

enum StockTransactionType {
  stockIn,
  stockOut,
  adjustment,
  sale,
  harvest,
  opening,
  historical;

  String get label {
    return switch (this) {
      StockTransactionType.stockIn => 'Receive stock',
      StockTransactionType.stockOut => 'Issue stock',
      StockTransactionType.adjustment => 'Adjustment',
      StockTransactionType.sale => 'Sale',
      StockTransactionType.harvest => 'Harvest',
      StockTransactionType.opening => 'Opening stock',
      StockTransactionType.historical => 'Historical batch',
    };
  }
}

class StockTransactionModel {
  const StockTransactionModel({
    required this.type,
    required this.quantity,
    required this.performedAt,
    required this.remarks,
    required this.performedBy,
    this.source,
    this.id,
    this.batch,
    this.allocatedBatches = const [],
    this.dateKnown = true,
  });

  final String? id;
  final StockTransactionType type;
  final double quantity;
  final DateTime performedAt;
  final String remarks;
  final String performedBy;
  final String? source;
  final InventoryStockBatch? batch;
  final List<StockBatchAllocation> allocatedBatches;
  final bool dateKnown;
}

class StockBatchAllocation {
  const StockBatchAllocation({
    required this.batchId,
    required this.quantity,
    this.originType,
    this.initialQuantity,
    this.remainingQuantity,
    this.ageKnown = false,
    this.receivedOn,
    this.harvestOn,
    this.dateBasis = 'Age unknown',
    this.profileId,
    this.profileName,
    this.referenceVersion,
    this.referenceDays,
    this.referenceSourceTitle,
    this.referenceSource,
    this.referenceConditions,
    this.referenceNote,
    this.estimatedSpoilageOn,
  });

  final String batchId;
  final double quantity;
  final String? originType;
  final double? initialQuantity;
  final double? remainingQuantity;
  final bool ageKnown;
  final DateTime? receivedOn;
  final DateTime? harvestOn;
  final String dateBasis;
  final String? profileId;
  final String? profileName;
  final int? referenceVersion;
  final int? referenceDays;
  final String? referenceSourceTitle;
  final String? referenceSource;
  final String? referenceConditions;
  final String? referenceNote;
  final DateTime? estimatedSpoilageOn;
}

class ExistingSaleCustomer {
  const ExistingSaleCustomer({required this.name, required this.contact});

  final String name;
  final String contact;
}

class StockModel {
  const StockModel({
    required this.id,
    required this.displayId,
    required this.name,
    required this.category,
    required this.currentQuantity,
    required this.unit,
    required this.storageLocation,
    required this.minimumStockLevel,
    required this.supplier,
    required this.dateAdded,
    required this.lastUpdated,
    required this.notes,
    required this.transactions,
    this.unitCost,
    this.sellingPrice,
    this.sales = const [],
    this.imagePath,
    this.imageUrl,
    this.imageAssetPath,
    this.spoilageProfileId,
    this.batches = const [],
    this.initialStockReceivedOn,
  });

  final String id;
  final String displayId;
  final String name;
  final StockCategory category;
  final double currentQuantity;
  final String unit;
  final String storageLocation;
  final double minimumStockLevel;
  final String supplier;
  final DateTime dateAdded;
  final DateTime lastUpdated;
  final String notes;
  final List<StockTransactionModel> transactions;
  final double? unitCost;
  final double? sellingPrice;
  final List<SalesTransactionModel> sales;
  final String? imagePath;
  final String? imageUrl;
  final String? imageAssetPath;
  final String? spoilageProfileId;
  final List<InventoryStockBatch> batches;
  final DateTime? initialStockReceivedOn;

  StockStatus get status {
    if (currentQuantity <= 0) {
      return StockStatus.outOfStock;
    }

    if (currentQuantity <= minimumStockLevel * 0.5) {
      return StockStatus.criticalStock;
    }

    if (currentQuantity <= minimumStockLevel) {
      return StockStatus.lowStock;
    }

    return StockStatus.inStock;
  }

  double get currentStockValue {
    return currentQuantity * (unitCost ?? 0);
  }

  double get estimatedSalesValue {
    return currentQuantity * (sellingPrice ?? 0);
  }

  double get quantitySold {
    final completedSales = sales.where(
      (sale) => sale.status == SalesTransactionStatus.completed,
    );

    if (completedSales.isNotEmpty) {
      return completedSales.fold<double>(
        0,
        (total, sale) => total + sale.quantitySold,
      );
    }

    return transactions
        .where((transaction) => transaction.type == StockTransactionType.sale)
        .fold<double>(0, (total, transaction) => total + transaction.quantity);
  }

  double get totalSalesValue {
    final completedSales = sales.where(
      (sale) => sale.status == SalesTransactionStatus.completed,
    );

    if (completedSales.isNotEmpty) {
      return completedSales.fold<double>(
        0,
        (total, sale) => total + sale.totalAmount,
      );
    }

    return transactions
        .where((transaction) => transaction.type == StockTransactionType.sale)
        .fold<double>(
          0,
          (total, transaction) => total + _saleAmountFrom(transaction.remarks),
        );
  }

  DateTime? get lastSaleDate {
    final completedSales = sales
        .where((sale) => sale.status == SalesTransactionStatus.completed)
        .toList()
      ..sort((left, right) => right.saleDate.compareTo(left.saleDate));

    return completedSales.isEmpty ? null : completedSales.first.saleDate;
  }

  StockModel copyWith({
    String? id,
    String? displayId,
    String? name,
    StockCategory? category,
    double? currentQuantity,
    String? unit,
    String? storageLocation,
    double? minimumStockLevel,
    String? supplier,
    DateTime? dateAdded,
    DateTime? lastUpdated,
    String? notes,
    List<StockTransactionModel>? transactions,
    Object? unitCost = _noChange,
    Object? sellingPrice = _noChange,
    List<SalesTransactionModel>? sales,
    Object? imagePath = _noChange,
    Object? imageUrl = _noChange,
    Object? imageAssetPath = _noChange,
    Object? spoilageProfileId = _noChange,
    List<InventoryStockBatch>? batches,
    DateTime? initialStockReceivedOn,
  }) {
    return StockModel(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      name: name ?? this.name,
      category: category ?? this.category,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      supplier: supplier ?? this.supplier,
      dateAdded: dateAdded ?? this.dateAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      notes: notes ?? this.notes,
      transactions: transactions ?? this.transactions,
      unitCost: unitCost == _noChange ? this.unitCost : unitCost as double?,
      sellingPrice: sellingPrice == _noChange
          ? this.sellingPrice
          : sellingPrice as double?,
      sales: sales ?? this.sales,
      imagePath: imagePath == _noChange ? this.imagePath : imagePath as String?,
      imageUrl: imageUrl == _noChange ? this.imageUrl : imageUrl as String?,
      imageAssetPath: imageAssetPath == _noChange
          ? this.imageAssetPath
          : imageAssetPath as String?,
      spoilageProfileId: spoilageProfileId == _noChange
          ? this.spoilageProfileId
          : spoilageProfileId as String?,
      batches: batches ?? this.batches,
      initialStockReceivedOn:
          initialStockReceivedOn ?? this.initialStockReceivedOn,
    );
  }
}

class InventoryStockBatch {
  const InventoryStockBatch({
    required this.id,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.receivedOn,
    required this.ageKnown,
    this.referenceDays,
    this.referenceVersion,
    this.referenceSourceTitle,
    this.referenceSource,
    this.referenceConditions,
    this.referenceNote,
    this.harvestOn,
    this.profileId,
    this.sourceTransactionId,
    this.originType = 'historical',
    this.profileName,
    this.dateBasis = 'Age unknown',
    this.estimatedSpoilageOn,
  });

  final String id;
  final String? sourceTransactionId;
  final String originType;
  final double initialQuantity;
  final double remainingQuantity;
  final DateTime receivedOn;
  final DateTime? harvestOn;
  final bool ageKnown;
  final int? referenceDays;
  final int? referenceVersion;
  final String? referenceSourceTitle;
  final String? referenceSource;
  final String? referenceConditions;
  final String? referenceNote;
  final String? profileId;
  final String? profileName;
  final String dateBasis;
  final DateTime? estimatedSpoilageOn;
}

enum SalesTransactionStatus {
  completed,
  voided;

  String get label {
    return switch (this) {
      SalesTransactionStatus.completed => 'Completed',
      SalesTransactionStatus.voided => 'Voided',
    };
  }
}

class SalesTransactionModel {
  const SalesTransactionModel({
    required this.id,
    required this.inventoryId,
    required this.quantitySold,
    required this.unitPrice,
    required this.totalAmount,
    required this.saleDate,
    required this.recordedBy,
    required this.status,
    this.customerName,
    this.customerContact,
    this.remarks,
  });

  final String id;
  final String inventoryId;
  final double quantitySold;
  final double unitPrice;
  final double totalAmount;
  final DateTime saleDate;
  final String recordedBy;
  final SalesTransactionStatus status;
  final String? customerName;
  final String? customerContact;
  final String? remarks;
}

class StockSalesSummaryModel {
  const StockSalesSummaryModel({
    required this.salesToday,
    required this.salesThisWeek,
    required this.salesThisMonth,
    required this.unitsSoldThisMonth,
    required this.salesTransactions,
    required this.salesTransactionsToday,
    required this.salesTransactionsThisWeek,
    required this.salesThisYear,
    required this.salesTransactionsThisYear,
  });

  factory StockSalesSummaryModel.empty() {
    return const StockSalesSummaryModel(
      salesToday: 0,
      salesThisWeek: 0,
      salesThisMonth: 0,
      unitsSoldThisMonth: 0,
      salesTransactions: 0,
      salesTransactionsToday: 0,
      salesTransactionsThisWeek: 0,
      salesThisYear: 0,
      salesTransactionsThisYear: 0,
    );
  }

  final double salesToday;
  final double salesThisWeek;
  final double salesThisMonth;
  final double unitsSoldThisMonth;
  final int salesTransactions;
  final int salesTransactionsToday;
  final int salesTransactionsThisWeek;
  final double salesThisYear;
  final int salesTransactionsThisYear;
}

class StockSalesTrendRecord {
  const StockSalesTrendRecord(
      {required this.id, required this.date, required this.total});

  final String id;
  final DateTime date;
  final double total;
}

class RecordSaleRequest {
  const RecordSaleRequest({
    required this.stock,
    required this.quantitySold,
    required this.unitPrice,
    required this.saleDate,
    this.paymentMethod = 'Cash',
    this.transactionReference,
    this.otherPaymentMethod,
    required this.customerName,
    required this.customerContact,
    this.remarks,
  });

  final StockModel stock;
  final double quantitySold;
  final double unitPrice;
  final DateTime saleDate;
  final String paymentMethod;
  final String? transactionReference;
  final String? otherPaymentMethod;
  final String customerName;
  final String customerContact;
  final String? remarks;

  double get totalAmount => quantitySold * unitPrice;
}

class StockImageUpload {
  const StockImageUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

const _noChange = Object();

double _saleAmountFrom(String remarks) {
  final match = RegExp(r'PHP\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(remarks);

  return double.tryParse(match?.group(1) ?? '') ?? 0;
}
