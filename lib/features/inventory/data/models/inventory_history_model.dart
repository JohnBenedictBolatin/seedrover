class InventoryHistoryPage {
  const InventoryHistoryPage({required this.records, required this.total});

  final List<InventoryHistoryRecord> records;
  final int total;
}

class InventoryHistoryRecord {
  const InventoryHistoryRecord({
    required this.itemName,
    required this.stockCode,
    required this.movementType,
    required this.quantity,
    required this.source,
    required this.createdAt,
    required this.remarks,
  });

  final String itemName;
  final String stockCode;
  final String movementType;
  final double quantity;
  final String source;
  final DateTime createdAt;
  final String remarks;

  factory InventoryHistoryRecord.fromJson(Map<String, dynamic> json) {
    final inventory = _firstRelation(json['inventory']);
    return InventoryHistoryRecord(
      itemName: inventory?['item_name'] as String? ?? 'Unknown item',
      stockCode: inventory?['stock_code'] as String? ?? 'Uncoded',
      movementType: json['transaction_type'] as String? ?? 'Movement',
      quantity: _toDouble(json['quantity']),
      source: json['source'] as String? ?? 'manual',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      remarks: json['remarks'] as String? ?? '',
    );
  }
}

Map<String, dynamic>? _firstRelation(Object? value) {
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

double _toDouble(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
