import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/communication/shared/communication_message.dart';
import '../../../../core/communication/shared/communication_service.dart';
import '../../../../core/constants/database_tables.dart';
import '../models/rover_command_model.dart';
import '../models/rover_control_model.dart';

class RoverRepository {
  const RoverRepository({
    required CommunicationService communicationService,
    required SupabaseClient client,
  })  : _communicationService = communicationService,
        _client = client;

  final CommunicationService _communicationService;
  final SupabaseClient _client;

  Stream<void> watchRoverStatus() {
    return _client
        .from(DatabaseTables.robotStatus)
        .stream(primaryKey: ['id'])
        .map((_) => null);
  }

  Future<RoverControlModel> loadStatus() async {
    final statusRows = await _client
        .from(DatabaseTables.robotStatus)
        .select()
        .eq('is_active', true)
        .limit(1) as List<dynamic>;
    final sensorRows = await _client
        .from(DatabaseTables.sensorReadings)
        .select()
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;

    final status = statusRows.isEmpty
        ? <String, dynamic>{}
        : statusRows.first as Map<String, dynamic>;
    final sensors = sensorRows.isEmpty
        ? <String, dynamic>{}
        : sensorRows.first as Map<String, dynamic>;

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
          value: _toDouble(sensors['soil_moisture']),
          unit: '%',
          status: 'Good',
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: _toDouble(sensors['soil_temperature']),
          unit: 'C',
          status: 'Moderate',
        ),
        RoverSensorModel(
          label: 'Environmental Temperature',
          value: _toDouble(sensors['environmental_temperature']),
          unit: 'C',
          status: 'Good',
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: _toDouble(sensors['humidity']),
          unit: '%',
          status: 'Good',
        ),
      ],
    );
  }

  Future<SoilCheckResultModel> checkSoilState() async {
    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select('soil_moisture')
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;
    final sensors =
        rows.isEmpty ? <String, dynamic>{} : rows.first as Map<String, dynamic>;
    final soilMoisture = _toDouble(sensors['soil_moisture']);
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
    await _recordCommand(command.protocolCommand, payload: payload);

    return command.label;
  }

  Future<String> sendPlantingCommand(PlantingCommand command) async {
    await _communicationService.send(
      CommunicationMessage(
        command: command.protocolCommand,
        timestamp: DateTime.now(),
      ),
    );
    await _recordCommand(command.protocolCommand);

    return command.label;
  }

  Future<String> sendEmergencyStop() async {
    await _communicationService.send(
      CommunicationMessage(
        command: 'EMERGENCY_STOP',
        timestamp: DateTime.now(),
      ),
    );
    await _recordCommand('EMERGENCY_STOP');

    return 'Emergency Stop';
  }

  Future<void> refreshCamera() async {
    await _communicationService.send(
      CommunicationMessage(
        command: 'REFRESH_CAMERA',
        timestamp: DateTime.now(),
      ),
    );
    await _recordCommand('REFRESH_CAMERA');
  }

  Future<void> _recordCommand(
    String command, {
    Map<String, Object?> payload = const {},
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _client.from(DatabaseTables.robotCommands).insert({
      'command': command,
      'payload': payload,
      'issued_by': userId,
      'status': 'Sent',
      'executed_at': DateTime.now().toIso8601String(),
    });

    await _client.from(DatabaseTables.activityLogs).insert({
      'user_id': userId,
      'activity': 'Robot Command',
      'description': '$command command sent.',
      'module': 'Rover',
    });
  }

  double _toDouble(Object? value) {
    return (value as num?)?.toDouble() ?? 0;
  }
}
