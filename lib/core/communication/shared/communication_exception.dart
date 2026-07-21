class CommunicationException implements Exception {
  const CommunicationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunicationTimeoutException extends CommunicationException {
  const CommunicationTimeoutException()
      : super('The rover did not respond in time.');
}
