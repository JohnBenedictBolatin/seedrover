import 'communication_enums.dart';

class HardwareSimulatorEvent {
  const HardwareSimulatorEvent({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.message,
    required this.type,
    this.relatedModule,
    this.relatedId,
    this.actionRoute,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final DateTime timestamp;
  final String title;
  final String message;
  final String type;
  final String? relatedModule;
  final String? relatedId;
  final String? actionRoute;
  final Map<String, Object?> payload;
}

class HardwareActivityLog {
  const HardwareActivityLog({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.details,
    required this.commandType,
    this.success = true,
  });

  final String id;
  final DateTime timestamp;
  final String action;
  final String details;
  final CommunicationCommandType commandType;
  final bool success;
}

class HardwareSimulatorState {
  const HardwareSimulatorState({
    required this.currentActivity,
    required this.plantingStatus,
    required this.batteryLevel,
    required this.seedLevel,
    required this.soilMoisture,
    required this.soilTemperature,
    required this.environmentTemperature,
    required this.humidity,
    required this.cameraStatus,
    required this.cameraFrameIndex,
    required this.cameraPlaceholder,
    required this.isMoving,
    required this.isPlanting,
    required this.updatedAt,
    this.lastError,
    this.notifications = const <HardwareSimulatorEvent>[],
    this.activityLogs = const <HardwareActivityLog>[],
  });

  factory HardwareSimulatorState.initial() {
    return HardwareSimulatorState(
      currentActivity: 'Idle',
      plantingStatus: 'Ready',
      batteryLevel: 84,
      seedLevel: 67,
      soilMoisture: 42,
      soilTemperature: 28,
      environmentTemperature: 31,
      humidity: 72,
      cameraStatus: 'Connected',
      cameraFrameIndex: 1,
      cameraPlaceholder: 'Field View 1',
      isMoving: false,
      isPlanting: false,
      updatedAt: DateTime.now(),
    );
  }

  final String currentActivity;
  final String plantingStatus;
  final int batteryLevel;
  final int seedLevel;
  final double soilMoisture;
  final double soilTemperature;
  final double environmentTemperature;
  final double humidity;
  final String cameraStatus;
  final int cameraFrameIndex;
  final String cameraPlaceholder;
  final bool isMoving;
  final bool isPlanting;
  final DateTime updatedAt;
  final String? lastError;
  final List<HardwareSimulatorEvent> notifications;
  final List<HardwareActivityLog> activityLogs;

  HardwareSimulatorState copyWith({
    String? currentActivity,
    String? plantingStatus,
    int? batteryLevel,
    int? seedLevel,
    double? soilMoisture,
    double? soilTemperature,
    double? environmentTemperature,
    double? humidity,
    String? cameraStatus,
    int? cameraFrameIndex,
    String? cameraPlaceholder,
    bool? isMoving,
    bool? isPlanting,
    Object? lastError = _noChange,
    List<HardwareSimulatorEvent>? notifications,
    List<HardwareActivityLog>? activityLogs,
  }) {
    return HardwareSimulatorState(
      currentActivity: currentActivity ?? this.currentActivity,
      plantingStatus: plantingStatus ?? this.plantingStatus,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      seedLevel: seedLevel ?? this.seedLevel,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      soilTemperature: soilTemperature ?? this.soilTemperature,
      environmentTemperature:
          environmentTemperature ?? this.environmentTemperature,
      humidity: humidity ?? this.humidity,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      cameraFrameIndex: cameraFrameIndex ?? this.cameraFrameIndex,
      cameraPlaceholder: cameraPlaceholder ?? this.cameraPlaceholder,
      isMoving: isMoving ?? this.isMoving,
      isPlanting: isPlanting ?? this.isPlanting,
      updatedAt: DateTime.now(),
      lastError: lastError == _noChange ? this.lastError : lastError as String?,
      notifications: notifications ?? this.notifications,
      activityLogs: activityLogs ?? this.activityLogs,
    );
  }
}

const _noChange = Object();
