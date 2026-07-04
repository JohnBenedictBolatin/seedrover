class RoverControlModel {
  const RoverControlModel({
    required this.batteryLevel,
    required this.seedLevel,
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.cameraConnected,
    required this.cameraLoading,
    required this.sensors,
  });

  final int batteryLevel;
  final int seedLevel;
  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool cameraConnected;
  final bool cameraLoading;
  final List<RoverSensorModel> sensors;

  RoverControlModel copyWith({
    int? batteryLevel,
    int? seedLevel,
    bool? wifiConnected,
    bool? bluetoothConnected,
    bool? cameraConnected,
    bool? cameraLoading,
    List<RoverSensorModel>? sensors,
  }) {
    return RoverControlModel(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      seedLevel: seedLevel ?? this.seedLevel,
      wifiConnected: wifiConnected ?? this.wifiConnected,
      bluetoothConnected: bluetoothConnected ?? this.bluetoothConnected,
      cameraConnected: cameraConnected ?? this.cameraConnected,
      cameraLoading: cameraLoading ?? this.cameraLoading,
      sensors: sensors ?? this.sensors,
    );
  }
}

class RoverSensorModel {
  const RoverSensorModel({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
  });

  final String label;
  final double value;
  final String unit;
  final String status;
}

class SoilCheckResultModel {
  const SoilCheckResultModel({
    required this.isSuitable,
    required this.message,
  });

  final bool isSuitable;
  final String message;
}
