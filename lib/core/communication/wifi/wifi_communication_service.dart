import '../shared/communication_device.dart';
import '../shared/communication_enums.dart';
import '../shared/simulated_communication_service.dart';

class WiFiCommunicationService extends SimulatedCommunicationService {
  WiFiCommunicationService()
      : super(
          transport: CommunicationTransport.wifi,
          devices: const [
            CommunicationDevice(
              name: 'SeedRover Wi-Fi',
              id: 'WIFI-SEEDROVER-001',
              signalStrength: -42,
              isAvailable: true,
              connectionState: CommunicationConnectionState.disconnected,
              transport: CommunicationTransport.wifi,
            ),
          ],
        );
}
