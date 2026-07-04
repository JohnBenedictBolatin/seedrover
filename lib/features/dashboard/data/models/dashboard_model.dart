class DashboardModel {
  const DashboardModel({
    required this.rover,
    required this.sensors,
    required this.recentActivities,
  });

  final RoverOverviewModel rover;
  final List<SensorSummaryModel> sensors;
  final List<ActivityPreviewModel> recentActivities;
}

class RoverOverviewModel {
  const RoverOverviewModel({
    required this.unitName,
    required this.status,
    required this.plantingStatus,
    required this.batteryLevel,
    required this.seedLevel,
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.cameraConnected,
    required this.isInUse,
    required this.usageDuration,
    required this.lastCommunication,
  });

  final String unitName;
  final String status;
  final String plantingStatus;
  final int batteryLevel;
  final int seedLevel;
  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool cameraConnected;
  final bool isInUse;
  final Duration usageDuration;
  final DateTime lastCommunication;
}

class SensorSummaryModel {
  const SensorSummaryModel({
    required this.label,
    required this.value,
    required this.unit,
    required this.interpretation,
    required this.condition,
  });

  final String label;
  final String value;
  final String unit;
  final String interpretation;
  final SensorCondition condition;
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
  final DateTime timestamp;
  final String module;
}

enum SensorCondition {
  excellent,
  moderate,
  poor,
}
