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

  /// Extracts the optional farmer-entered note from the legacy combined text.
  /// Older movement writes stored the reason/source and note in one field.
  String get note => _actualNote(
        movementType: movementType,
        source: source,
        remarks: remarks,
      );

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

String _actualNote({
  required String movementType,
  required String source,
  required String remarks,
}) {
  final text = remarks.trim();
  if (text.isEmpty || source == 'sale' || source == 'void_sale') return '';

  final lines = text.split('\n').map((line) => line.trim()).toList();
  final firstLine = lines.first;
  if (source == 'manual' && lines.length > 1) {
    return _withoutDefaultNote(lines.skip(1).join('\n'));
  }

  final hasPrefixedReason =
      RegExp(r'^(source|reason):\s*', caseSensitive: false).hasMatch(firstLine);
  if (hasPrefixedReason) {
    final note = lines.length > 1
        ? lines.skip(1).join('\n').trim()
        : _textAfterSeparator(firstLine) ?? '';
    return _withoutDefaultNote(note);
  }

  if (source == 'harvest') {
    final colon = text.indexOf(':');
    if (colon >= 0) return _withoutDefaultNote(text.substring(colon + 1));
  }

  if (movementType.toUpperCase() == 'OUT' ||
      movementType.toUpperCase() == 'ADJUSTMENT') {
    final note = _textAfterSeparator(text);
    if (note != null) {
      final reason = text.substring(0, text.indexOf(' - ')).trim();
      if (note.trim() == reason) return '';
      return _withoutDefaultNote(note);
    }
  }

  return _withoutDefaultNote(text);
}

String? _textAfterSeparator(String text) {
  final separator = text.indexOf(' - ');
  return separator < 0 ? null : text.substring(separator + 3).trim();
}

String _withoutDefaultNote(String note) {
  final value = note.trim();
  if (value.isEmpty ||
      const {
        'Stock added.',
        'Stock received.',
        'Stock issued.',
        'Stock adjusted.',
        'Harvest recorded.',
      }.contains(value)) {
    return '';
  }
  return value;
}
