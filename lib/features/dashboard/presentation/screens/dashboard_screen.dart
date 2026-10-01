import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../../../features/crops/providers/crop_providers.dart';
import '../../../../features/crops/data/models/crop_model.dart';
import '../../../../features/inventory/providers/stock_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/welcome_header_backdrop.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/recent_activity_panel.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_summary_hero.dart';
import '../widgets/sales_inventory_charts.dart';
import '../widgets/dashboard_needs_attention.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/startup_recovery.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refreshDashboard() async {
    final profile = ref.read(authControllerProvider).profile;
    final refreshes = <Future<void>>[];
    if (profile?.hasPermission(PermissionKeys.stocksView) == true) {
      refreshes.add(
        ref.read(stockInventoryControllerProvider.notifier).refreshStocks(),
      );
    }
    if (profile?.hasPermission(PermissionKeys.cropsView) == true) {
      refreshes.add(
        ref.read(cropMonitoringControllerProvider.notifier).refreshCrops(),
      );
    }
    ref.invalidate(dashboardProvider);
    try {
      refreshes.add(ref.read(dashboardProvider.future));
      await Future.wait(refreshes);
    } catch (_) {
      // The dashboard body displays the friendly error state below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile?.isPlantingManager == true) {
      final cropState = ref.watch(cropMonitoringControllerProvider);
      return _withLargerDashboardText(
        context,
        _PlantingManagerDashboard(
          crops: cropState.crops,
          isLoading: cropState.isLoading,
          errorMessage: cropState.errorMessage,
          onRefresh: () => ref
              .read(cropMonitoringControllerProvider.notifier)
              .refreshCrops(),
        ),
      );
    }

    ref.listen<AsyncValue<void>>(dashboardRealtimeProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue == true) {
        ref.invalidate(dashboardProvider);
      }
    });

    final dashboardAsync = ref.watch(dashboardProvider);
    final canViewStocks =
        profile?.hasPermission(PermissionKeys.stocksView) == true;
    final canViewCrops =
        profile?.hasPermission(PermissionKeys.cropsView) == true;
    final now = DateTime.now();
    // Inventory and crop sections manage their own loading states. Keep them
    // from holding the entire dashboard behind slower, unrelated requests.
    final showingInitialLoad =
        dashboardAsync.isLoading && !dashboardAsync.hasValue;

    return _withLargerDashboardText(
      context,
      RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: showingInitialLoad
            ? StartupRecovery(
                loading: const _DashboardLoadingSkeleton(),
                errorMessage: dashboardAsync.hasError
                    ? 'Unable to load dashboard data. Check your connection and retry.'
                    : null,
                onRetry: _refreshDashboard,
                destinations: [
                  if (canViewCrops)
                    (label: 'Continue with Crops', route: AppRoutes.crops),
                  if (canViewStocks)
                    (label: 'Continue with Inventory', route: AppRoutes.stocks),
                  if (profile?.hasPermission(PermissionKeys.roverView) == true)
                    (
                      label: 'Continue to Rover Control',
                      route: AppRoutes.rover
                    ),
                ],
              )
            : dashboardAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                skipError: true,
                loading: () => const _DashboardLoadingSkeleton(),
                error: (_, __) => StartupRecovery(
                  loading: const _DashboardLoadingSkeleton(),
                  errorMessage:
                      'Unable to load dashboard data. Check your connection and retry.',
                  onRetry: _refreshDashboard,
                  destinations: [
                    if (canViewCrops)
                      (label: 'Continue with Crops', route: AppRoutes.crops),
                    if (canViewStocks)
                      (
                        label: 'Continue with Inventory',
                        route: AppRoutes.stocks
                      ),
                    if (profile?.hasPermission(PermissionKeys.roverView) ==
                        true)
                      (
                        label: 'Continue to Rover Control',
                        route: AppRoutes.rover
                      ),
                  ],
                ),
                data: (dashboard) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  children: [
                    WelcomeHeaderBackdrop(
                      header: DashboardHeader(
                        onGradient: true,
                      ),
                      briefing: _DashboardBriefingCard(
                        fullName: profile?.fullName ?? 'Operator',
                        roleName: profile?.roleName ?? 'Authenticated User',
                        timestamp: now,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          if (canViewStocks) ...[
                            const DashboardSummaryHero(),
                            const SizedBox(height: AppSpacing.lg),
                            const DashboardQuickActions(),
                            const SizedBox(height: AppSpacing.lg),
                            const DashboardNeedsAttention(),
                            const SizedBox(height: AppSpacing.xl),
                            SalesInventoryCharts(
                              key: const ValueKey('dashboard-overview-v2'),
                              rover: dashboard.rover,
                            ),
                          ] else ...[
                            const DashboardNeedsAttention(),
                            const SizedBox(height: AppSpacing.lg),
                            const DashboardQuickActions(),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          RecentActivityPanel(
                            activities: dashboard.recentActivities,
                            errorMessage: dashboard.activityError,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget _withLargerDashboardText(BuildContext context, Widget child) {
  final mediaQuery = MediaQuery.of(context);
  return MediaQuery(
    data: mediaQuery.copyWith(
      textScaler: _DashboardTextScaler(mediaQuery.textScaler),
    ),
    child: child,
  );
}

class _DashboardTextScaler extends TextScaler {
  const _DashboardTextScaler(this.parent);

  final TextScaler parent;

  @override
  double scale(double fontSize) => parent.scale(fontSize * 1.1);

  // TextScaler retains this member for backward compatibility.
  @override
  double get textScaleFactor =>
      parent.textScaleFactor * 1.1; // ignore: deprecated_member_use

  @override
  bool operator ==(Object other) =>
      other is _DashboardTextScaler && other.parent == parent;

  @override
  int get hashCode => Object.hash(parent, 1.1);
}

class _PlantingManagerDashboard extends StatelessWidget {
  const _PlantingManagerDashboard({
    required this.crops,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final List<CropModel> crops;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final active = crops.where((crop) => !crop.isCompleted).toList();
    final attention = active.where((crop) =>
        crop.status == CropStatus.needsAttention ||
        crop.careTasks
            .any((task) => task.status == 'Due' || task.status == 'Overdue'));
    final harvestSoon = active.where((crop) =>
        crop.isHarvestReady ||
        (crop.estimatedHarvest != null && crop.remainingHarvestDays <= 14));
    final stageCounts = <String, int>{};
    for (final crop in active) {
      stageCounts.update(crop.growthStageLabel, (count) => count + 1,
          ifAbsent: () => 1);
    }
    final stages = stageCounts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final attentionCrops = attention.take(6).toList(growable: false);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          const DashboardHeader(),
          const SizedBox(height: AppSpacing.md),
          Text('Farm overview', style: AppTypography.sectionHeading),
          const SizedBox(height: AppSpacing.xs),
          Text('Crop growth, care follow-up, and upcoming harvests.',
              style: AppTypography.caption),
          const SizedBox(height: AppSpacing.lg),
          if (isLoading && crops.isEmpty)
            const SkeletonCard(
              height: 150,
              children: [
                SkeletonLine(widthFactor: 0.45),
                SizedBox(height: AppSpacing.md),
                SkeletonLine(widthFactor: 0.9),
                SizedBox(height: AppSpacing.sm),
                SkeletonLine(widthFactor: 0.7),
              ],
            )
          else if (errorMessage != null && crops.isEmpty)
            _PlantingDashboardMessage(
                message: 'Crop dashboard could not load: $errorMessage')
          else ...[
            Row(
              children: [
                Expanded(
                    child: _PlantingMetric(
                        title: 'Active batches',
                        value: active.length,
                        icon: Icons.eco_outlined)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _PlantingMetric(
                        title: 'Need attention',
                        value: attention.length,
                        icon: Icons.warning_amber_rounded)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: _PlantingMetric(
                        title: 'Harvest soon',
                        value: harvestSoon.length,
                        icon: Icons.event_available_outlined)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlantingDashboardPanel(
              title: 'Growth stages',
              subtitle: 'Active batches by their recorded stage',
              child: stages.isEmpty
                  ? const _PlantingDashboardMessage(
                      message: 'No active crop batches yet.')
                  : Column(
                      children: [
                        for (final item in stages) ...[
                          _StageBar(
                            label: item.key,
                            count: item.value,
                            maximum: stages.first.value,
                          ),
                          if (item != stages.last)
                            const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlantingDashboardPanel(
              title: 'Care follow-up',
              subtitle: 'Crops with overdue or due care tasks',
              child: attentionCrops.isEmpty
                  ? const _PlantingDashboardMessage(
                      message: 'No crops need care follow-up right now.')
                  : Column(
                      children: [
                        for (final crop in attentionCrops)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.eco_outlined,
                                color: AppColors.primaryGreen),
                            title: Text(crop.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${crop.fieldLabel} · ${_careFollowUpLabel(crop)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context
                                .push(AppRoutes.cropDetailsPath(crop.id)),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlantingMetric extends StatelessWidget {
  const _PlantingMetric(
      {required this.title, required this.value, required this.icon});
  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primaryGreen, size: 20),
            const SizedBox(height: AppSpacing.xs),
            Text('$value', style: AppTypography.sectionHeading),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.numericCaption),
          ]),
        ),
      );
}

class _PlantingDashboardPanel extends StatelessWidget {
  const _PlantingDashboardPanel(
      {required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            child,
          ]),
        ),
      );
}

class _StageBar extends StatelessWidget {
  const _StageBar(
      {required this.label, required this.count, required this.maximum});
  final String label;
  final int count;
  final int maximum;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 3,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            flex: 5,
            child: LinearProgressIndicator(
                value: maximum == 0 ? 0 : count / maximum,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.primaryGreen,
                backgroundColor: AppColors.inactiveBorder)),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
            width: 24,
            child: Text('$count',
                textAlign: TextAlign.end, style: AppTypography.numericCaption)),
      ]);
}

class _PlantingDashboardMessage extends StatelessWidget {
  const _PlantingDashboardMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: AppTypography.caption);
}

String _careFollowUpLabel(CropModel crop) {
  for (final task in crop.careTasks) {
    if (task.status == 'Due' || task.status == 'Overdue') return task.title;
  }
  return crop.careStatus;
}

class _DashboardBriefingCard extends StatelessWidget {
  const _DashboardBriefingCard({
    required this.fullName,
    required this.roleName,
    required this.timestamp,
  });

  final String fullName;
  final String roleName;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final name = fullName.trim().split(RegExp(r'\s+')).first;
    final greeting = switch (timestamp.hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };
    final surface = AppColors.isLight ? Colors.white : AppColors.cardBackground;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradientColors,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your field today',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$greeting, $name',
                    style: AppTypography.sectionHeading.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$roleName · ${DateTimeFormatter.formatDate(timestamp)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const SeedRoverMascot(
              expression: SeedRoverMascotExpression.dashboard,
              size: 62,
            ),
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
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 68, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 68, children: [])),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonCard(height: 68, children: [])),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonLine(widthFactor: 0.42, height: 18),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 220, children: []),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 210, children: []),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 124, children: []),
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
