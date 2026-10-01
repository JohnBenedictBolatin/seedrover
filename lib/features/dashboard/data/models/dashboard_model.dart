class DashboardModel {
  const DashboardModel({
    required this.rover,
    required this.sensors,
    required this.recentActivities,
    this.roverError,
    this.sensorError,
    this.activityError,
  });

  final RoverOverviewModel rover;
  final List<SensorSummaryModel> sensors;
  final List<ActivityPreviewModel> recentActivities;
  final String? roverError;
  final String? sensorError;
  final String? activityError;
}

class RoverOverviewModel {
  const RoverOverviewModel({
    required this.unitName,
    required this.status,
    required this.plantingStatus,
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.cameraConnected,
    required this.isInUse,
    required this.lastCommunication,
  });

  final String unitName;
  final String status;
  final String plantingStatus;
  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool cameraConnected;
  final bool isInUse;
  final DateTime? lastCommunication;
}

class SensorSummaryModel {
  const SensorSummaryModel({
    required this.label,
    required this.value,
    required this.unit,
    required this.interpretation,
    required this.condition,
    this.recordedAt,
    this.source,
  });

  final String label;
  final String value;
  final String unit;
  final String interpretation;
  final SensorCondition condition;
  final DateTime? recordedAt;
  final String? source;
}

class ActivityPreviewModel {
  const ActivityPreviewModel({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.module,
  });

  final String title;
  final String description;
  final DateTime? timestamp;
  final String module;
}

enum SensorCondition {
  recorded,
  unavailable,
}
