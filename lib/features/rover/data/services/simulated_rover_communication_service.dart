import '../../../../core/communication/shared/communication_device.dart';
import '../../../../core/communication/shared/communication_enums.dart';
import '../../../../core/communication/shared/simulated_communication_service.dart';

class SimulatedRoverCommunicationService extends SimulatedCommunicationService {
  SimulatedRoverCommunicationService()
      : super(
          transport: CommunicationTransport.wifi,
          devices: const [
            CommunicationDevice(
              name: 'SeedRover Simulator',
              id: 'SIM-SEEDROVER-001',
              signalStrength: -36,
              isAvailable: true,
              connectionState: CommunicationConnectionState.disconnected,
              transport: CommunicationTransport.wifi,
            ),
          ],
        );
}
