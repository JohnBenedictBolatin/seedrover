import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dashboard_model.dart';

class DashboardController {
  const DashboardController();

  DashboardModel loadMockDashboard() {
    final now = DateTime.now();

    return DashboardModel(
      rover: RoverOverviewModel(
        unitName: 'SeedRover Unit SR-001',
        status: 'ONLINE',
        plantingStatus: 'Ready',
        batteryLevel: 84,
        seedLevel: 67,
        wifiConnected: true,
        bluetoothConnected: false,
        cameraConnected: true,
        isInUse: true,
        usageDuration: const Duration(hours: 2, minutes: 18),
        lastCommunication: now.subtract(const Duration(seconds: 12)),
      ),
      sensors: const [
        SensorSummaryModel(
          label: 'Soil Moisture',
          value: '42',
          unit: '%',
          interpretation: 'Good',
          condition: SensorCondition.excellent,
        ),
        SensorSummaryModel(
          label: 'Soil Temp',
          value: '28',
          unit: 'C',
          interpretation: 'Moderate',
          condition: SensorCondition.moderate,
        ),
        SensorSummaryModel(
          label: 'Air Temp',
          value: '31',
          unit: 'C',
          interpretation: 'Good',
          condition: SensorCondition.excellent,
        ),
        SensorSummaryModel(
          label: 'Humidity',
          value: '72',
          unit: '%',
          interpretation: 'Good',
          condition: SensorCondition.excellent,
        ),
      ],
      recentActivities: [
        ActivityPreviewModel(
          title: 'Robot status refreshed',
          description: 'SeedRover reported stable operating conditions.',
          timestamp: now.subtract(const Duration(minutes: 2)),
          module: 'Rover',
        ),
        ActivityPreviewModel(
          title: 'Sensor summary updated',
          description: 'Soil and environment readings were refreshed.',
          timestamp: now.subtract(const Duration(minutes: 9)),
          module: 'Sensors',
        ),
        ActivityPreviewModel(
          title: 'Seed level checked',
          description: 'Current seed level remains within normal range.',
          timestamp: now.subtract(const Duration(minutes: 24)),
          module: 'Stocks',
        ),
      ],
    );
  }
}

final dashboardControllerProvider = Provider<DashboardController>(
  (ref) => const DashboardController(),
);

final dashboardProvider = Provider<DashboardModel>(
  (ref) => ref.watch(dashboardControllerProvider).loadMockDashboard(),
);
