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
  adjustment;

  String get label {
    return switch (this) {
      StockTransactionType.stockIn => 'Stock In',
      StockTransactionType.stockOut => 'Stock Out',
      StockTransactionType.adjustment => 'Adjustment',
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
  });

  final StockTransactionType type;
  final double quantity;
  final DateTime performedAt;
  final String remarks;
  final String performedBy;
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
    this.imagePath,
    this.imageUrl,
    this.imageAssetPath,
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
  final String? imagePath;
  final String? imageUrl;
  final String? imageAssetPath;

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
    Object? imagePath = _noChange,
    Object? imageUrl = _noChange,
    Object? imageAssetPath = _noChange,
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
      imagePath: imagePath == _noChange ? this.imagePath : imagePath as String?,
      imageUrl: imageUrl == _noChange ? this.imageUrl : imageUrl as String?,
      imageAssetPath: imageAssetPath == _noChange
          ? this.imageAssetPath
          : imageAssetPath as String?,
    );
  }
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
