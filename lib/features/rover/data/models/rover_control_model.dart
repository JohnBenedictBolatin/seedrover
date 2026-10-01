class RoverControlModel {
  const RoverControlModel({
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.cameraConnected,
    required this.cameraLoading,
    required this.sensors,
    this.isSimulated = false,
  });

  factory RoverControlModel.offline() {
    return const RoverControlModel(
      wifiConnected: false,
      bluetoothConnected: false,
      cameraConnected: false,
      cameraLoading: false,
      sensors: [
        RoverSensorModel(
          label: 'Soil Moisture',
          value: null,
          unit: '%',
          status: 'Unavailable',
        ),
        RoverSensorModel(
          label: 'Soil Temperature',
          value: null,
          unit: 'C',
          status: 'Unavailable',
        ),
        RoverSensorModel(
          label: 'Environmental Temperature',
          value: null,
          unit: 'C',
          status: 'Unavailable',
        ),
        RoverSensorModel(
          label: 'Humidity',
          value: null,
          unit: '%',
          status: 'Unavailable',
        ),
      ],
      isSimulated: false,
    );
  }

  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool cameraConnected;
  final bool cameraLoading;
  final List<RoverSensorModel> sensors;
  final bool isSimulated;

  RoverControlModel copyWith({
    bool? wifiConnected,
    bool? bluetoothConnected,
    bool? cameraConnected,
    bool? cameraLoading,
    List<RoverSensorModel>? sensors,
    bool? isSimulated,
  }) {
    return RoverControlModel(
      wifiConnected: wifiConnected ?? this.wifiConnected,
      bluetoothConnected: bluetoothConnected ?? this.bluetoothConnected,
      cameraConnected: cameraConnected ?? this.cameraConnected,
      cameraLoading: cameraLoading ?? this.cameraLoading,
      sensors: sensors ?? this.sensors,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }
}

class RoverSensorModel {
  const RoverSensorModel({
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    this.recordedAt,
    this.source,
    this.calibrationVersion,
    this.soilMoistureCalibrated,
  });

  final String label;
  final double? value;
  final String unit;
  final String status;
  final DateTime? recordedAt;
  final String? source;
  final String? calibrationVersion;
  final bool? soilMoistureCalibrated;
}

class SoilCheckResultModel {
  const SoilCheckResultModel({
    required this.isSuitable,
    required this.message,
  });

  final bool isSuitable;
  final String message;
}
