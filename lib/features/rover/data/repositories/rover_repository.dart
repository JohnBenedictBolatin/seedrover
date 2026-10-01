import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/communication/shared/communication_device.dart';
import '../../../../core/communication/shared/communication_message.dart';
import '../../../../core/communication/shared/communication_response.dart';
import '../../../../core/communication/shared/communication_service.dart';
import '../../../../core/communication/shared/hardware_simulator_state.dart';
import '../../../../core/communication/shared/simulated_communication_service.dart';
import '../../../../core/constants/database_tables.dart';
import '../../../../shared/utils/soil_moisture_reference_label.dart';
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

  bool get isSimulationConnected {
    return _communicationService.connectedDevice != null;
  }

  Stream<void> watchRoverStatus() {
    return _client
        .from(DatabaseTables.robotStatus)
        .stream(primaryKey: ['id']).map((_) => null);
  }

  Stream<void> watchSimulationStatus() {
    final service = _communicationService;

    if (service is! SimulatedCommunicationService) {
      return const Stream<void>.empty();
    }

    return service.simulatorStateStream.map((_) => null);
  }

  Future<RoverControlModel> loadStatus() async {
    if (isSimulationConnected) {
      return _loadSimulatedStatus();
    }

    var statusRows = <dynamic>[];
    var sensorRows = <dynamic>[];

    // The ESP32 hotspot intentionally has no internet. Do not keep Rover
    // Control on its loading skeleton while Supabase is unreachable.
    try {
      final rows = await Future.wait<List<dynamic>>([
        (_client
                .from(DatabaseTables.robotStatus)
                .select()
                .eq('is_active', true)
                .limit(1) as Future<List<dynamic>>)
            .timeout(const Duration(seconds: 2)),
        (_client
                .from(DatabaseTables.sensorReadings)
                .select(
                    'soil_moisture, calibrated_value, soil_moisture_calibrated, calibration_version, soil_temperature, environmental_temperature, humidity, recorded_at, source')
                .eq('provenance_status', 'verified_hardware')
                .order('recorded_at', ascending: false)
                .limit(1) as Future<List<dynamic>>)
            .timeout(const Duration(seconds: 2)),
      ]);
      statusRows = rows[0];
      sensorRows = rows[1];
    } catch (_) {
      // Local PING remains available with empty telemetry.
    }

    final status = statusRows.isEmpty
        ? <String, dynamic>{}
        : statusRows.first as Map<String, dynamic>;
    final sensors = sensorRows.isEmpty
        ? <String, dynamic>{}
        : sensorRows.first as Map<String, dynamic>;
    final sensorTime =
        DateTime.tryParse(sensors['recorded_at']?.toString() ?? '')?.toLocal();
    final now = DateTime.now();
    final sensorFresh = sensorTime != null &&
        !now.isBefore(sensorTime) &&
        now.difference(sensorTime) <= const Duration(seconds: 60);
    final sensorAgeKnown = sensorTime != null &&
        !sensorTime.isAfter(now.add(const Duration(minutes: 1)));
    String freshnessStatus() {
      if (!sensorAgeKnown) return 'Verified hardware reading · age unknown';
      return sensorFresh
          ? 'Fresh verified hardware reading'
          : 'Stale verified hardware reading';
    }

    final moistureCalibrationState =
        sensors['soil_moisture_calibrated'] as bool?;
    final moistureCalibrated = moistureCalibrationState == true &&
        (sensors['calibration_version'] as String?)?.trim().isNotEmpty == true;
    final sensorSource = sensors['source']?.toString();
    final lastUpdated =
        DateTime.tryParse(status['last_updated']?.toString() ?? '');
    final heartbeatFresh = lastUpdated != null &&
        DateTime.now().difference(lastUpdated).abs() <=
            const Duration(seconds: 9);

    return RoverControlModel(
      wifiConnected:
          heartbeatFresh && (status['wifi_connected'] as bool? ?? false),
      bluetoothConnected:
          heartbeatFresh && (status['bluetooth_connected'] as bool? ?? false),
      cameraConnected:
          heartbeatFresh && (status['camera_connected'] as bool? ?? false),
      cameraLoading: false,
      sensors: [
        RoverSensorModel(
          label: 'Soil Moisture',
          value: moistureCalibrated
              ? _sensorNumber(
                  sensors['calibrated_value'] ?? sensors['soil_moisture'],
                  0,
                  100)
              : null,
          unit: '%',
          status: sensorTime == null
              ? 'Unavailable · no fresh verified reading'
              : moistureCalibrationState != true
                  ? 'Unavailable'
                  : _sensorNumber(
                              sensors['calibrated_value'] ??
                                  sensors['soil_moisture'],
                              0,
                              100) ==
                          null
                      ? 'Unavailable · invalid moisture reading'
                      : freshnessStatus(),
          recordedAt: sensorTime,
          source: sensorSource,
          calibrationVersion: sensors['calibration_version']?.toString(),
          soilMoistureCalibrated: moistureCalibrationState,
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: _sensorNumber(sensors['soil_temperature'], -55, 125),
          unit: 'C',
          status: _sensorNumber(sensors['soil_temperature'], -55, 125) == null
              ? 'Unavailable'
              : freshnessStatus(),
          recordedAt: sensorTime,
          source: sensorSource,
        ),
        RoverSensorModel(
          label: 'Air Temperature',
          value: _sensorNumber(sensors['environmental_temperature'], -40, 80),
          unit: 'C',
          status:
              _sensorNumber(sensors['environmental_temperature'], -40, 80) ==
                      null
                  ? 'Unavailable'
                  : freshnessStatus(),
          recordedAt: sensorTime,
          source: sensorSource,
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: _sensorNumber(sensors['humidity'], 0, 100),
          unit: '%',
          status: _sensorNumber(sensors['humidity'], 0, 100) == null
              ? 'Unavailable'
              : freshnessStatus(),
          recordedAt: sensorTime,
          source: sensorSource,
        ),
      ],
    );
  }

  Future<SoilCheckResultModel> checkSoilState() async {
    if (isSimulationConnected) {
      return const SoilCheckResultModel(
          isSuitable: false,
          message:
              'Simulated sensor values cannot be used as a field observation.');
    }

    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select(
            'soil_moisture, calibrated_value, soil_moisture_calibrated, calibration_version')
        .eq('provenance_status', 'verified_hardware')
        .eq('soil_moisture_calibrated', true)
        .gte(
            'recorded_at',
            DateTime.now()
                .subtract(const Duration(seconds: 60))
                .toUtc()
                .toIso8601String())
        .lte('recorded_at', DateTime.now().toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;
    final sensors =
        rows.isEmpty ? <String, dynamic>{} : rows.first as Map<String, dynamic>;
    final soilMoisture = sensors['calibration_version'] == null
        ? null
        : _sensorNumber(
            sensors['calibrated_value'] ?? sensors['soil_moisture'], 0, 100);
    if (soilMoisture == null) {
      return const SoilCheckResultModel(
          isSuitable: false,
          message: 'No fresh soil-moisture reading is available.');
    }

    return SoilCheckResultModel(
      isSuitable: false,
      message:
          'Soil moisture: ${soilMoisture.toStringAsFixed(1)}%. ${soilMoistureReferenceLabel(soilMoisture)}.',
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

  Future<String> sendPlantingCommand(
    PlantingCommand command, {
    PlantingSeedType? seed,
  }) async {
    final payload = seed == null
        ? const <String, Object?>{}
        : <String, Object?>{
            'seed_type': seed.payloadValue,
            'seed_name': seed.label,
          };

    await _communicationService.send(
      CommunicationMessage(
        command: command.protocolCommand,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
    await _recordCommand(command.protocolCommand, payload: payload);

    return seed == null ? command.label : '${command.label} ${seed.label}';
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
    await _sendMessage('REFRESH_CAMERA');
    await _recordCommand('REFRESH_CAMERA');
  }

  Future<void> connectSimulation() async {
    if (isSimulationConnected) {
      return;
    }

    final devicesFuture =
        _communicationService.discoveredDevicesStream.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => <CommunicationDevice>[],
    );

    await _communicationService.scan();

    final devices = await devicesFuture;
    final availableDevices = devices.where((device) => device.isAvailable);

    if (availableDevices.isEmpty) {
      throw StateError('No simulated rover device found.');
    }

    await _communicationService.connect(availableDevices.first);
  }

  Future<void> disconnectSimulation() async {
    await _communicationService.disconnect();
  }

  Future<RoverControlModel> _loadSimulatedStatus() async {
    final service = _communicationService;

    if (service is SimulatedCommunicationService) {
      return _modelFromSimulatorState(service.simulatorState);
    }

    final statusResponse = await _sendMessage('GET_ROBOT_STATUS');
    final status = statusResponse.payload;

    return RoverControlModel(
      wifiConnected: status['wifi_connected'] as bool? ?? false,
      bluetoothConnected: status['bluetooth_connected'] as bool? ?? false,
      cameraConnected: status['camera_connected'] as bool? ?? false,
      cameraLoading: status['camera_status'] == 'Loading',
      isSimulated: true,
      sensors: [
        RoverSensorModel(
          label: 'Soil Moisture',
          value: null,
          unit: '%',
          status: 'Simulation · value withheld',
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: null,
          unit: 'C',
          status: 'Simulation · value withheld',
        ),
        RoverSensorModel(
          label: 'Air Temperature',
          value: null,
          unit: 'C',
          status: 'Simulation · value withheld',
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: null,
          unit: '%',
          status: 'Simulation · value withheld',
        ),
      ],
    );
  }

  Future<CommunicationResponse> _sendMessage(
    String command, {
    Map<String, Object?> payload = const {},
  }) {
    return _communicationService.send(
      CommunicationMessage(
        command: command,
        timestamp: DateTime.now(),
        payload: payload,
      ),
    );
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

  double? _nullableDouble(Object? value) => (value as num?)?.toDouble();

  double? _sensorNumber(Object? value, double minimum, double maximum) {
    final number = _nullableDouble(value);
    return number != null &&
            number.isFinite &&
            number >= minimum &&
            number <= maximum
        ? number
        : null;
  }

  RoverControlModel _modelFromSimulatorState(HardwareSimulatorState state) {
    return RoverControlModel(
      wifiConnected: isSimulationConnected,
      bluetoothConnected: isSimulationConnected,
      cameraConnected: state.cameraStatus == 'Connected',
      cameraLoading: state.cameraStatus == 'Loading',
      isSimulated: true,
      sensors: [
        RoverSensorModel(
          label: 'Soil Moisture',
          value: null,
          unit: '%',
          status: 'Simulated',
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: null,
          unit: 'C',
          status: 'Simulated',
        ),
        RoverSensorModel(
          label: 'Environmental Temperature',
          value: null,
          unit: 'C',
          status: 'Simulated',
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: null,
          unit: '%',
          status: 'Simulated',
        ),
      ],
    );
  }
}
