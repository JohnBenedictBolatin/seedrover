class UncertainInventoryWrite {
  const UncertainInventoryWrite(
      {required this.stockId,
      required this.action,
      required this.attempted,
      required this.createdAt,
      this.reference,
      this.operation,
      this.submissionId,
      this.payload});
  final String stockId;
  final String action;
  final String attempted;
  final DateTime createdAt;
  final String? reference;
  final String? operation;
  final String? submissionId;
  final Map<String, Object?>? payload;
}
