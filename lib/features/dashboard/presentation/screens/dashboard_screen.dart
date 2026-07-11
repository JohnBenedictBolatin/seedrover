import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/dashboard_analytics_section.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/recent_activity_panel.dart';
import '../widgets/rover_overview_card.dart';
import '../widgets/section_title.dart';
import '../widgets/sensor_summary_grid.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showSkeleton = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _showSkeleton = false);
      }
    });
  }

  Future<void> _refreshDashboard() async {
    setState(() => _showSkeleton = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    ref.invalidate(dashboardProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {
      // The dashboard body displays the friendly error state below.
    }

    if (mounted) {
      setState(() => _showSkeleton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(dashboardRealtimeProvider, (previous, next) {
      if (next.hasValue && !_showSkeleton) {
        ref.invalidate(dashboardProvider);
      }
    });

    final dashboardAsync = ref.watch(dashboardProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: _showSkeleton || dashboardAsync.isLoading
          ? const _DashboardLoadingSkeleton()
          : dashboardAsync.when(
              loading: () => const _DashboardLoadingSkeleton(),
              error: (_, __) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  SectionTitle(title: 'Dashboard unavailable'),
                  SizedBox(height: AppSpacing.md),
                  Text('Unable to load live dashboard data.'),
                ],
              ),
              data: (dashboard) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  const DashboardAnalyticsSection(),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle(title: 'Recent Activities'),
                  const SizedBox(height: AppSpacing.md),
                  RecentActivityPanel(activities: dashboard.recentActivities),
                ],
              ),
            ),
    );
  }
}

class _DashboardLoadingSkeleton extends StatelessWidget {
  const _DashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonLine(widthFactor: 0.6, height: 30),
        SizedBox(height: AppSpacing.sm),
        SkeletonLine(widthFactor: 0.42),
        SizedBox(height: AppSpacing.xl),
        SkeletonLine(widthFactor: 0.38, height: 18),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.68, height: 18),
            SizedBox(height: AppSpacing.md),
            SkeletonBlock(height: 112),
            SizedBox(height: AppSpacing.md),
            SkeletonLine(widthFactor: 0.82),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonLine(widthFactor: 0.42, height: 18),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 92, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 92, children: [])),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 92, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 92, children: [])),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonLine(widthFactor: 0.42, height: 18),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 80, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 80, children: [])),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 160, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 160, children: [])),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonLine(widthFactor: 0.42, height: 18),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.82),
            SizedBox(height: AppSpacing.sm),
            SkeletonLine(widthFactor: 0.64),
            SizedBox(height: AppSpacing.md),
            SkeletonLine(widthFactor: 0.78),
            SizedBox(height: AppSpacing.sm),
            SkeletonLine(widthFactor: 0.56),
          ],
        ),
      ],
    );
  }
}
