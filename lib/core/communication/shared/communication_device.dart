import 'communication_enums.dart';

class CommunicationDevice {
  const CommunicationDevice({
    required this.name,
    required this.id,
    required this.signalStrength,
    required this.isAvailable,
    required this.connectionState,
    required this.transport,
  });

  final String name;
  final String id;
  final int signalStrength;
  final bool isAvailable;
  final CommunicationConnectionState connectionState;
  final CommunicationTransport transport;

  CommunicationDevice copyWith({
    String? name,
    String? id,
    int? signalStrength,
    bool? isAvailable,
    CommunicationConnectionState? connectionState,
    CommunicationTransport? transport,
  }) {
    return CommunicationDevice(
      name: name ?? this.name,
      id: id ?? this.id,
      signalStrength: signalStrength ?? this.signalStrength,
      isAvailable: isAvailable ?? this.isAvailable,
      connectionState: connectionState ?? this.connectionState,
      transport: transport ?? this.transport,
    );
  }
}
