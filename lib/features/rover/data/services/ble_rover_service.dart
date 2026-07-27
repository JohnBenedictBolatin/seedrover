import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleRoverService {
  BleRoverService({required String roverToken}) : _roverToken = roverToken;

  static final Guid serviceUuid = Guid('7b100001-0d91-4b68-a5e2-1b7ecb100001');
  static final Guid commandUuid = Guid('7b100002-0d91-4b68-a5e2-1b7ecb100002');
  static final Guid responseUuid = Guid('7b100003-0d91-4b68-a5e2-1b7ecb100003');

  final String _roverToken;
  final _connectedController = StreamController<bool>.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _command;
  BluetoothCharacteristic? _response;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _responseSubscription;
  Completer<Map<String, dynamic>>? _pendingResponse;

  Stream<bool> get connectedStream => _connectedController.stream;
  bool get isConnected => _device?.isConnected == true && _command != null;

  Future<void> connect() async {
    if (isConnected) return;
    if (_roverToken.isEmpty) {
      throw StateError('Add ROVER_TOKEN to the app .env file first.');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('This phone does not support Bluetooth Low Energy.');
    }
    final adapter = await FlutterBluePlus.adapterState
        .where((state) => state != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 3));
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Turn on Bluetooth, then try again.');
    }

    BluetoothDevice? found;
    final foundDevice = Completer<BluetoothDevice>();
    final scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final advertisement = result.advertisementData;
        if (advertisement.advName == 'SeedRover-01' ||
            advertisement.serviceUuids.contains(serviceUuid)) {
          if (!foundDevice.isCompleted) foundDevice.complete(result.device);
          break;
        }
      }
    });
    try {
      // Do not filter at Android's scanner level. Some ESP32/phone combinations
      // put the name or service UUID in the scan-response packet instead.
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      found = await foundDevice.future.timeout(const Duration(seconds: 11));
    } on TimeoutException {
      throw StateError(
        'SeedRover-01 was not found. Reset the ESP32 and check Bluetooth permissions.',
      );
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('permission')) {
        throw StateError(
          'Bluetooth permission denied. Allow Nearby devices in Android Settings.',
        );
      }
      rethrow;
    } finally {
      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();
    }

    await found.connect(
      license: License.free,
      timeout: const Duration(seconds: 12),
    );
    _device = found;
    _connectionSubscription?.cancel();
    _connectionSubscription = found.connectionState.listen((connection) {
      final connected = connection == BluetoothConnectionState.connected;
      if (!connected) {
        _command = null;
        _response = null;
        _pendingResponse?.completeError(StateError('Rover disconnected.'));
        _pendingResponse = null;
      }
      _connectedController.add(connected);
    });

    final services = await found.discoverServices();
    final roverService =
        services.where((service) => service.uuid == serviceUuid).firstOrNull;
    if (roverService == null) {
      throw StateError('SeedRover BLE service is missing.');
    }
    _command = roverService.characteristics
        .where((characteristic) => characteristic.uuid == commandUuid)
        .firstOrNull;
    _response = roverService.characteristics
        .where((characteristic) => characteristic.uuid == responseUuid)
        .firstOrNull;
    if (_command == null || _response == null) {
      throw StateError('SeedRover BLE characteristics are missing.');
    }
    await _responseSubscription?.cancel();
    _responseSubscription = _response!.onValueReceived.listen(_handleResponse);
    await _response!.setNotifyValue(true);
    _connectedController.add(true);
  }

  Future<BlePingResult> ping() async {
    await connect();
    final startedAt = DateTime.now();
    final commandId = 'PING-${startedAt.microsecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingResponse = completer;
    final message = utf8.encode(jsonEncode({
      'command_id': commandId,
      'command': 'PING',
      'token': _roverToken,
      'payload': const <String, Object?>{},
    }));
    late final Map<String, dynamic> response;
    try {
      await _command!.write(message, withoutResponse: false);
      response = await completer.future.timeout(const Duration(seconds: 5));
    } finally {
      _pendingResponse = null;
    }
    if (response['command_id'] != commandId ||
        response['status'] != 'success' ||
        response['data']?['reply'] != 'PONG') {
      throw StateError(
          response['message']?.toString() ?? 'Invalid PONG response.');
    }
    return BlePingResult(DateTime.now().difference(startedAt));
  }

  void _handleResponse(List<int> value) {
    try {
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is Map<String, dynamic> &&
          _pendingResponse?.isCompleted == false) {
        _pendingResponse!.complete(decoded);
      }
    } catch (_) {
      if (_pendingResponse?.isCompleted == false) {
        _pendingResponse!
            .completeError(StateError('ESP32 returned invalid JSON.'));
      }
    }
  }

  Future<void> disconnect() async {
    await _responseSubscription?.cancel();
    _responseSubscription = null;
    await _device?.disconnect();
    _command = null;
    _response = null;
    _connectedController.add(false);
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionSubscription?.cancel();
    await _connectedController.close();
  }
}

class BlePingResult {
  const BlePingResult(this.roundTrip);
  final Duration roundTrip;
}
