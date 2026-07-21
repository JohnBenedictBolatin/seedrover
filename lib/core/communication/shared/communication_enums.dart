enum CommunicationConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  error;

  String get label {
    return switch (this) {
      CommunicationConnectionState.disconnected => 'Disconnected',
      CommunicationConnectionState.scanning => 'Scanning',
      CommunicationConnectionState.connecting => 'Connecting',
      CommunicationConnectionState.connected => 'Connected',
      CommunicationConnectionState.reconnecting => 'Reconnecting',
      CommunicationConnectionState.disconnecting => 'Disconnecting',
      CommunicationConnectionState.error => 'Error',
    };
  }
}

enum CommunicationTransport {
  bluetooth,
  wifi,
  lora;

  String get label {
    return switch (this) {
      CommunicationTransport.bluetooth => 'Bluetooth',
      CommunicationTransport.wifi => 'Wi-Fi',
      CommunicationTransport.lora => 'LoRa',
    };
  }
}

enum CommunicationCommandType {
  moveForward,
  moveBackward,
  turnLeft,
  turnRight,
  stop,
  startPlanting,
  pausePlanting,
  resumePlanting,
  stopPlanting,
  emergencyStop,
  statusRequest,
  sensorRequest,
  batteryRequest,
  seedLevelRequest,
  startCamera,
  stopCamera,
  refreshCamera,
  ping,
  unsupported;

  String get protocolName {
    return switch (this) {
      CommunicationCommandType.moveForward => 'MOVE_FORWARD',
      CommunicationCommandType.moveBackward => 'MOVE_BACKWARD',
      CommunicationCommandType.turnLeft => 'TURN_LEFT',
      CommunicationCommandType.turnRight => 'TURN_RIGHT',
      CommunicationCommandType.stop => 'STOP',
      CommunicationCommandType.startPlanting => 'START_PLANTING',
      CommunicationCommandType.pausePlanting => 'PAUSE_PLANTING',
      CommunicationCommandType.resumePlanting => 'RESUME_PLANTING',
      CommunicationCommandType.stopPlanting => 'STOP_PLANTING',
      CommunicationCommandType.emergencyStop => 'EMERGENCY_STOP',
      CommunicationCommandType.statusRequest => 'GET_ROBOT_STATUS',
      CommunicationCommandType.sensorRequest => 'GET_SENSOR_DATA',
      CommunicationCommandType.batteryRequest => 'GET_BATTERY_LEVEL',
      CommunicationCommandType.seedLevelRequest => 'GET_SEED_LEVEL',
      CommunicationCommandType.startCamera => 'START_CAMERA',
      CommunicationCommandType.stopCamera => 'STOP_CAMERA',
      CommunicationCommandType.refreshCamera => 'REFRESH_CAMERA',
      CommunicationCommandType.ping => 'PING',
      CommunicationCommandType.unsupported => 'UNSUPPORTED',
    };
  }

  static CommunicationCommandType fromProtocolName(String value) {
    final normalized = value.trim().toUpperCase();

    for (final type in CommunicationCommandType.values) {
      if (type.protocolName == normalized) {
        return type;
      }
    }

    return CommunicationCommandType.unsupported;
  }
}

enum CommunicationCommandStatus {
  queued,
  sending,
  success,
  failed,
  timeout,
  unsupported;
}

enum CommunicationResponseType {
  success,
  failed,
  invalidCommand,
  busy,
  disconnected,
  timeout,
  invalidJson,
  unexpected;

  static CommunicationResponseType fromStatus(String status) {
    return switch (status.trim().toLowerCase()) {
      'success' => CommunicationResponseType.success,
      'failed' => CommunicationResponseType.failed,
      'invalid_command' => CommunicationResponseType.invalidCommand,
      'busy' => CommunicationResponseType.busy,
      'disconnected' => CommunicationResponseType.disconnected,
      'timeout' => CommunicationResponseType.timeout,
      'invalid_json' => CommunicationResponseType.invalidJson,
      _ => CommunicationResponseType.unexpected,
    };
  }
}
