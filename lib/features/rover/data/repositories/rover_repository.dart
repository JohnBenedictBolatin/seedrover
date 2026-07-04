import '../../../../core/communication/shared/communication_message.dart';
import '../../../../core/communication/shared/communication_service.dart';
import '../models/rover_command_model.dart';
import '../models/rover_control_model.dart';

class RoverRepository {
  const RoverRepository({
    required CommunicationService communicationService,
  }) : _communicationService = communicationService;

  final CommunicationService _communicationService;

  Future<RoverControlModel> loadSimulatedStatus() async {
    final statusResponse = await _communicationService.send(
      CommunicationMessage(
        command: 'GET_ROBOT_STATUS',
        timestamp: DateTime.now(),
      ),
    );
    final sensorResponse = await _communicationService.send(
      CommunicationMessage(
        command: 'GET_SENSOR_DATA',
        timestamp: DateTime.now(),
      ),
    );

    final status = statusResponse.data;
    final sensors = sensorResponse.data;

    return RoverControlModel(
      batteryLevel: status['battery_level'] as int? ?? 0,
      seedLevel: status['seed_level'] as int? ?? 0,
      wifiConnected: status['wifi_connected'] as bool? ?? false,
      bluetoothConnected: status['bluetooth_connected'] as bool? ?? false,
      cameraConnected: status['camera_connected'] as bool? ?? false,
      cameraLoading: false,
      sensors: [
        RoverSensorModel(
          label: 'Soil Moisture',
          value: (sensors['soil_moisture'] as num? ?? 0).toDouble(),
          unit: '%',
          status: 'Good',
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: (sensors['soil_temperature'] as num? ?? 0).toDouble(),
          unit: 'C',
          status: 'Moderate',
        ),
        RoverSensorModel(
          label: 'Environmental Temperature',
          value: (sensors['environment_temperature'] as num? ?? 0).toDouble(),
          unit: 'C',
          status: 'Good',
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: (sensors['humidity'] as num? ?? 0).toDouble(),
          unit: '%',
          status: 'Good',
        ),
      ],
    );
  }

  Future<SoilCheckResultModel> checkSoilState() async {
    final sensorResponse = await _communicationService.send(
      CommunicationMessage(
        command: 'GET_SENSOR_DATA',
        timestamp: DateTime.now(),
      ),
    );

    final sensors = sensorResponse.data;
    final soilMoisture = (sensors['soil_moisture'] as num? ?? 0).toDouble();
    final isSuitable = soilMoisture >= 35 && soilMoisture <= 55;

    return SoilCheckResultModel(
      isSuitable: isSuitable,
      message: isSuitable
          ? 'Soil is good for planting.'
          : 'Soil is not ready for planting yet.',
    );
  }

  Future<String> sendMovementCommand(
    RoverMovementCommand command, {
    required int speed,
  }) async {
    final payload = command == RoverMovementCommand.stop
        ? <String, Object?>{}
        : <String, Object?>{'speed': speed};

    await _communicationService.send(
      CommunicationMessage(
        command: command.protocolCommand,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );

    return command.label;
  }

  Future<String> sendPlantingCommand(PlantingCommand command) async {
    await _communicationService.send(
      CommunicationMessage(
        command: command.protocolCommand,
        timestamp: DateTime.now(),
      ),
    );

    return command.label;
  }

  Future<String> sendEmergencyStop() async {
    await _communicationService.send(
      CommunicationMessage(
        command: 'EMERGENCY_STOP',
        timestamp: DateTime.now(),
      ),
    );

    return 'Emergency Stop';
  }

  Future<void> refreshCamera() async {
    await _communicationService.send(
      CommunicationMessage(
        command: 'REFRESH_CAMERA',
        timestamp: DateTime.now(),
      ),
    );
  }
}
