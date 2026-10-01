import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/planting_session_model.dart';

class LocalWifiRoverService {
  LocalWifiRoverService({required String baseUrl, required String roverToken})
      : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), ''),
        _roverToken = roverToken;

  final String _baseUrl;
  final String _roverToken;
  final _connectedController = StreamController<bool>.broadcast();
  final _localNetworkController = StreamController<bool>.broadcast();
  bool _isConnected = false;
  bool _localNetworkActive = false;

  Stream<bool> get connectedStream => _connectedController.stream;
  bool get isConnected => _isConnected;
  Stream<bool> get localNetworkStream => _localNetworkController.stream;
  bool get isLocalNetworkActive => _localNetworkActive;

  void _validateConfiguration() {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'Set ROVER_BASE_URL in .env.mobile.json and run with '
        '--dart-define-from-file=.env.mobile.json.',
      );
    }
    if (_roverToken.isEmpty) {
      throw StateError(
        'Set ROVER_TOKEN in .env.mobile.json and run with '
        '--dart-define-from-file=.env.mobile.json.',
      );
    }
  }

  Future<void> connect() async {
    _validateConfiguration();
    _setLocalNetworkActive(true);
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('seedrover/wifi').invokeMethod<bool>(
          'connectToRoverWifi',
          {
            'ssid': 'SeedRover-01',
            'password': _roverToken,
          },
        );
      }
      final response = await _request('GET', '/health');
      if (response['status'] != 'success') {
        throw StateError('The ESP32 health check failed.');
      }
      _setConnected(true);
    } on PlatformException catch (error) {
      _setConnected(false);
      throw StateError(error.message ?? 'Could not connect to SeedRover-01.');
    } catch (_) {
      _setConnected(false);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await const MethodChannel('seedrover/wifi')
          .invokeMethod<bool>('disconnectFromRoverWifi');
    }
    _setConnected(false);
  }

  Future<LocalWifiPingResult> ping() async {
    if (!_isConnected) await connect();
    final startedAt = DateTime.now();
    final commandId = 'PING-${startedAt.microsecondsSinceEpoch}';
    final response = await _request('POST', '/command', body: {
      'command_id': commandId,
      'command': 'PING',
      'payload': const <String, Object?>{},
    });
    if (response['command_id'] != commandId ||
        response['status'] != 'success' ||
        response['data']?['reply'] != 'PONG') {
      throw StateError(
        response['message']?.toString() ?? 'Invalid PONG response.',
      );
    }
    _setConnected(true);
    return LocalWifiPingResult(DateTime.now().difference(startedAt));
  }

  Future<LocalWifiCommandResult> sendCommand(
    String command, {
    Map<String, Object?> payload = const <String, Object?>{},
    bool connectIfNeeded = true,
  }) async {
    if (!_isConnected) {
      if (!connectIfNeeded) {
        throw StateError(
            'SeedRover disconnected before the command completed.');
      }
      await connect();
    }
    final startedAt = DateTime.now();
    final commandId = 'CMD-${startedAt.microsecondsSinceEpoch}';
    final response = await _request('POST', '/command', body: {
      'command_id': commandId,
      'command': command,
      'payload': payload,
    });
    if (response['command_id'] != commandId ||
        response['status'] != 'success' ||
        response['data']?['accepted_command'] != command) {
      throw StateError(
        response['message']?.toString() ?? 'Invalid command acknowledgement.',
      );
    }
    _setConnected(true);
    return LocalWifiCommandResult(
      command: command,
      roundTrip: DateTime.now().difference(startedAt),
    );
  }

  Future<PlantingOperationStatus> getPlantingStatus() async {
    if (!_isConnected) await connect();
    final response = await _request('GET', '/planting-status');
    _setConnected(true);
    return PlantingOperationStatus.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<RoverCalibrationModel> getCalibration() async {
    final response = await sendRawCommand('GET_CALIBRATION');
    return RoverCalibrationModel.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<void> saveCalibration(RoverCalibrationModel calibration) async {
    await sendCommand('SET_CALIBRATION', payload: calibration.toJson());
  }

  Future<void> startPlantingRow(
    PlantingRowConfig configuration, {
    required int soilSampledAtMs,
  }) async {
    await sendCommand(
      'START_PLANTING_ROW',
      payload: {
        ...configuration.toProtocolPayload(),
        'soil_sampled_at_ms': soilSampledAtMs,
      },
    );
  }

  Future<Map<String, dynamic>> precheckPlantingSoil() async {
    await sendCommand('PRECHECK_PLANTING_SOIL');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    try {
      final response = await _request('GET', '/sensors');
      final readings = Map<String, dynamic>.from(response['data'] as Map);
      readings['recorded_at'] = DateTime.now().toUtc().toIso8601String();
      readings['source'] = 'SeedRover local Wi-Fi';
      return readings;
    } finally {
      try {
        await sendCommand('SOIL_SENSOR_UP');
      } catch (_) {
        // The firmware raises mechanisms when its client heartbeat expires.
      }
    }
  }

  Future<void> cancelPlantingSoilPrecheck() async {
    await sendCommand('CANCEL_PLANTING_PRECHECK', connectIfNeeded: false);
  }

  Future<Map<String, dynamic>> checkAndReadSensors() async {
    await sendCommand('CHECK_SOIL');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    try {
      final response = await _request('GET', '/sensors');
      final readings = Map<String, dynamic>.from(response['data'] as Map);
      readings['recorded_at'] = DateTime.now().toUtc().toIso8601String();
      readings['source'] = 'SeedRover local Wi-Fi';
      final nullableSensorProtocol =
          readings.containsKey('soil_sample_available') &&
              readings.containsKey('soil_moisture_calibrated') &&
              readings.containsKey('sampled_at_ms');
      if (!nullableSensorProtocol) {
        readings['source'] = 'Legacy rover protocol · unverified';
        readings['firmware_version'] = null;
        readings['soil_moisture_calibrated'] = null;
        readings['calibration_version'] = null;
        readings['soil_moisture_percent'] = null;
        readings['soil_raw'] = null;
      } else if (readings['soil_sample_available'] != true) {
        readings['soil_raw'] = null;
      }
      return readings;
    } finally {
      try {
        await sendCommand('SOIL_SENSOR_UP');
      } catch (_) {
        // The rover heartbeat and safe-state routines remain responsible for
        // stopping motion if the phone loses its local connection.
      }
    }
  }

  Future<Map<String, dynamic>> sendRawCommand(
    String command, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    if (!_isConnected) await connect();
    final commandId = 'CMD-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _request('POST', '/command', body: {
      'command_id': commandId,
      'command': command,
      'payload': payload,
    });
    _setConnected(true);
    return response;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = method == 'GET'
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      request.headers.set('X-Rover-Token', _roverToken);
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      request.headers.contentType = ContentType.json;
      if (body != null) {
        final encodedBody = utf8.encode(jsonEncode(body));
        request.contentLength = encodedBody.length;
        request.add(encodedBody);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('ESP32 returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            decoded['message']?.toString() ?? 'ESP32 rejected the request.');
      }
      return decoded;
    } on SocketException {
      _setConnected(false);
      throw StateError(
        'Cannot reach the ESP32. Connect the phone to SeedRover-01 and verify ROVER_BASE_URL.',
      );
    } on TimeoutException {
      _setConnected(false);
      throw StateError(
        'The ESP32 timed out. Stay connected to SeedRover-01 and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  void _setConnected(bool value) {
    _isConnected = value;
    _connectedController.add(value);
    _setLocalNetworkActive(value);
  }

  void _setLocalNetworkActive(bool value) {
    if (_localNetworkActive == value) return;
    _localNetworkActive = value;
    _localNetworkController.add(value);
  }

  Future<void> dispose() async {
    await _connectedController.close();
    await _localNetworkController.close();
  }
}

class LocalWifiPingResult {
  const LocalWifiPingResult(this.roundTrip);
  final Duration roundTrip;
}

class LocalWifiCommandResult {
  const LocalWifiCommandResult({
    required this.command,
    required this.roundTrip,
  });

  final String command;
  final Duration roundTrip;
}
