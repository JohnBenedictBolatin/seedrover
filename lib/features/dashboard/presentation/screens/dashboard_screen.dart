import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/recent_activity_panel.dart';
import '../widgets/rover_overview_card.dart';
import '../widgets/section_title.dart';
import '../widgets/sensor_summary_grid.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DashboardHeader(
          fullName: profile?.fullName ?? 'Operator',
          roleName: profile?.roleName ?? 'Authenticated User',
          timestamp: now,
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle(title: 'Rover Overview'),
        const SizedBox(height: AppSpacing.md),
        RoverOverviewCard(rover: dashboard.rover),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle(title: 'Sensor Summary', mono: true),
        const SizedBox(height: AppSpacing.md),
        SensorSummaryGrid(sensors: dashboard.sensors),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle(title: 'Recent Activities'),
        const SizedBox(height: AppSpacing.md),
        RecentActivityPanel(activities: dashboard.recentActivities),
      ],
    );
  }
}
