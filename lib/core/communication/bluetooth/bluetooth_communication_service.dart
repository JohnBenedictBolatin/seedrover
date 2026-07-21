import '../shared/communication_device.dart';
import '../shared/communication_enums.dart';
import '../shared/simulated_communication_service.dart';

class BluetoothCommunicationService extends SimulatedCommunicationService {
  BluetoothCommunicationService()
      : super(
          transport: CommunicationTransport.bluetooth,
          devices: const [
            CommunicationDevice(
              name: 'SeedRover BT',
              id: 'BT-SEEDROVER-001',
              signalStrength: -54,
              isAvailable: true,
              connectionState: CommunicationConnectionState.disconnected,
              transport: CommunicationTransport.bluetooth,
            ),
            CommunicationDevice(
              name: 'SeedRover Backup BT',
              id: 'BT-SEEDROVER-002',
              signalStrength: -72,
              isAvailable: true,
              connectionState: CommunicationConnectionState.disconnected,
              transport: CommunicationTransport.bluetooth,
            ),
          ],
        );
}
