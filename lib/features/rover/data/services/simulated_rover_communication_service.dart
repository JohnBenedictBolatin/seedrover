import '../../../../core/communication/shared/communication_message.dart';
import '../../../../core/communication/shared/communication_response.dart';
import '../../../../core/communication/shared/communication_service.dart';

class SimulatedRoverCommunicationService implements CommunicationService {
  const SimulatedRoverCommunicationService();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<CommunicationResponse> send(CommunicationMessage message) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    return CommunicationResponse(
      status: 'success',
      timestamp: DateTime.now(),
      data: _dataFor(message.command),
    );
  }

  Map<String, Object?> _dataFor(String command) {
    return switch (command) {
      'GET_ROBOT_STATUS' => const {
          'battery_level': 84,
          'seed_level': 67,
          'wifi_connected': true,
          'bluetooth_connected': true,
          'camera_connected': true,
        },
      'GET_SENSOR_DATA' => const {
          'soil_moisture': 42,
          'soil_temperature': 28,
          'environment_temperature': 31,
          'humidity': 72,
        },
      'START_PLANTING' => const {'planting_status': 'active'},
      'EMERGENCY_STOP' => const {'planting_status': 'stopped'},
      _ => const {},
    };
  }
}
