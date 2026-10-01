enum ActionStatus {
  confirmed,
  savedLocally,
  rejected,
  uncertain,
  verifiedAbsent
}

/// A write was acknowledged, but a subsequent attachment/read failed.
class UnconfirmedWrite implements Exception {
  const UnconfirmedWrite(this.message, {this.stockId});
  final String message;
  final String? stockId;
}

/// A completed Future alone is not evidence that a write succeeded.
class ActionOutcome {
  const ActionOutcome(this.status, [this.message]);
  const ActionOutcome.success() : this(ActionStatus.confirmed);
  const ActionOutcome.failure(String message)
      : this(ActionStatus.rejected, message);
  const ActionOutcome.unknown(String message)
      : this(ActionStatus.uncertain, message);
  const ActionOutcome.verifiedAbsent(String message)
      : this(ActionStatus.verifiedAbsent, message);

  final ActionStatus status;
  final String? message;
  bool get canClose =>
      status == ActionStatus.confirmed || status == ActionStatus.savedLocally;

  static ActionOutcome fromError(String? error) => error == null
      ? const ActionOutcome.success()
      : error.startsWith('Outcome not confirmed:')
          ? ActionOutcome.unknown(error)
          : ActionOutcome.failure(error);
}
