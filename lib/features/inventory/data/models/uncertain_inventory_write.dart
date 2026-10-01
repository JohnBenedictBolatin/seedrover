class UncertainInventoryWrite {
  const UncertainInventoryWrite(
      {required this.stockId,
      required this.action,
      required this.attempted,
      required this.createdAt,
      this.reference});
  final String stockId;
  final String action;
  final String attempted;
  final DateTime createdAt;
  final String? reference;
}
